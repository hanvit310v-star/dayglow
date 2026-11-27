// 캘린더 데이터의 모양 (일정 · 할 일 · 카테고리)
// 웹 버전(index.html)의 백업 파일(JSON)과 같은 이름을 써서, 나중에 그대로 불러올 수 있게 했어요.
import 'dart:math';

final _rand = Random();

/// 겹치지 않는 고유 번호 만들기
String newId() =>
    DateTime.now().millisecondsSinceEpoch.toRadixString(36) + _rand.nextInt(1 << 20).toRadixString(36);

class CalEvent {
  String id;
  String title;
  String date; // 'YYYY-MM-DD'
  bool allDay;
  String start; // 'HH:MM'
  String end;
  String cat;
  String repeat; // none · daily · weekly · monthly
  int? remind; // 몇 분 전에 알릴지 (없으면 null)
  String memo;

  CalEvent({
    required this.id,
    required this.title,
    required this.date,
    this.allDay = false,
    this.start = '09:00',
    this.end = '10:00',
    this.cat = 'etc',
    this.repeat = 'none',
    this.remind,
    this.memo = '',
  });

  factory CalEvent.fromJson(Map<String, dynamic> j) => CalEvent(
        id: j['id'] as String,
        title: j['title'] as String,
        date: j['date'] as String,
        allDay: j['allDay'] == true,
        start: (j['start'] ?? '00:00') as String,
        end: (j['end'] ?? '23:59') as String,
        cat: (j['cat'] ?? 'etc') as String,
        repeat: (j['repeat'] ?? 'none') as String,
        remind: (j['remind'] as num?)?.toInt(),
        memo: (j['memo'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date,
        'allDay': allDay,
        'start': start,
        'end': end,
        'cat': cat,
        'repeat': repeat,
        'remind': remind,
        'memo': memo,
      };

  CalEvent copy() => CalEvent.fromJson(toJson());
}

class Todo {
  String id;
  String text;
  String due; // 마감일 'YYYY-MM-DD', 없으면 ''
  bool done;

  Todo({required this.id, required this.text, this.due = '', this.done = false});

  factory Todo.fromJson(Map<String, dynamic> j) => Todo(
        id: j['id'] as String,
        text: j['text'] as String,
        due: (j['due'] ?? '') as String,
        done: j['done'] == true,
      );

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'due': due, 'done': done};
}

class Category {
  String id;
  String name;
  String color; // '#RRGGBB'
  bool on;

  Category({required this.id, required this.name, required this.color, this.on = true});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        name: j['name'] as String,
        color: (j['color'] ?? '#a7aaa8') as String,
        on: j['on'] != false,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color, 'on': on};
}

/// 기본 카테고리 (어두운 배경에 맞춘 차분한 색) — 이름·색을 바꿔 보세요
List<Category> defaultCategories() => [
      Category(id: 'meeting', name: 'Meeting', color: '#8fb3d9'),
      Category(id: 'deadline', name: 'Deadline', color: '#e09b8f'),
      Category(id: 'personal', name: 'Personal', color: '#a3c9a8'),
      Category(id: 'etc', name: 'Other', color: '#a7aaa8'),
    ];

/// 새 카테고리를 만들 때 차례로 쓰는 색
const newCategoryColors = ['#c3a6d6', '#e3c08d', '#93c8cf', '#d9a3b8', '#d8d39a', '#a9a8dc'];
