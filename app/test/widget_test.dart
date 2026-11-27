// 날짜 계산이 웹 버전과 같게 동작하는지 확인하는 자동 테스트
import 'package:flutter_test/flutter_test.dart';
import 'package:dayglow/core/calendar_logic.dart';
import 'package:dayglow/core/models.dart';
import 'package:dayglow/mood/mood_controller.dart';

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
}
