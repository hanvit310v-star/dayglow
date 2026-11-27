// 일정·할 일·카테고리를 저장하고 꺼내 쓰는 곳
// - 기본: 기기 안에 저장해요 (오프라인에서도 항상 동작)
// - 로그인하면: 서버(Firebase Firestore)에도 저장하고, 다른 기기에서 바꾼 내용을 실시간으로 받아와요
//   (같은 일정을 두 기기에서 동시에 고치면 '나중에 저장한 쪽'이 남아요)
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/calendar_logic.dart';
import '../core/models.dart';
import 'sync_service.dart';

/// '활동 시간' — 비어 있는 시간을 계산하는 범위 (9시~22시)
const activeHours = (start: 9, end: 22);

class CalendarStore extends ChangeNotifier {
  List<CalEvent> events = [];
  List<Todo> todos = [];
  List<Checklist> lists = []; // 체크리스트
  List<Category> cats = defaultCategories();
  SharedPreferences? _prefs;

  SyncService? sync;
  String? _syncUid; // 지금 서버와 연결 중인 계정
  final List<StreamSubscription> _subs = [];

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    events = _readList('cal_events', CalEvent.fromJson);
    todos = _readList('cal_todos', Todo.fromJson);
    lists = _readList('cal_lists', Checklist.fromJson);
    final c = _readList('cal_cats', Category.fromJson);
    if (c.isNotEmpty) cats = c;
  }

  // ===== 서버 동기화 =====
  /// 로그인 서비스를 연결해요. 로그인하면 서버와 이어지고, 로그아웃하면 끊어져요.
  void attachSync(SyncService s) {
    sync = s;
    s.addListener(notifyListeners); // 로그인 상태가 바뀌면 화면도 다시 그림
    s.onUserChanged = _onUserChanged;
    s.start();
  }

  bool get signedIn => sync?.user != null;

  Future<void> _onUserChanged(User? u) async {
    if (u == null) {
      await _stopListening(); // 로그아웃·로그인 만료: 서버와 끊기만 해요 (기기 안 사본은 그대로)
      return;
    }
    if (_syncUid == u.uid) return;
    await _stopListening();
    _syncUid = u.uid;
    sync?.setLoading(true);
    try {
      await _firstMerge(u.uid);
      _listen(u.uid);
      sync?.setLoading(false);
    } catch (e) {
      sync?.setLoading(false, err: syncErrorText(e));
    }
  }

  Future<void> _stopListening() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _syncUid = null;
  }

  /// 이 기기에서 이 계정으로 처음 로그인할 때 한 번만: 기기 안 일정을 서버에 합쳐 올려요.
  /// (같은 번호의 일정은 서버 것을 남기고, 기기에만 있던 것은 서버로 올려요)
  Future<void> _firstMerge(String uid) async {
    if (_prefs?.getString('cal_synced_uid') == uid) return;
    final s = sync!;
    // 서버 상태를 직접 확인 (인터넷이 없으면 여기서 오류 → 다음 실행 때 다시 시도)
    const src = GetOptions(source: Source.server);
    final res = await Future.wait([s.col('events', uid).get(src), s.col('todos', uid).get(src), s.col('cats', uid).get(src), s.col('lists', uid).get(src)]);
    final cloudEv = res[0].docs.map((d) => d.id).toSet();
    final cloudTodo = res[1].docs.map((d) => d.id).toSet();
    final cloudCat = res[2].docs.map((d) => d.id).toSet();
    final cloudList = res[3].docs.map((d) => d.id).toSet();

    final batch = FirebaseFirestore.instance.batch();
    for (final e in events.where((e) => !cloudEv.contains(e.id))) {
      batch.set(s.col('events', uid).doc(e.id), _payload(e.toJson()));
    }
    for (final t in todos.where((t) => !cloudTodo.contains(t.id))) {
      batch.set(s.col('todos', uid).doc(t.id), _payload(t.toJson()));
    }
    for (final l in lists.where((l) => !cloudList.contains(l.id))) {
      batch.set(s.col('lists', uid).doc(l.id), _payload(l.toJson()));
    }
    for (var i = 0; i < cats.length; i++) {
      final c = cats[i];
      if (!cloudCat.contains(c.id)) batch.set(s.col('cats', uid).doc(c.id), _payload(c.toJson(), order: cloudCat.length + i));
    }
    // 서버가 느려도 앱이 멈추지 않게 결과를 기다리지 않아요 (기기가 알아서 재시도)
    unawaited(batch.commit().catchError((Object e) => debugPrint('처음 올리기 실패: $e')));
    await _prefs?.setString('cal_synced_uid', uid);
  }

  /// 서버 변경을 실시간으로 받기 — 다른 기기에서 바꾸면 여기로 들어와요
  void _listen(String uid) {
    final s = sync!;
    void onErr(Object e) => s.setLoading(false, err: syncErrorText(e));

    _subs.add(s.col('events', uid).snapshots().listen((snap) {
      events = _parse(snap, CalEvent.fromJson);
      _saveLocal();
      notifyListeners();
    }, onError: onErr));

    _subs.add(s.col('todos', uid).snapshots().listen((snap) {
      todos = _parse(snap, Todo.fromJson)..sort((a, b) => a.id.compareTo(b.id));
      _saveLocal();
      notifyListeners();
    }, onError: onErr));

    _subs.add(s.col('lists', uid).snapshots().listen((snap) {
      lists = _parse(snap, Checklist.fromJson)..sort((a, b) => a.id.compareTo(b.id));
      _saveLocal();
      notifyListeners();
    }, onError: onErr));

    _subs.add(s.col('cats', uid).snapshots().listen((snap) {
      final docs = [...snap.docs]..sort((a, b) => ((a.data()['order'] ?? 0) as num).compareTo((b.data()['order'] ?? 0) as num));
      final list = docs
          .map((d) {
            try {
              return Category.fromJson({...d.data(), 'id': d.id});
            } catch (_) {
              return null;
            }
          })
          .whereType<Category>()
          .toList();
      if (list.isNotEmpty) cats = list; // 서버에 아직 없으면 기본 카테고리를 그대로 써요
      _saveLocal();
      notifyListeners();
    }, onError: onErr));
  }

  List<T> _parse<T>(QuerySnapshot<Map<String, dynamic>> snap, T Function(Map<String, dynamic>) f) => snap.docs
      .map((d) {
        try {
          return f({...d.data(), 'id': d.id});
        } catch (_) {
          return null; // 모양이 이상한 항목은 건너뜀
        }
      })
      .whereType<T>()
      .toList();

  /// 서버에 저장할 내용 (수정 시각을 함께 기록)
  Map<String, dynamic> _payload(Map<String, dynamic> json, {int? order}) =>
      {...json, 'updatedAt': FieldValue.serverTimestamp(), 'order': ?order};

  void _cloudSet(String name, String id, Map<String, dynamic> json, {int? order}) {
    final uid = _syncUid;
    if (uid == null || sync == null) return;
    // 서버 확인은 기다리지 않아요. 인터넷이 없으면 기기가 모아 두었다가 연결되면 올려요.
    sync!.col(name, uid).doc(id).set(_payload(json, order: order)).catchError((Object e) {
      sync?.setLoading(false, err: syncErrorText(e));
    });
  }

  void _cloudDelete(String name, String id) {
    final uid = _syncUid;
    if (uid == null || sync == null) return;
    sync!.col(name, uid).doc(id).delete().catchError((Object e) {
      sync?.setLoading(false, err: syncErrorText(e));
    });
  }

  /// 로그아웃: 이 기기의 일정은 지우고(서버에는 그대로 있어요), 다시 로그인하면 불러와요
  Future<void> signOut() async {
    final s = sync;
    if (s == null) return;
    try {
      // 아직 서버에 못 올린 변경이 있으면 잠깐 기다려요 (최대 3초)
      await FirebaseFirestore.instance.waitForPendingWrites().timeout(const Duration(seconds: 3));
    } catch (_) {}
    await _stopListening();
    await s.signOut();
    _clearLocal();
  }

  /// 계정 삭제: 서버의 내 데이터를 모두 지운 뒤 계정을 지워요. 실패하면 오류 문장을, 성공하면 null 을 돌려줘요.
  Future<String?> deleteAccount() async {
    final s = sync;
    final uid = s?.user?.uid;
    if (s == null || uid == null) return '로그인되어 있지 않아요.';
    try {
      await _stopListening();
      for (final name in const ['events', 'todos', 'cats', 'lists']) {
        final snap = await s.col(name, uid).get(const GetOptions(source: Source.server));
        for (var i = 0; i < snap.docs.length; i += 400) {
          final batch = FirebaseFirestore.instance.batch();
          for (final d in snap.docs.skip(i).take(400)) {
            batch.delete(d.reference);
          }
          await batch.commit();
        }
      }
      await s.deleteAuthUser();
      _clearLocal();
      return null;
    } catch (e) {
      // 데이터는 지워졌어도 계정 삭제가 막힐 수 있어요(다시 로그인 필요). 서버 연결은 다시 이어 줘요.
      if (s.user != null) unawaited(_onUserChanged(s.user));
      return syncErrorText(e);
    }
  }

  void _clearLocal() {
    events = [];
    todos = [];
    lists = [];
    cats = defaultCategories();
    _prefs?.remove('cal_synced_uid');
    _saveLocal();
    notifyListeners();
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

  /// 기기 안에 저장 (로그인 전에도, 오프라인에서도 쓰이는 사본)
  void _saveLocal() {
    final p = _prefs;
    if (p != null) {
      p.setString('cal_events', jsonEncode(events.map((e) => e.toJson()).toList()));
      p.setString('cal_todos', jsonEncode(todos.map((e) => e.toJson()).toList()));
      p.setString('cal_lists', jsonEncode(lists.map((e) => e.toJson()).toList()));
      p.setString('cal_cats', jsonEncode(cats.map((e) => e.toJson()).toList()));
    }
  }

  void _save() {
    _saveLocal();
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

  /// 그날 마감인 체크리스트
  List<Checklist> listsDue(String ds) => lists.where((l) => l.due == ds).toList();

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

  // ===== 쓰기 (기기 안에 저장 + 로그인 중이면 서버에도 저장) =====
  void upsertEvent(CalEvent e) {
    final i = events.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      events[i] = e;
    } else {
      events.add(e);
    }
    _save();
    _cloudSet('events', e.id, e.toJson());
  }

  void deleteEvent(String id) {
    events.removeWhere((e) => e.id == id);
    _save();
    _cloudDelete('events', id);
  }

  void addTodo(String text, {String due = ''}) {
    final t = Todo(id: newId(), text: text, due: due);
    todos.add(t);
    _save();
    _cloudSet('todos', t.id, t.toJson());
  }

  void updateTodo(String id, {required String text, required String due, required bool done}) {
    final t = todos.firstWhere((x) => x.id == id);
    t
      ..text = text
      ..due = due
      ..done = done;
    _save();
    _cloudSet('todos', t.id, t.toJson());
  }

  void toggleTodo(String id) {
    final t = todos.firstWhere((x) => x.id == id);
    t.done = !t.done;
    _save();
    _cloudSet('todos', t.id, t.toJson());
  }

  void deleteTodo(String id) {
    todos.removeWhere((t) => t.id == id);
    _save();
    _cloudDelete('todos', id);
  }

  int clearDoneUndated() {
    final gone = todos.where((t) => t.due.isEmpty && t.done).toList();
    todos.removeWhere((t) => t.due.isEmpty && t.done);
    _save();
    for (final t in gone) {
      _cloudDelete('todos', t.id);
    }
    return gone.length;
  }

  // ===== 체크리스트 =====
  void upsertList(Checklist l) {
    final i = lists.indexWhere((x) => x.id == l.id);
    if (i >= 0) {
      lists[i] = l;
    } else {
      lists.add(l);
    }
    _save();
    _cloudSet('lists', l.id, l.toJson());
  }

  void deleteList(String id) {
    lists.removeWhere((l) => l.id == id);
    _save();
    _cloudDelete('lists', id);
  }

  void toggleListItem(String listId, String itemId) {
    final l = lists.firstWhere((x) => x.id == listId);
    final it = l.items.firstWhere((x) => x.id == itemId);
    it.done = !it.done;
    _save();
    _cloudSet('lists', l.id, l.toJson());
  }

  void addListItem(String listId, String text) {
    final l = lists.firstWhere((x) => x.id == listId);
    l.items.add(CheckItem(id: newId(), text: text));
    _save();
    _cloudSet('lists', l.id, l.toJson());
  }

  void setCategoryOn(String id, bool on) {
    final c = cats.firstWhere((c) => c.id == id)..on = on;
    _save();
    _cloudSet('cats', c.id, c.toJson(), order: cats.indexOf(c));
  }

  Category addCategory(String name) {
    final c = Category(id: 'c${newId()}', name: name, color: newCategoryColors[cats.length % newCategoryColors.length]);
    cats.add(c);
    _save();
    _cloudSet('cats', c.id, c.toJson(), order: cats.length - 1);
    return c;
  }
}
