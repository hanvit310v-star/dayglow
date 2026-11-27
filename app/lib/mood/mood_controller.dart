// 날씨·상황(분위기)을 정하는 곳
// 기본은 모두 '자동'. 분위기 패널에서 직접 고르면 그 값을 우선 사용해요.
import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/calendar_logic.dart';
import 'forecast.dart';

export 'forecast.dart' show themeOf;

// ===== 바꿔서 쓸 수 있는 기준값 =====
const weatherRefreshMinutes = 30; // 날씨를 다시 확인하는 간격
const heatC = 33, coldC = -10; // 폭염·한파 기준 기온
const windStrongKmh = 40; // 강풍 기준
const busyEvents = 5, busyFreeMinutes = 180; // 바쁜 날: 일정 5개 이상 또는 빈 시간 3시간 미만
// 위치를 못 받을 때 예보 기능에 쓰는 대체 도시 (바꾸려면 아래 3개만 고치세요)
const fallbackPlace = 'Seoul', fallbackLat = '37.57', fallbackLon = '126.98';

const weatherLabel = {
  'clear': 'Clear',
  'night': 'Clear night',
  'cloudy': 'Cloudy',
  'rain': 'Rain',
  'snow': 'Snow',
  'fog': 'Fog',
  'storm': 'Storm',
};
const todLabel = {'dawn': 'Dawn', 'day': 'Day', 'dusk': 'Dusk', 'night': 'Night'};
const tempLabel = {'normal': 'Mild', 'heat': 'Heat', 'cold': 'Cold'};

/// 확인한 날씨 (좌표는 저장하지 않음)
class WeatherInfo {
  final String theme;
  final int temp;
  final int wind;
  final String? sunrise; // 'YYYY-MM-DDTHH:MM' (그 지역 시간)
  final String? sunset;
  final int at; // 확인한 시각 (밀리초)

  const WeatherInfo({required this.theme, required this.temp, required this.wind, this.sunrise, this.sunset, required this.at});

  factory WeatherInfo.fromJson(Map<String, dynamic> j) => WeatherInfo(
        theme: j['theme'] as String,
        temp: (j['temp'] as num).toInt(),
        wind: ((j['wind'] ?? 0) as num).toInt(),
        sunrise: j['sunrise'] as String?,
        sunset: j['sunset'] as String?,
        at: (j['at'] as num).toInt(),
      );

  Map<String, dynamic> toJson() =>
      {'theme': theme, 'temp': temp, 'wind': wind, 'sunrise': sunrise, 'sunset': sunset, 'at': at};
}

class MoodController extends ChangeNotifier {
  WeatherInfo? wx;
  final Forecast forecast = Forecast(); // 16일치 예보 (화면들이 같은 객체를 함께 봐요)
  String weatherMode = 'auto'; // auto 또는 직접 고른 날씨
  String todMode = 'auto';
  String tempMode = 'auto';
  int intensity = 100; // 효과 세기 0~100
  bool busyCalm = true;
  bool focus = true;
  String status = '';
  bool _fetching = false;
  SharedPreferences? _prefs;

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    try {
      final w = p.getString('cal_weather');
      if (w != null) wx = WeatherInfo.fromJson(jsonDecode(w) as Map<String, dynamic>);
      final f = p.getString('cal_forecast');
      if (f != null) forecast.setFrom(Forecast.fromJson(jsonDecode(f) as Map<String, dynamic>));
      final m = p.getString('cal_mood');
      if (m != null) {
        final j = jsonDecode(m) as Map<String, dynamic>;
        weatherMode = (j['weather'] ?? 'auto') as String;
        todMode = (j['tod'] ?? 'auto') as String;
        tempMode = (j['temp'] ?? 'auto') as String;
        intensity = ((j['intensity'] ?? 100) as num).toInt();
        busyCalm = j['busyCalm'] != false;
        focus = j['focus'] != false;
      }
    } catch (_) {/* 저장된 값이 이상하면 기본값 사용 */}
  }

  void _persist() {
    _prefs?.setString('cal_mood', jsonEncode({
      'weather': weatherMode,
      'tod': todMode,
      'temp': tempMode,
      'intensity': intensity,
      'busyCalm': busyCalm,
      'focus': focus,
    }));
    final w = wx;
    if (w != null) _prefs?.setString('cal_weather', jsonEncode(w.toJson()));
    notifyListeners();
  }

  // ===== 지금 적용할 값 =====
  String get theme => weatherMode != 'auto' ? weatherMode : (wx?.theme ?? 'rain');

  /// 해 뜨고 지는 시각으로 시간대 판단 (정보가 없으면 06:30 / 18:00)
  String autoTod([DateTime? at]) {
    final now = at ?? DateTime.now();
    DateTime sr = DateTime(now.year, now.month, now.day, 6, 30);
    DateTime ss = DateTime(now.year, now.month, now.day, 18);
    final w = wx;
    if (w != null && w.sunrise != null && w.sunset != null && w.sunrise!.startsWith(ymd(now))) {
      sr = DateTime.tryParse(w.sunrise!) ?? sr;
      ss = DateTime.tryParse(w.sunset!) ?? ss;
    }
    Duration m(int n) => Duration(minutes: n);
    if (!now.isBefore(sr.subtract(m(45))) && now.isBefore(sr.add(m(45)))) return 'dawn';
    if (!now.isBefore(ss.subtract(m(60))) && now.isBefore(ss.add(m(30)))) return 'dusk';
    return (!now.isBefore(sr) && now.isBefore(ss)) ? 'day' : 'night';
  }

  String? get autoTemp {
    final w = wx;
    if (w == null) return null;
    return w.temp >= heatC ? 'heat' : (w.temp <= coldC ? 'cold' : 'normal');
  }

  String get tod => todMode != 'auto' ? todMode : autoTod();
  String get temp => tempMode != 'auto' ? tempMode : (autoTemp ?? 'normal');
  bool get windStrong => weatherMode == 'auto' && (wx?.wind ?? 0) >= windStrongKmh;

  /// '맑음 · 노을 · 폭염'
  String get label {
    final parts = [weatherLabel[theme]!];
    final t = tod;
    if (t == 'dawn' || t == 'dusk' || (t == 'night' && theme != 'night')) parts.add(todLabel[t]!);
    if (temp != 'normal') parts.add(tempLabel[temp]!);
    return parts.join(' · ');
  }

  String get statusText {
    final parts = <String>[];
    final w = wx;
    if (w != null) {
      final m = (DateTime.now().millisecondsSinceEpoch - w.at) ~/ 60000;
      parts.add('내 위치: ${weatherLabel[w.theme]} ${w.temp}° · ${m > 0 ? '$m분 전 확인' : '방금 확인'}');
    }
    if (weatherMode != 'auto') parts.add('날씨는 직접 고른 ${weatherLabel[weatherMode]} 테마를 쓰는 중');
    if (status.isNotEmpty) parts.add(status);
    return parts.join(' · ');
  }

  // ===== 날씨 확인: 위치(앱 사용 중에만) → Open-Meteo(무료·키 없음) =====
  // 현재 날씨와 16일 예보를 한 번에 받아요. 위치를 못 받으면 대체 도시(서울) 예보만 받아요.
  Future<void> refresh({bool force = false}) async {
    final w = wx;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final wxFresh = w == null || nowMs - w.at < weatherRefreshMinutes * 60000;
    if (!force && forecast.fresh(weatherRefreshMinutes) && wxFresh) {
      notifyListeners();
      return;
    }
    if (_fetching) return;
    _fetching = true;
    status = '위치를 확인하는 중…';
    notifyListeners();
    try {
      final loc = await _locate();
      final here = loc != null;
      final lat = loc?.lat ?? fallbackLat, lon = loc?.lon ?? fallbackLon;
      final res = await http
          .get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
              '&current=temperature_2m,weather_code,is_day,wind_speed_10m'
              '&hourly=temperature_2m,weather_code,precipitation_probability'
              '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset'
              '&timezone=auto&past_days=1&forecast_days=16'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('weather ${res.statusCode}');
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final now = DateTime.now().millisecondsSinceEpoch;
      forecast.setFrom(Forecast.parse(j, place: here ? 'Here' : fallbackPlace, at: now));
      _prefs?.setString('cal_forecast', jsonEncode(forecast.toJson()));
      if (here) {
        final c = j['current'] as Map<String, dynamic>;
        final d = j['daily'] as Map<String, dynamic>?;
        final today = (d?['time'] as List?)?.indexOf(todayStr()) ?? -1;
        final i = today < 0 ? 0 : today;
        wx = WeatherInfo(
          theme: themeOf((c['weather_code'] as num).toInt(), c['is_day'] == 1),
          temp: (c['temperature_2m'] as num).round(),
          wind: ((c['wind_speed_10m'] ?? 0) as num).round(),
          sunrise: (d?['sunrise'] as List?)?[i] as String?,
          sunset: (d?['sunset'] as List?)?[i] as String?,
          at: now,
        );
        status = '';
      } else {
        status = '$status 예보 기능은 $fallbackPlace 기준으로 보여줘요.';
      }
    } on TimeoutException {
      status = '날씨 확인이 오래 걸려 기본 테마를 써요.';
    } catch (_) {
      status = '날씨를 가져오지 못했어요. 인터넷 연결을 확인해 주세요.';
    } finally {
      _fetching = false;
      _persist();
    }
  }

  /// 대략적인 위치(약 1km 단위로 뭉갬, 저장하지 않음). 못 받으면 이유를 status에 적고 null
  Future<({String lat, String lon})?> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        status = '기기의 위치 서비스가 꺼져 있어 기본 테마를 써요.';
        return null;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        status = '위치 권한이 꺼져 있어 기본 테마를 써요.';
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 15));
      return (lat: pos.latitude.toStringAsFixed(2), lon: pos.longitude.toStringAsFixed(2));
    } on TimeoutException {
      status = '위치 확인이 오래 걸려 기본 테마를 써요.';
      return null;
    } catch (_) {
      status = '위치를 확인하지 못해 기본 테마를 써요.';
      return null;
    }
  }

  // ===== 분위기 패널에서 직접 고르기 =====
  void setWeatherMode(String v) {
    weatherMode = v;
    _persist();
  }

  void setTodMode(String v) {
    todMode = v;
    _persist();
  }

  void setTempMode(String v) {
    tempMode = v;
    _persist();
  }

  void setIntensity(int v) {
    intensity = v;
    _persist();
  }

  void setBusyCalm(bool v) {
    busyCalm = v;
    _persist();
  }

  void setFocus(bool v) {
    focus = v;
    _persist();
  }

  void resetAll() {
    weatherMode = todMode = tempMode = 'auto';
    intensity = 100;
    busyCalm = focus = true;
    _persist();
  }
}
