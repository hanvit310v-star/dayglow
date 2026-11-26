// 날짜 계산 도구 (화면·기기와 상관없는 공통 기능)
import 'models.dart';

const weekdayKo = ['일', '월', '화', '수', '목', '금', '토'];

String pad2(int n) => n.toString().padLeft(2, '0');

String ymd(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';

DateTime parseYmd(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 'HH:MM' → 하루 중 몇 분째인지
int toMin(String t) {
  final p = t.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// 일요일=0 … 토요일=6 (웹 버전과 같은 순서)
int weekdayIndex(DateTime d) => d.weekday % 7;

String todayStr() => ymd(DateTime.now());

/// '11/26' 형태
String monthDay(String ds) => '${int.parse(ds.substring(5, 7))}/${int.parse(ds.substring(8))}';

/// 이 일정이 해당 날짜에 나타나는가 (반복 규칙 계산)
bool occursOn(CalEvent ev, String ds) {
  if (ds.compareTo(ev.date) < 0) return false;
  switch (ev.repeat) {
    case 'daily':
      return true;
    case 'weekly':
      return parseYmd(ev.date).weekday == parseYmd(ds).weekday;
    case 'monthly':
      return parseYmd(ev.date).day == parseYmd(ds).day;
    default:
      return ds == ev.date;
  }
}

/// 하루 칸 안에서 겹치는 일정을 옆으로 나란히 배치하기 위한 정보
class PlacedEvent {
  final CalEvent e;
  final int startMin;
  final int endMin;
  int col = 0;
  int cols = 1;
  PlacedEvent(this.e, this.startMin, this.endMin);
}

List<PlacedEvent> layoutDay(List<CalEvent> evs) {
  final list = evs
      .where((e) => !e.allDay)
      .map((e) {
        final s = toMin(e.start);
        final en = toMin(e.end);
        return PlacedEvent(e, s, en > s + 20 ? en : s + 20);
      })
      .toList()
    ..sort((a, b) => a.startMin.compareTo(b.startMin));
  final out = <PlacedEvent>[];
  var cluster = <PlacedEvent>[];
  var clusterEnd = -1;
  void flush() {
    if (cluster.isEmpty) return;
    final n = cluster.map((x) => x.col).reduce((a, b) => a > b ? a : b) + 1;
    for (final x in cluster) {
      x.cols = n;
    }
    out.addAll(cluster);
    cluster = [];
  }

  for (final x in list) {
    if (cluster.isNotEmpty && x.startMin >= clusterEnd) flush();
    final used = cluster.where((y) => y.endMin > x.startMin).map((y) => y.col).toSet();
    var col = 0;
    while (used.contains(col)) {
      col++;
    }
    x.col = col;
    cluster.add(x);
    if (x.endMin > clusterEnd) clusterEnd = x.endMin;
  }
  flush();
  return out;
}

/// '9h 30m' 형태
String hoursMinutes(int m) {
  if (m <= 0) return '0m';
  final h = m ~/ 60, r = m % 60;
  return [if (h > 0) '${h}h', if (r > 0) '${r}m'].join(' ');
}
