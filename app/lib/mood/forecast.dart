// 날씨 예보(시간별·일별)와, 예보로 계산하는 것들 (화면과 상관없는 공통 기능)
//  · 비 오는 야외 일정 찾기 → 더 좋은 시간 후보
//  · 오늘 산책하기 좋은 시간
//  · 옷차림 한 줄
import 'dart:math';

import '../core/calendar_logic.dart';
import '../core/models.dart';

// ===== 바꿔서 쓸 수 있는 기준값 =====
const rainWarnPercent = 50; // 이 확률 이상이면 '비 올 것 같음'
const dryPercent = 30; // 대체 시간은 이 확률 미만인 시간만
const walkRainPercent = 20; // 산책 시간은 이 확률 미만인 시간만
const walkTempMin = 5, walkTempMax = 30; // 산책하기 좋은 기온 범위(℃)
const walkStartHour = 9, walkEndHour = 20; // 산책을 추천하는 시간대
const slotSearchDays = 10; // 대체 시간을 찾아볼 날짜 수

/// 세계기상기구(WMO) 날씨 코드 → 테마
String themeOf(int code, bool isDay) {
  if ([95, 96, 99].contains(code)) return 'storm';
  if ([71, 73, 75, 77, 85, 86].contains(code)) return 'snow';
  if ((code >= 51 && code <= 67) || [80, 81, 82].contains(code)) return 'rain';
  if ([45, 48].contains(code)) return 'fog';
  if ([2, 3].contains(code)) return 'cloudy';
  return isDay ? 'clear' : 'night';
}

/// 비·눈·천둥이 오는 날씨인가
bool isWet(String theme) => theme == 'rain' || theme == 'storm' || theme == 'snow';

/// 한 시간의 예보
class HourWx {
  final int code;
  final int temp;
  final int rain; // 비 올 확률 %
  const HourWx(this.code, this.temp, this.rain);

  String get theme => themeOf(code, true);
  /// 비·눈이 올 것 같은가: 천둥이거나, 확률이 높거나, 날씨 코드가 비·눈이면서 확률도 어느 정도 있을 때
  /// (예보 코드는 비인데 확률은 2%처럼 낮은 시간이 흔해서, 코드만으로는 경고하지 않아요)
  bool get wet => theme == 'storm' || rain >= rainWarnPercent || (isWet(theme) && rain >= dryPercent);
}

/// 하루의 예보
class DayWx {
  final String ds;
  final int code;
  final int tMax;
  final int tMin;
  final int rain;
  final String? sunrise; // 'YYYY-MM-DDTHH:MM'
  final String? sunset;
  final List<HourWx?> hours; // 0~23시 (없으면 null)

  const DayWx({
    required this.ds,
    required this.code,
    required this.tMax,
    required this.tMin,
    required this.rain,
    this.sunrise,
    this.sunset,
    required this.hours,
  });

  String get theme => themeOf(code, true);

  /// 해 뜨는 시각(분). 정보가 없으면 06:30
  int get sunriseMin => _minOf(sunrise, 6 * 60 + 30);

  /// 해 지는 시각(분). 정보가 없으면 18:00
  int get sunsetMin => _minOf(sunset, 18 * 60);

  static int _minOf(String? iso, int fallback) {
    if (iso == null || iso.length < 16) return fallback;
    return (int.tryParse(iso.substring(11, 13)) ?? 0) * 60 + (int.tryParse(iso.substring(14, 16)) ?? 0);
  }
}

/// 16일치 예보 묶음 (좌표는 저장하지 않고, 어느 지역 예보인지 이름만 저장)
class Forecast {
  final Map<String, DayWx> days = {};
  String place = ''; // 'Here' 또는 대체 도시 이름
  int at = 0; // 받은 시각(밀리초)

  bool get isEmpty => days.isEmpty;
  DayWx? day(String ds) => days[ds];

  HourWx? hour(String ds, int h) {
    final d = days[ds];
    if (d == null || h < 0 || h > 23) return null;
    return d.hours[h];
  }

  bool fresh(int minutes) => !isEmpty && DateTime.now().millisecondsSinceEpoch - at < minutes * 60000;

  void setFrom(Forecast o) {
    days
      ..clear()
      ..addAll(o.days);
    place = o.place;
    at = o.at;
  }

  /// Open-Meteo 응답 → 예보
  static Forecast parse(Map<String, dynamic> j, {required String place, required int at}) {
    final f = Forecast()
      ..place = place
      ..at = at;
    final daily = j['daily'] as Map<String, dynamic>?;
    final hourly = j['hourly'] as Map<String, dynamic>?;
    if (daily == null || hourly == null) return f;

    final hTimes = (hourly['time'] as List).cast<String>();
    final hTemp = hourly['temperature_2m'] as List;
    final hCode = hourly['weather_code'] as List;
    final hRain = hourly['precipitation_probability'] as List;
    final byDay = <String, List<HourWx?>>{};
    for (var i = 0; i < hTimes.length; i++) {
      final t = hTimes[i];
      final h = int.tryParse(t.substring(11, 13)) ?? -1;
      if (h < 0 || h > 23) continue;
      final list = byDay.putIfAbsent(t.substring(0, 10), () => List<HourWx?>.filled(24, null));
      if (hTemp[i] == null || hCode[i] == null) continue;
      list[h] = HourWx((hCode[i] as num).toInt(), (hTemp[i] as num).round(), ((hRain[i] ?? 0) as num).round());
    }

    final dTimes = (daily['time'] as List).cast<String>();
    List? col(String k) => daily[k] as List?;
    for (var i = 0; i < dTimes.length; i++) {
      final ds = dTimes[i];
      final max = col('temperature_2m_max')?[i], min = col('temperature_2m_min')?[i], code = col('weather_code')?[i];
      if (max == null || min == null || code == null) continue;
      f.days[ds] = DayWx(
        ds: ds,
        code: (code as num).toInt(),
        tMax: (max as num).round(),
        tMin: (min as num).round(),
        rain: ((col('precipitation_probability_max')?[i] ?? 0) as num).round(),
        sunrise: col('sunrise')?[i] as String?,
        sunset: col('sunset')?[i] as String?,
        hours: byDay[ds] ?? List<HourWx?>.filled(24, null),
      );
    }
    return f;
  }

  Map<String, dynamic> toJson() => {
        'place': place,
        'at': at,
        'days': [
          for (final d in days.values)
            {
              'd': d.ds,
              'c': d.code,
              'hi': d.tMax,
              'lo': d.tMin,
              'r': d.rain,
              'sr': d.sunrise,
              'ss': d.sunset,
              'h': [for (final h in d.hours) h == null ? null : [h.code, h.temp, h.rain]],
            }
        ],
      };

  static Forecast fromJson(Map<String, dynamic> j) {
    final f = Forecast()
      ..place = (j['place'] ?? '') as String
      ..at = ((j['at'] ?? 0) as num).toInt();
    for (final raw in (j['days'] as List? ?? [])) {
      final m = raw as Map<String, dynamic>;
      final hs = (m['h'] as List).map((x) {
        if (x == null) return null;
        final l = x as List;
        return HourWx((l[0] as num).toInt(), (l[1] as num).toInt(), (l[2] as num).toInt());
      }).toList();
      f.days[m['d'] as String] = DayWx(
        ds: m['d'] as String,
        code: (m['c'] as num).toInt(),
        tMax: (m['hi'] as num).toInt(),
        tMin: (m['lo'] as num).toInt(),
        rain: (m['r'] as num).toInt(),
        sunrise: m['sr'] as String?,
        sunset: m['ss'] as String?,
        hours: hs.length == 24 ? hs : List<HourWx?>.filled(24, null),
      );
    }
    return f;
  }
}

// ===== 1. 야외 일정 + 비 =====

/// 야외 일정이 비를 맞을 것 같을 때의 정보
class RainRisk {
  final int fromHour;
  final int toHour;
  final int maxRain; // %
  final String theme; // rain · storm · snow (확률만 높으면 rain)
  const RainRisk(this.fromHour, this.toHour, this.maxRain, this.theme);
}

/// 그 날짜에 열리는 야외 일정이 비 맞을 위험이 있는가 (지난 일정은 제외)
RainRisk? rainRisk(CalEvent e, String ds, Forecast f, {DateTime? now}) {
  if (!e.outdoor || e.allDay || f.isEmpty) return null;
  final n = now ?? DateTime.now();
  if (ds.compareTo(ymd(n)) < 0) return null;
  final startMin = toMin(e.start), endMin = toMin(e.end);
  if (ds == ymd(n) && endMin <= n.hour * 60 + n.minute) return null;
  var from = -1, to = -1, maxRain = 0;
  var theme = 'rain';
  for (var h = startMin ~/ 60; h <= (max(endMin, startMin + 1) - 1) ~/ 60; h++) {
    final w = f.hour(ds, h);
    if (w == null || !w.wet) continue;
    if (from < 0) {
      from = h;
      theme = isWet(w.theme) ? w.theme : 'rain';
    }
    to = h + 1;
    maxRain = max(maxRain, w.rain);
  }
  return from < 0 ? null : RainRisk(from, to, maxRain, theme);
}

/// 일정을 옮길 수 있는 날짜·시간 후보
class Slot {
  final String ds;
  final int startMin;
  final int endMin;
  final HourWx? wx; // 시작 시각의 예보
  const Slot(this.ds, this.startMin, this.endMin, this.wx);

  String get startText => '${pad2(startMin ~/ 60)}:${pad2(startMin % 60)}';
  String get endText => '${pad2(endMin ~/ 60)}:${pad2(endMin % 60)}';
}

bool _freeAt(List<CalEvent> events, String skipId, int s, int e) => !events.any(
      (o) => o.id != skipId && !o.allDay && toMin(o.start) < e && toMin(o.end) > s,
    );

/// 같은 길이로 옮길 수 있는, 비가 안 오고 다른 일정과 안 겹치는 시간 후보 (가까운 날 순, 하루에 하나)
List<Slot> betterSlots(
  CalEvent e,
  String from,
  Forecast f,
  List<CalEvent> Function(String ds) eventsOn, {
  DateTime? now,
  int count = 3,
}) {
  final n = now ?? DateTime.now();
  final today = dateOnly(n);
  final nowMin = n.hour * 60 + n.minute;
  final dur = max(30, toMin(e.end) - toMin(e.start));
  final origin = toMin(e.start);
  final out = <({int dayDiff, int timeDiff, Slot slot})>[];

  for (var i = 0; i < slotSearchDays; i++) {
    final ds = ymd(addDays(today, i));
    if (f.day(ds) == null) continue;
    final evs = eventsOn(ds);
    ({int timeDiff, Slot slot})? best;
    for (var h = 8; h <= 20; h++) {
      final s = h * 60, en = s + dur;
      if (en > 23 * 60) continue;
      if (ds == from && s == origin) continue;
      if (ds == ymd(today) && s < nowMin) continue;
      var dry = true;
      for (var k = h; k <= (en - 1) ~/ 60; k++) {
        final w = f.hour(ds, k);
        if (w == null || w.wet || w.rain >= dryPercent) dry = false;
      }
      if (!dry || !_freeAt(evs, e.id, s, en)) continue;
      final diff = (s - origin).abs();
      if (best == null || diff < best.timeDiff) best = (timeDiff: diff, slot: Slot(ds, s, en, f.hour(ds, h)));
    }
    if (best != null) {
      out.add((dayDiff: (parseYmd(ds).difference(parseYmd(from)).inDays).abs(), timeDiff: best.timeDiff, slot: best.slot));
    }
  }
  out.sort((a, b) => a.dayDiff != b.dayDiff ? a.dayDiff.compareTo(b.dayDiff) : a.timeDiff.compareTo(b.timeDiff));
  return out.take(count).map((x) => x.slot).toList();
}

// ===== 2. 산책하기 좋은 시간 =====

bool _goodHour(HourWx? w) =>
    w != null && !w.wet && w.rain < walkRainPercent && w.temp >= walkTempMin && w.temp <= walkTempMax;

double _hourScore(HourWx w) =>
    (w.theme == 'clear' ? 2.0 : (w.theme == 'cloudy' ? 1.0 : 0.0)) - (w.temp - 20).abs() / 5;

/// 그날 비어 있고 날씨가 좋은 1~2시간 (없으면 null)
Slot? walkWindow(String ds, Forecast f, List<CalEvent> Function(String ds) eventsOn, {DateTime? now}) {
  final n = now ?? DateTime.now();
  if (ds.compareTo(ymd(n)) < 0 || f.day(ds) == null) return null;
  final nowMin = n.hour * 60 + n.minute;
  final evs = eventsOn(ds);
  final dayWx = f.day(ds)!;
  // 해가 떠 있는 시간만 (일몰 30분 뒤까지)
  bool ok(int h) =>
      h * 60 >= dayWx.sunriseMin &&
      h * 60 + 60 <= dayWx.sunsetMin + 30 &&
      _goodHour(f.hour(ds, h)) &&
      _freeAt(evs, '', h * 60, h * 60 + 60);

  Slot? best;
  var bestScore = -1e9;
  for (var h = walkStartHour; h < walkEndHour; h++) {
    if (ds == ymd(n) && h * 60 < nowMin) continue;
    if (!ok(h)) continue;
    final len = (h + 1 < 24 && ok(h + 1)) ? 2 : 1;
    var score = 0.0;
    for (var k = h; k < h + len; k++) {
      score += _hourScore(f.hour(ds, k)!);
    }
    score = score / len + len * 0.5;
    if (score > bestScore) {
      bestScore = score;
      best = Slot(ds, h * 60, (h + len) * 60, f.hour(ds, h));
    }
  }
  return best;
}

// ===== 3. 옷차림 한 줄 =====

/// ref: 기준 기온(℃) · range: 하루 일교차 · rain: 비 올 확률 %
String outfit({required double ref, required int range, required int rain}) {
  final parts = <String>[
    if (ref >= 27)
      'Light & breathable'
    else if (ref >= 23)
      'T-shirt'
    else if (ref >= 17)
      'Light shirt or cardigan'
    else if (ref >= 12)
      'Jacket or trench coat'
    else if (ref >= 6)
      'Coat & scarf'
    else if (ref >= 0)
      'Padded coat & gloves'
    else
      'Heavy coat, hat & gloves',
  ];
  if (range >= 10 && ref < 27) parts.add('dress in layers');
  if (ref >= 27) parts.add('sunscreen');
  if (rain >= rainWarnPercent) parts.add('umbrella');
  final s = parts.join(' · ');
  return s;
}

/// 그날 전체 옷차림 (아침은 더 춥게 반영)
String dayOutfit(DayWx d) => outfit(ref: d.tMin * 0.4 + d.tMax * 0.6, range: d.tMax - d.tMin, rain: d.rain);

/// 특정 시각 기준 옷차림
String hourOutfit(DayWx d, HourWx h) => outfit(ref: h.temp.toDouble(), range: d.tMax - d.tMin, rain: max(d.rain, h.rain));
