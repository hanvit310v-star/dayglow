// 날짜 계산이 웹 버전과 같게 동작하는지 확인하는 자동 테스트
import 'package:flutter_test/flutter_test.dart';
import 'package:dayglow/core/calendar_logic.dart';
import 'package:dayglow/core/models.dart';
import 'package:dayglow/mood/forecast.dart';

void main() {
  test('반복 일정이 맞는 날짜에 나타난다', () {
    final weekly = CalEvent(id: 'a', title: '회의', date: '2026-11-26', repeat: 'weekly');
    expect(occursOn(weekly, '2026-11-26'), isTrue);
    expect(occursOn(weekly, '2026-12-03'), isTrue);
    expect(occursOn(weekly, '2026-12-04'), isFalse);
    expect(occursOn(weekly, '2026-11-19'), isFalse); // 시작 전
    final monthly = CalEvent(id: 'b', title: '월세', date: '2026-11-26', repeat: 'monthly');
    expect(occursOn(monthly, '2026-12-26'), isTrue);
  });

  test('겹치는 일정은 옆으로 나란히 배치된다', () {
    final placed = layoutDay([
      CalEvent(id: '1', title: 'A', date: '2026-11-26', start: '10:00', end: '11:00'),
      CalEvent(id: '2', title: 'B', date: '2026-11-26', start: '10:30', end: '12:00'),
      CalEvent(id: '3', title: 'C', date: '2026-11-26', start: '13:00', end: '14:00'),
    ]);
    expect(placed.firstWhere((p) => p.e.id == '2').col, 1);
    expect(placed.firstWhere((p) => p.e.id == '1').cols, 2);
    expect(placed.firstWhere((p) => p.e.id == '3').cols, 1);
  });

  test('날씨 코드가 맞는 테마로 바뀐다', () {
    expect(themeOf(0, true), 'clear');
    expect(themeOf(0, false), 'night');
    expect(themeOf(3, true), 'cloudy');
    expect(themeOf(61, true), 'rain');
    expect(themeOf(73, true), 'snow');
    expect(themeOf(95, true), 'storm');
  });

  // ===== 날씨 예보 기능 (가짜 예보로 계산만 확인) =====
  final now = DateTime(2026, 11, 27, 8, 0);
  const sunny = HourWx(0, 18, 0);
  const rainy = HourWx(61, 14, 80);

  DayWx day(String ds, HourWx Function(int h) f) =>
      DayWx(ds: ds, code: 0, tMax: 20, tMin: 10, rain: 0, hours: [for (var h = 0; h < 24; h++) f(h)]);
  Forecast fc(Map<String, HourWx Function(int)> days) {
    final f = Forecast();
    days.forEach((ds, fn) => f.days[ds] = day(ds, fn));
    return f;
  }

  List<CalEvent> none(String ds) => [];

  test('야외 일정이 비 오는 시간과 겹치면 경고한다', () {
    final f = fc({'2026-11-28': (h) => h == 15 ? rainy : sunny});
    final out = CalEvent(id: 'o', title: '러닝', date: '2026-11-28', start: '14:00', end: '16:00', outdoor: true);
    final risk = rainRisk(out, '2026-11-28', f, now: now);
    expect(risk, isNotNull);
    expect(risk!.fromHour, 15);
    expect(risk.toHour, 16);
    expect(risk.maxRain, 80);
    // 야외가 아니거나 비 안 오는 시간이면 경고 없음
    expect(rainRisk(out..outdoor = false, '2026-11-28', f, now: now), isNull);
    final dry = CalEvent(id: 'd', title: '러닝', date: '2026-11-28', start: '09:00', end: '10:00', outdoor: true);
    expect(rainRisk(dry, '2026-11-28', f, now: now), isNull);
    // 이미 지난 날은 경고 없음
    expect(rainRisk(CalEvent(id: 'p', title: 'x', date: '2026-11-26', start: '15:00', end: '16:00', outdoor: true), '2026-11-26', f, now: now), isNull);
  });

  test('비 오는 일정의 대체 시간은 맑고 안 겹치는 가까운 날이다', () {
    final f = fc({
      '2026-11-28': (h) => rainy, // 원래 날은 종일 비
      '2026-11-29': (h) => sunny,
      '2026-11-30': (h) => sunny,
    });
    final e = CalEvent(id: 'o', title: '러닝', date: '2026-11-28', start: '14:00', end: '15:00', outdoor: true);
    final busy = CalEvent(id: 'b', title: '회의', date: '2026-11-29', start: '13:00', end: '16:00');
    final slots = betterSlots(e, '2026-11-28', f, (ds) => ds == '2026-11-29' ? [busy] : [], now: now);
    expect(slots.first.ds, '2026-11-29');
    // 회의(13~16시)와 안 겹치는 시간 (12시·16시는 원래 시각 14시에서 똑같이 가까워 둘 다 맞음)
    expect(slots.first.endMin <= 13 * 60 || slots.first.startMin >= 16 * 60, isTrue);
    expect([12 * 60, 16 * 60], contains(slots.first.startMin));
    expect(slots.map((s) => s.ds).toSet().length, slots.length); // 하루에 하나
    expect(slots.every((s) => s.ds != '2026-11-28'), isTrue);
  });

  test('산책 시간은 비어 있고 날씨 좋은 시간만 고른다', () {
    final f = fc({'2026-11-28': (h) => h < 15 ? rainy : sunny});
    final busy = CalEvent(id: 'b', title: '회의', date: '2026-11-28', start: '15:00', end: '17:00');
    final w = walkWindow('2026-11-28', f, (ds) => [busy], now: now);
    expect(w, isNotNull);
    expect(w!.startMin, 17 * 60); // 15시 전은 비, 15~17시는 일정
    expect(walkWindow('2026-11-28', fc({'2026-11-28': (h) => rainy}), none, now: now), isNull);
    // 해가 진 뒤(기본 일몰 18:00 + 30분)는 추천하지 않음: 종일 맑아도 19시 이후 시작은 없다
    expect(walkWindow('2026-11-28', fc({'2026-11-28': (h) => h >= 19 ? sunny : rainy}), none, now: now), isNull);
    // 오늘이면 이미 지난 시간은 제외
    final late = walkWindow('2026-11-27', fc({'2026-11-27': (h) => sunny}), none, now: DateTime(2026, 11, 27, 13, 30));
    expect(late!.startMin >= 13 * 60 + 30, isTrue);
  });

  test('옷차림 한 줄: 기온에 맞고, 비·일교차를 덧붙인다', () {
    expect(outfit(ref: 30, range: 5, rain: 0), contains('Light & breathable'));
    expect(outfit(ref: 14, range: 5, rain: 0), 'Jacket or trench coat');
    expect(outfit(ref: 3, range: 12, rain: 70), 'Padded coat & gloves · dress in layers · umbrella');
  });

  test('예보를 저장했다 불러와도 같고, 야외 표시도 보존된다', () {
    final f = fc({'2026-11-28': (h) => h == 15 ? rainy : sunny})..place = 'Seoul';
    final back = Forecast.fromJson(f.toJson());
    expect(back.place, 'Seoul');
    expect(back.hour('2026-11-28', 15)!.rain, 80);
    expect(back.hour('2026-11-28', 3)!.theme, 'clear');
    final ev = CalEvent(id: 'a', title: 'x', date: '2026-11-28', outdoor: true);
    expect(CalEvent.fromJson(ev.toJson()).outdoor, isTrue);
    expect(CalEvent.fromJson({'id': 'a', 'title': 'x', 'date': '2026-11-28'}).outdoor, isFalse); // 옛 백업 파일
  });
}
