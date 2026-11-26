// 메인 화면: 왼쪽(달력 + 큰 날짜) · 오른쪽 유리 패널(검색·오늘 일정·하루 요약·마감일 없는 할 일)
// 넓은 화면은 6:4 배치, 좁은 화면(폰)은 위아래로 쌓음
import 'dart:async';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../core/calendar_logic.dart';
import '../core/models.dart';
import '../data/calendar_store.dart';
import '../mood/mood_controller.dart';
import 'atmosphere.dart';
import 'calendar_views.dart';
import 'editors.dart';
import 'palette.dart';

class HomePage extends StatefulWidget {
  final CalendarStore store;
  final MoodController mood;
  const HomePage({super.key, required this.store, required this.mood});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  String view = 'month';
  DateTime cursor = dateOnly(DateTime.now());
  String sel = todayStr();
  String query = '';
  bool todoOpen = false;
  final searchCtl = TextEditingController();
  final todoCtl = TextEditingController();
  Timer? _minute;

  CalendarStore get store => widget.store;
  MoodController get mood => widget.mood;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    mood.refresh();
    // 시간대·일정 진행 중·자정 넘어감을 1분마다 다시 확인
    _minute = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
    Timer.periodic(const Duration(minutes: weatherRefreshMinutes), (_) => mood.refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱으로 돌아오면 날씨·상황을 바로 다시 확인
    if (state == AppLifecycleState.resumed) {
      mood.refresh();
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minute?.cancel();
    searchCtl.dispose();
    todoCtl.dispose();
    super.dispose();
  }

  // ===== 상황 판단 =====
  bool get busy {
    final ds = todayStr();
    return store.eventsOn(ds).where((e) => !e.allDay).length >= busyEvents || store.freeMinutes(ds) < busyFreeMinutes;
  }

  CalEvent? get focusEvent => mood.focus ? store.nowEvent() : null;

  String moodExtra() {
    final parts = <String>[];
    if (mood.busyCalm && busy) parts.add(' · 바쁜 날이라 효과를 줄였어요');
    if (focusEvent != null) parts.add(' · 일정 진행 중이라 효과를 멈췄어요');
    return parts.join();
  }

  // ===== 동작 =====
  /// 화면 조각(패널 등)에서 화면을 다시 그릴 때 쓰는 통로
  void update(VoidCallback fn) => setState(fn);

  void toast(String m) => showToast(context, paletteOf(mood.theme), m);

  Future<void> openEditor({CalEvent? event, Todo? todo, String? date, int? hour, bool fromCell = false}) async {
    final msg = await showEditor(context,
        store: store, pal: paletteOf(mood.theme), event: event, todo: todo, date: date, hour: hour, fromCell: fromCell);
    if (msg != null && mounted) {
      if (event == null && todo == null && date != null) sel = date;
      toast(msg);
    }
  }

  void openMood() => showMoodPanel(context, mood: mood, extraStatus: moodExtra, wide: MediaQuery.sizeOf(context).width >= 1080);

  void setView(String v) => setState(() {
        view = v;
        if (v != 'month') cursor = parseYmd(sel);
      });

  void move(int dir) => setState(() {
        if (view == 'month') {
          cursor = DateTime(cursor.year, cursor.month + dir, 1);
        } else {
          cursor = addDays(cursor, dir * (view == 'week' ? 7 : 1));
          if (view == 'day') sel = ymd(cursor);
        }
      });

  void goToday() => setState(() {
        cursor = dateOnly(DateTime.now());
        sel = todayStr();
      });

  late final actions = CalendarActions(
    select: (ds) => setState(() => sel = ds),
    addAt: (ds, {hour}) {
      setState(() => sel = ds);
      openEditor(date: ds, hour: hour, fromCell: true);
    },
    openEvent: (e) => openEditor(event: e),
    openTodo: (t) => openEditor(todo: t),
    toggleTodo: store.toggleTodo,
    showDay: (ds) => setState(() {
      sel = ds;
      cursor = parseYmd(ds);
      view = 'day';
    }),
  );

  String get title {
    final c = cursor;
    if (view == 'month') return '${c.year} · ${c.month}월';
    if (view == 'week') {
      final s = addDays(c, -weekdayIndex(c)), e = addDays(s, 6);
      return '${s.year} · ${monthDay(ymd(s))} – ${monthDay(ymd(e))}';
    }
    return '${c.year} · ${c.month}월 ${c.day}일 ${weekdayKo[weekdayIndex(c)]}요일';
  }

  // ===== 화면 =====
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, mood]),
      builder: (context, _) {
        final pal = paletteOf(mood.theme);
        final width = MediaQuery.sizeOf(context).width;
        final wide = width >= 1080;
        final compact = width < 640;
        final busyNow = mood.busyCalm && busy;
        final atmosphere = Atmosphere(
          theme: mood.theme,
          tod: mood.tod,
          temp: mood.temp,
          effectOpacity: mood.intensity / 100 * (busyNow ? 0.4 : 1),
          paused: focusEvent != null,
          windStrong: mood.windStrong,
        );

        final left = _LeftPane(state: this, pal: pal, wide: wide, compact: compact);
        final right = _RightPanel(state: this, pal: pal, wide: wide);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 1200),
          color: pal.bg,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: wide
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1320, minHeight: 720),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(children: [
                            Positioned.fill(child: atmosphere),
                            Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Expanded(flex: 62, child: left),
                              Expanded(flex: 38, child: right),
                            ]),
                          ]),
                        ),
                      ),
                    ),
                  )
                : Stack(children: [
                    Positioned.fill(child: atmosphere),
                    SafeArea(
                      bottom: false,
                      child: SingleChildScrollView(child: Column(children: [left, right])),
                    ),
                  ]),
          ),
        );
      },
    );
  }
}

// ===== 왼쪽: 상단 바 · 달력 · 큰 날짜 =====
class _LeftPane extends StatelessWidget {
  final _HomePageState state;
  final WxPalette pal;
  final bool wide;
  final bool compact;
  const _LeftPane({required this.state, required this.pal, required this.wide, required this.compact});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final pad = compact ? 18.0 : (wide ? 48.0 : 32.0);

    final viewTabs = Row(mainAxisSize: MainAxisSize.min, children: [
      for (final v in const [('month', '월'), ('week', '주'), ('day', '일')]) ...[
        TextTab(label: v.$2, on: s.view == v.$1, onTap: () => s.setView(v.$1)),
        const SizedBox(width: 18),
      ],
    ]);
    final nav = Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(onPressed: () => s.move(-1), icon: const Icon(Icons.chevron_left, size: 18), color: t50, tooltip: '이전'),
      TextButton(style: textButton(), onPressed: s.goToday, child: const Text('오늘')),
      IconButton(onPressed: () => s.move(1), icon: const Icon(Icons.chevron_right, size: 18), color: t50, tooltip: '다음'),
    ]);
    final offCats = s.store.cats.where((c) => !c.on).length;
    final tools = Row(mainAxisSize: MainAxisSize.min, children: [
      TextButton(
        style: textButton(),
        onPressed: () => showCategoryMenu(context, store: s.store, pal: pal),
        child: Text(offCats > 0 ? '카테고리 ${s.store.cats.length - offCats}/${s.store.cats.length}' : '카테고리'),
      ),
      IconButton(
        onPressed: () => showSettings(context, mood: s.mood, pal: pal, openMood: s.openMood),
        icon: const Icon(Icons.tune, size: 18),
        color: t50,
        tooltip: '설정',
      ),
      const SizedBox(width: 10),
      TextButton(style: accentButton(pal), onPressed: () => s.openEditor(date: s.sel), child: const Text('+ 추가')),
    ]);
    const brand = Text.rich(TextSpan(children: [
      TextSpan(text: 'my'),
      TextSpan(text: '.', style: TextStyle(color: Color(0xFFA3BDB3))),
      TextSpan(text: 'calendar'),
    ]), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: t100, letterSpacing: .3));

    final top = wide
        ? Row(children: [brand, const SizedBox(width: 22), viewTabs, const Spacer(), nav, const SizedBox(width: 14), tools])
        : Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 14, runSpacing: 8, children: [
            SizedBox(width: double.infinity, child: brand),
            viewTabs,
            nav,
            tools,
          ]);

    Widget calendar;
    if (s.view == 'month') {
      calendar = MonthView(
        store: s.store,
        cursor: s.cursor,
        sel: s.sel,
        actions: s.actions,
        accent: pal.accent,
        ink: pal.accentInk,
        fillHeight: wide,
        compact: compact,
      );
    } else {
      final days = s.view == 'week'
          ? List.generate(7, (i) => addDays(addDays(s.cursor, -weekdayIndex(s.cursor)), i))
          : [s.cursor];
      calendar = TimeGridView(
        key: ValueKey('${s.view}${ymd(s.cursor)}'),
        store: s.store,
        days: days,
        sel: s.sel,
        actions: s.actions,
        accent: pal.accent,
        ink: pal.accentInk,
        bodyHeight: wide ? 400 : 420,
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, wide ? 40 : 20, pad, wide ? 44 : 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        top,
        Padding(
          padding: EdgeInsets.only(top: wide ? 30 : 22, bottom: 14),
          child: Text(s.title, style: const TextStyle(fontSize: 12, letterSpacing: 1.6, color: t50)),
        ),
        if (wide) Expanded(child: calendar) else calendar,
        SizedBox(height: wide ? 30 : 24),
        _Hero(state: s, pal: pal, compact: compact),
      ]),
    );
  }
}

/// 왼쪽 아래 구석: 선택한 날을 크게 (주인공 하나만 크게, 나머지는 작게)
class _Hero extends StatelessWidget {
  final _HomePageState state;
  final WxPalette pal;
  final bool compact;
  const _Hero({required this.state, required this.pal, required this.compact});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final d = parseYmd(s.sel);
    final today = todayStr();
    final rel = s.sel == today
        ? '오늘'
        : s.sel == ymd(addDays(DateTime.now(), 1))
            ? '내일'
            : s.sel == ymd(addDays(DateTime.now(), -1))
                ? '어제'
                : '';
    final nowEv = s.sel == today ? s.focusEvent : null;
    final count = s.store.eventsOn(s.sel).length;
    Widget stat(String v, String k) => Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(v, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w200, color: t100, height: 1)),
          const SizedBox(height: 6),
          Text(k, style: const TextStyle(fontSize: 11, color: t50)),
        ]);
    return Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 22, runSpacing: 12, children: [
      Text(pad2(d.day),
          style: TextStyle(fontSize: compact ? 72 : 112, fontWeight: FontWeight.w200, height: .82, letterSpacing: -4, color: t100)),
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('${weekdayKo[weekdayIndex(d)]}요일',
              style: TextStyle(fontSize: compact ? 28 : 38, fontWeight: FontWeight.w300, height: 1, color: t100)),
          const SizedBox(height: 10),
          Text('${rel.isNotEmpty ? '$rel · ' : ''}${d.year}. ${d.month}. ${d.day}', style: const TextStyle(fontSize: 12, color: t50)),
          if (nowEv != null) ...[
            const SizedBox(height: 8),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: pal.accent, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text('지금 · ${nowEv.title} ~${nowEv.end}', style: TextStyle(fontSize: 12, color: pal.accent)),
            ]),
          ],
        ]),
      ),
      Padding(padding: const EdgeInsets.only(bottom: 6, left: 8), child: stat('$count', '일정')),
      // 날씨 표시 = 분위기 패널을 여는 버튼
      Tooltip(
        message: '분위기 직접 고르기',
        child: InkWell(
          onTap: s.openMood,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: underline))),
            child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              stat(s.mood.wx != null ? '${s.mood.wx!.temp}°' : '·', s.mood.label),
              const Padding(padding: EdgeInsets.only(left: 2, bottom: 1), child: Icon(Icons.expand_less, size: 13, color: t30)),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ===== 오른쪽: 유리 패널 =====
class _RightPanel extends StatelessWidget {
  final _HomePageState state;
  final WxPalette pal;
  final bool wide;
  const _RightPanel({required this.state, required this.pal, required this.wide});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final side = wide ? 44.0 : 24.0;
    final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 밑줄 검색창 + 직각 검색 버튼
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(side, wide ? 22 : 14, 30, 0),
            child: TextField(
              controller: s.searchCtl,
              onChanged: (v) => s.update(() => s.query = v.trim()),
              style: const TextStyle(fontSize: 13, color: t100),
              decoration: underlineDecoration(pal.accent, hint: '일정 검색'),
            ),
          ),
        ),
        SizedBox(
          width: wide ? 76 : 60,
          height: wide ? 76 : 60,
          child: Material(
            color: pal.accent,
            child: InkWell(onTap: () {}, child: Icon(Icons.search, color: pal.accentInk, size: 20)),
          ),
        ),
      ]),
      Padding(
        padding: EdgeInsets.fromLTRB(side, 0, side, 40),
        child: s.query.isNotEmpty ? _results(context) : _sections(context),
      ),
    ]);

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          decoration: BoxDecoration(color: pal.glass, border: const Border(left: BorderSide(color: hairline))),
          child: wide ? SingleChildScrollView(child: content) : content,
        ),
      ),
    );
  }

  Widget _sectionHead(String title, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Text(title, style: const TextStyle(fontSize: 13, color: t100)),
          const Spacer(),
          ?trailing,
        ]),
      );

  Widget _item({required Widget lead, required String text, required String value, VoidCallback? onTap, bool done = false, bool over = false}) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            lead,
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: over ? softRed : (done ? t30 : t50),
                    decoration: done ? TextDecoration.lineThrough : null,
                  )),
            ),
            Text(value, style: const TextStyle(fontSize: 12, color: t70)),
          ]),
        ),
      );

  Widget _results(BuildContext context) {
    final s = state;
    final q = s.query.toLowerCase();
    final hits = s.store.events.where((e) => '${e.title} ${e.memo}'.toLowerCase().contains(q)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionHead('검색 결과 ${hits.length}개'),
        if (hits.isEmpty) const Text('검색 결과가 없어요.', style: TextStyle(fontSize: 13, color: t30)),
        for (final e in hits.take(20))
          _item(
            lead: Container(width: 5, height: 5, decoration: BoxDecoration(color: hexColor(s.store.catOf(e.cat).color), shape: BoxShape.circle)),
            text: e.title,
            value: '${monthDay(e.date)} ${e.allDay ? '종일' : e.start}${e.repeat != 'none' ? ' · 반복' : ''}',
            onTap: () {
              s.update(() {
                s.sel = e.date;
                s.cursor = parseYmd(e.date);
                s.query = '';
                s.searchCtl.clear();
              });
              s.openEditor(event: e);
            },
          ),
      ]),
    );
  }

  Widget _sections(BuildContext context) {
    final s = state;
    final st = s.store;
    final ds = s.sel;
    final d = parseYmd(ds);
    final today = todayStr();
    final evs = st.eventsOn(ds);
    final tds = st.todosOn(ds);
    final dayTodos = st.todos.where((t) => t.due == ds).toList();
    final undated = st.undatedTodos;
    final open = undated.where((t) => !t.done).toList();
    final done = undated.where((t) => t.done).toList();
    Widget divider() => const Divider(color: hairline, height: 1);
    Widget kv(String k, String v, {bool warn = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            Text(k, style: const TextStyle(fontSize: 13, color: t50)),
            const Spacer(),
            Text(v, style: TextStyle(fontSize: 13, color: warn ? softRed : t100)),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 선택한 날의 목록
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionHead(
            ds == today ? '오늘의 일정' : '${monthDay(ds)} ${weekdayKo[weekdayIndex(d)]}요일',
            trailing: TextButton(style: textButton(color: pal.accent), onPressed: () => s.openEditor(date: ds, fromCell: true), child: const Text('+ 추가')),
          ),
          if (evs.isEmpty && tds.isEmpty) const Text('비어 있는 하루예요.', style: TextStyle(fontSize: 13, color: t30)),
          for (final e in evs)
            _item(
              lead: Container(width: 5, height: 5, decoration: BoxDecoration(color: hexColor(st.catOf(e.cat).color), shape: BoxShape.circle)),
              text: e.title,
              value: e.allDay ? '종일' : e.start,
              onTap: () => s.openEditor(event: e),
            ),
          for (final x in tds)
            _item(
              lead: TodoCircle(done: x.t.done, accent: pal.accent, ink: pal.accentInk, onTap: () => st.toggleTodo(x.t.id)),
              text: x.t.text,
              value: x.over ? '${monthDay(x.t.due)} 마감' : '할 일',
              done: x.t.done,
              over: x.over,
              onTap: () => s.openEditor(todo: x.t),
            ),
        ]),
      ),
      divider(),
      // 하루 요약: 항목명은 흐리게 왼쪽, 수치는 선명하게 오른쪽
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionHead('하루 요약'),
          kv('일정', '${evs.length}'),
          kv('할 일 (완료/전체)', '${dayTodos.where((t) => t.done).length} / ${dayTodos.length}'),
          kv('비어 있는 시간 (${activeHours.start}–${activeHours.end}시)', hoursMinutes(st.freeMinutes(ds))),
          kv('밀린 할 일', '${st.overdueCount}', warn: st.overdueCount > 0),
        ]),
      ),
      // 마감일 없는 할 일 (접이식)
      if (undated.isNotEmpty) ...[
        divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InkWell(
              onTap: () => s.update(() => s.todoOpen = !s.todoOpen),
              child: Row(children: [
                const Text('마감일 없는 할 일', style: TextStyle(fontSize: 13, color: t100)),
                const SizedBox(width: 8),
                Text(open.isEmpty ? '모두 완료' : pad2(open.length), style: const TextStyle(fontSize: 13, color: t50)),
                const Spacer(),
                AnimatedRotation(
                  turns: s.todoOpen ? .5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more, size: 16, color: t30),
                ),
              ]),
            ),
            if (s.todoOpen) ...[
              const SizedBox(height: 10),
              for (final t in [...open, ...done])
                _item(
                  lead: TodoCircle(done: t.done, accent: pal.accent, ink: pal.accentInk, onTap: () => st.toggleTodo(t.id)),
                  text: t.text,
                  value: '',
                  done: t.done,
                  onTap: () => s.openEditor(todo: t),
                ),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: s.todoCtl,
                    style: const TextStyle(fontSize: 13, color: t100),
                    decoration: underlineDecoration(pal.accent, hint: '할 일 추가 후 Enter'),
                    onSubmitted: (v) {
                      if (v.trim().isEmpty) return;
                      st.addTodo(v.trim());
                      s.todoCtl.clear();
                    },
                  ),
                ),
                if (done.isNotEmpty)
                  TextButton(
                    style: textButton(),
                    onPressed: () => s.toast('완료한 할 일 ${st.clearDoneUndated()}개를 지웠어요.'),
                    child: const Text('완료 지우기'),
                  ),
              ]),
            ],
          ]),
        ),
      ],
    ]);
  }
}
