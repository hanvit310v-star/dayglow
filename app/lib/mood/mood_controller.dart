// 날씨·상황(분위기)을 정하는 곳
// 기본은 모두 '자동'. 분위기 패널에서 직접 고르면 그 값을 우선 사용해요.
import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/calendar_logic.dart';

// ===== 바꿔서 쓸 수 있는 기준값 =====
const weatherRefreshMinutes = 30; // 날씨를 다시 확인하는 간격
const heatC = 33, coldC = -10; // 폭염·한파 기준 기온
const windStrongKmh = 40; // 강풍 기준
const busyEvents = 5, busyFreeMinutes = 180; // 바쁜 날: 일정 5개 이상 또는 빈 시간 3시간 미만

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

/// 세계기상기구(WMO) 날씨 코드 → 테마
String themeOf(int code, bool isDay) {
  if ([95, 96, 99].contains(code)) return 'storm';
  if ([71, 73, 75, 77, 85, 86].contains(code)) return 'snow';
  if ((code >= 51 && code <= 67) || [80, 81, 82].contains(code)) return 'rain';
  if ([45, 48].contains(code)) return 'fog';
  if ([2, 3].contains(code)) return 'cloudy';
  return isDay ? 'clear' : 'night';
}

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
  Future<void> refresh({bool force = false}) async {
    final w = wx;
    if (!force && w != null && DateTime.now().millisecondsSinceEpoch - w.at < weatherRefreshMinutes * 60000) {
      notifyListeners();
      return;
    }
    if (_fetching) return;
    _fetching = true;
    status = '위치를 확인하는 중…';
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        status = '기기의 위치 서비스가 꺼져 있어 기본 테마를 써요.';
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        status = '위치 권한이 꺼져 있어 기본 테마를 써요.';
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 15));
      // 약 1km 단위로 뭉개서 보냄. 좌표는 저장하지 않음
      final lat = pos.latitude.toStringAsFixed(2), lon = pos.longitude.toStringAsFixed(2);
      final res = await http
          .get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
              '&current=temperature_2m,weather_code,is_day,wind_speed_10m&daily=sunrise,sunset&timezone=auto&forecast_days=1'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('weather ${res.statusCode}');
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final c = j['current'] as Map<String, dynamic>;
      final d = j['daily'] as Map<String, dynamic>?;
      wx = WeatherInfo(
        theme: themeOf((c['weather_code'] as num).toInt(), c['is_day'] == 1),
        temp: (c['temperature_2m'] as num).round(),
        wind: ((c['wind_speed_10m'] ?? 0) as num).round(),
        sunrise: (d?['sunrise'] as List?)?.first as String?,
        sunset: (d?['sunset'] as List?)?.first as String?,
        at: DateTime.now().millisecondsSinceEpoch,
      );
      status = '';
    } on TimeoutException {
      status = '위치·날씨 확인이 오래 걸려 기본 테마를 써요.';
    } catch (_) {
      status = '날씨를 가져오지 못했어요. 인터넷 연결을 확인해 주세요.';
    } finally {
      _fetching = false;
      _persist();
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
