// 일정·할 일·카테고리를 기기에 저장하고 꺼내 쓰는 곳
// 지금은 기기 안에만 저장해요(오프라인 우선). 로그인 단계에서 이 파일에 서버(Supabase) 동기화를 붙여요.
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/calendar_logic.dart';
import '../core/models.dart';

/// '활동 시간' — 비어 있는 시간을 계산하는 범위 (9시~22시)
const activeHours = (start: 9, end: 22);

class CalendarStore extends ChangeNotifier {
  List<CalEvent> events = [];
  List<Todo> todos = [];
  List<Category> cats = defaultCategories();
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    events = _readList('cal_events', CalEvent.fromJson);
    todos = _readList('cal_todos', Todo.fromJson);
    final c = _readList('cal_cats', Category.fromJson);
    if (c.isNotEmpty) cats = c;
  }

  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) f) {
    final s = _prefs?.getString(key);
    if (s == null) return [];
    try {
      return (jsonDecode(s) as List)
          .map((x) {
            try {
              return f(Map<String, dynamic>.from(x as Map));
            } catch (_) {
              return null; // 모양이 이상한 항목은 건너뜀
            }
          })
          .whereType<T>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _save() {
    final p = _prefs;
    if (p != null) {
      p.setString('cal_events', jsonEncode(events.map((e) => e.toJson()).toList()));
      p.setString('cal_todos', jsonEncode(todos.map((e) => e.toJson()).toList()));
      p.setString('cal_cats', jsonEncode(cats.map((e) => e.toJson()).toList()));
    }
    notifyListeners();
  }

  // ===== 읽기 =====
  Category catOf(String id) => cats.firstWhere((c) => c.id == id, orElse: () => cats.last);

  List<CalEvent> eventsOn(String ds, {bool onlyVisible = true}) {
    final list = events.where((e) => occursOn(e, ds) && (!onlyVisible || catOf(e.cat).on)).toList();
    list.sort((a, b) {
      if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
      return a.start.compareTo(b.start);
    });
    return list;
  }

  /// 그날 마감인 할 일 + (오늘이면) 밀린 할 일을 맨 위에
  List<({Todo t, bool over})> todosOn(String ds) {
    final today = todayStr();
    final list = todos.where((t) => t.due == ds).map((t) => (t: t, over: !t.done && t.due.compareTo(today) < 0)).toList();
    if (ds == today) {
      final late = todos.where((t) => t.due.isNotEmpty && t.due.compareTo(today) < 0 && !t.done);
      list.insertAll(0, late.map((t) => (t: t, over: true)));
    }
    return list;
  }

  List<Todo> get undatedTodos => todos.where((t) => t.due.isEmpty).toList();

  int get overdueCount {
    final today = todayStr();
    return todos.where((t) => t.due.isNotEmpty && t.due.compareTo(today) < 0 && !t.done).length;
  }

  /// 활동 시간 안에서 일정이 없는 시간(분)
  int freeMinutes(String ds) {
    final a = activeHours.start * 60, b = activeHours.end * 60;
    final iv = eventsOn(ds)
        .where((e) => !e.allDay)
        .map((e) => (s: toMin(e.start).clamp(a, b), e: toMin(e.end).clamp(a, b)))
        .where((x) => x.e > x.s)
        .toList()
      ..sort((x, y) => x.s.compareTo(y.s));
    var used = 0, cs = -1, ce = -1;
    for (final x in iv) {
      if (x.s > ce) {
        if (ce > cs) used += ce - cs;
        cs = x.s;
        ce = x.e;
      } else if (x.e > ce) {
        ce = x.e;
      }
    }
    if (ce > cs) used += ce - cs;
    return b - a - used;
  }

  /// 지금 진행 중인 일정 (없으면 null)
  CalEvent? nowEvent() {
    final now = DateTime.now();
    final m = now.hour * 60 + now.minute;
    for (final e in eventsOn(todayStr())) {
      if (!e.allDay && toMin(e.start) <= m && m < toMin(e.end)) return e;
    }
    return null;
  }

  /// 같은 시간에 겹치는 일정
  List<CalEvent> overlaps(CalEvent c) {
    if (c.allDay) return [];
    final s = toMin(c.start), e = toMin(c.end);
    return events
        .where((o) => o.id != c.id && !o.allDay && occursOn(o, c.date) && toMin(o.start) < e && toMin(o.end) > s)
        .toList();
  }

  // ===== 쓰기 =====
  void upsertEvent(CalEvent e) {
    final i = events.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      events[i] = e;
    } else {
      events.add(e);
    }
    _save();
  }

  void deleteEvent(String id) {
    events.removeWhere((e) => e.id == id);
    _save();
  }

  void addTodo(String text, {String due = ''}) {
    todos.add(Todo(id: newId(), text: text, due: due));
    _save();
  }

  void updateTodo(String id, {required String text, required String due, required bool done}) {
    final t = todos.firstWhere((x) => x.id == id);
    t
      ..text = text
      ..due = due
      ..done = done;
    _save();
  }

  void toggleTodo(String id) {
    final t = todos.firstWhere((x) => x.id == id);
    t.done = !t.done;
    _save();
  }

  void deleteTodo(String id) {
    todos.removeWhere((t) => t.id == id);
    _save();
  }

  int clearDoneUndated() {
    final n = todos.where((t) => t.due.isEmpty && t.done).length;
    todos.removeWhere((t) => t.due.isEmpty && t.done);
    _save();
    return n;
  }

  void setCategoryOn(String id, bool on) {
    cats.firstWhere((c) => c.id == id).on = on;
    _save();
  }

  Category addCategory(String name) {
    final c = Category(id: 'c${newId()}', name: name, color: newCategoryColors[cats.length % newCategoryColors.length]);
    cats.add(c);
    _save();
    return c;
  }
}
