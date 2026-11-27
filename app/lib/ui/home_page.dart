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
import 'motion.dart';
import 'palette.dart';
import 'strings.dart';
import 'sync_dialog.dart';

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

  void toast(String m, {VoidCallback? undo}) => showToast(context, paletteOf(mood.theme), m, undo: undo);

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
        navDir = 0;
        view = v;
        if (v != 'month') cursor = parseYmd(sel);
      });

  // 움직임 방향: 다음(미래)이면 1, 이전(과거)이면 -1, 보기 전환이면 0
  int navDir = 1; // 달력 화면이 들어오는 방향
  int selDir = 1; // 큰 날짜 숫자가 굴러가는 방향

  void selectDay(String ds) {
    if (ds != sel) selDir = ds.compareTo(sel) > 0 ? 1 : -1;
    sel = ds;
  }

  void move(int dir) => setState(() {
        navDir = dir;
        if (view == 'month') {
          cursor = DateTime(cursor.year, cursor.month + dir, 1);
        } else {
          cursor = addDays(cursor, dir * (view == 'week' ? 7 : 1));
          if (view == 'day') selectDay(ymd(cursor));
        }
      });

  void goToday() => setState(() {
        final t = dateOnly(DateTime.now());
        navDir = t.isAfter(cursor) ? 1 : -1;
        cursor = t;
        selectDay(todayStr());
      });

  late final actions = CalendarActions(
    select: (ds) => setState(() => selectDay(ds)),
    addAt: (ds, {hour}) {
      setState(() => selectDay(ds));
      openEditor(date: ds, hour: hour, fromCell: true);
    },
    openEvent: (e) => openEditor(event: e),
    openTodo: (t) => openEditor(todo: t),
    // 일정 위 호버 칩: 복제 · 하루 뒤로 · 삭제 (삭제는 '되돌리기' 버튼이 있는 알림을 띄움)
    duplicateEvent: (e) {
      store.upsertEvent(e.copy()..id = newId()..repeat = 'none');
      toast('Event duplicated');
    },
    postponeEvent: (e) {
      final before = e.copy();
      store.upsertEvent(e.copy()..date = ymd(addDays(parseYmd(e.date), 1)));
      toast('Moved to tomorrow', undo: () => store.upsertEvent(before));
    },
    deleteEvent: (e) {
      final backup = e.copy();
      store.deleteEvent(e.id);
      toast('Event deleted', undo: () => store.upsertEvent(backup));
    },
    toggleTodo: store.toggleTodo,
    showDay: (ds) => setState(() {
      selectDay(ds);
      cursor = parseYmd(ds);
      navDir = 0;
      view = 'day';
    }),
  );

  String get title {
    final c = cursor;
    if (view == 'month') return '${monthLongEn[c.month - 1]} ${c.year}';
    if (view == 'week') {
      final s = addDays(c, -weekdayIndex(c)), e = addDays(s, 6);
      return '${enMonthDay(ymd(s))} – ${enMonthDay(ymd(e))}, ${e.year}';
    }
    return '${weekdayLongEn[weekdayIndex(c)]}, ${enFullDate(c)}';
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
        final atmosphere = RepaintBoundary(child: Atmosphere(
          theme: mood.theme,
          tod: mood.tod,
          temp: mood.temp,
          effectOpacity: mood.intensity / 100 * (busyNow ? 0.4 : 1),
          paused: focusEvent != null,
          windStrong: mood.windStrong,
        ));

        // RepaintBoundary: 배경의 비·눈 효과가 매 프레임 다시 그려져도
        // 달력·오른쪽 목록은 바뀔 때만 다시 그리도록 분리 (클릭·입력 반응 속도 개선)
        final left = RepaintBoundary(child: _LeftPane(state: this, pal: pal, wide: wide, compact: compact));
        final right = RepaintBoundary(child: _RightPanel(state: this, pal: pal, wide: wide));

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
      for (final v in const [('month', 'M'), ('week', 'W'), ('day', 'D')]) ...[
        TextTab(label: v.$2, on: s.view == v.$1, onTap: () => s.setView(v.$1)),
        const SizedBox(width: 18),
      ],
    ]);
    final nav = Row(mainAxisSize: MainAxisSize.min, children: [
      Pressable(pressedScale: .88, child: IconButton(onPressed: () => s.move(-1), icon: const Icon(Icons.chevron_left, size: 18), color: t50, tooltip: 'Previous')),
      Pressable(child: TextButton(style: textButton(), onPressed: s.goToday, child: const Text('Today'))),
      Pressable(pressedScale: .88, child: IconButton(onPressed: () => s.move(1), icon: const Icon(Icons.chevron_right, size: 18), color: t50, tooltip: 'Next')),
    ]);
    final offCats = s.store.cats.where((c) => !c.on).length;
    final tools = Row(mainAxisSize: MainAxisSize.min, children: [
      Pressable(
        child: TextButton(
          style: textButton(),
          onPressed: () => showSyncDialog(context, store: s.store, pal: pal),
          child: RollingText(syncLabel(s.store), style: const TextStyle(fontSize: 13)),
        ),
      ),
      Pressable(
        child: TextButton(
          style: textButton(),
          onPressed: () => showCategoryMenu(context, store: s.store, pal: pal),
          child: RollingText(offCats > 0 ? 'Category ${s.store.cats.length - offCats}/${s.store.cats.length}' : 'Category',
              style: const TextStyle(fontSize: 13)),
        ),
      ),
    ]);
    const brand = Text.rich(TextSpan(children: [
      TextSpan(text: 'Day'),
      TextSpan(text: 'glow', style: TextStyle(color: Color(0xFFA3BDB3))),
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

    // 달·주·날을 넘기면 그 방향에서 달력이 밀려 들어옴
    final switcher = SlideSwitcher(switchKey: '${s.view}|${s.title}', direction: s.navDir, fill: wide, child: calendar);

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, wide ? 40 : 20, pad, wide ? 44 : 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        top,
        Padding(
          padding: EdgeInsets.only(top: wide ? 30 : 22, bottom: 14),
          child: RollingText(s.title, direction: s.navDir < 0 ? -1 : 1, style: const TextStyle(fontSize: 12, letterSpacing: 1.6, color: t50)),
        ),
        if (wide) Expanded(child: switcher) else switcher,
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
        ? 'Today'
        : s.sel == ymd(addDays(DateTime.now(), 1))
            ? 'Tomorrow'
            : s.sel == ymd(addDays(DateTime.now(), -1))
                ? 'Yesterday'
                : '';
    final nowEv = s.sel == today ? s.focusEvent : null;
    final count = s.store.eventsOn(s.sel).length;
    final dir = s.selDir;
    // 숫자·글자가 바뀌면 위(다음 날)·아래(이전 날)로 굴러가듯 교체
    Widget stat(String v, String k) => Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          RollingText(v, direction: dir, alignment: Alignment.center,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w200, color: t100, height: 1)),
          const SizedBox(height: 6),
          RollingText(k, alignment: Alignment.center, style: const TextStyle(fontSize: 11, color: t50)),
        ]);
    return Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 22, runSpacing: 12, children: [
      RollingText(pad2(d.day),
          direction: dir,
          style: TextStyle(fontSize: compact ? 72 : 112, fontWeight: FontWeight.w200, height: .82, letterSpacing: -4, color: t100)),
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          RollingText(weekdayLongEn[weekdayIndex(d)],
              direction: dir, style: TextStyle(fontSize: compact ? 28 : 38, fontWeight: FontWeight.w300, height: 1.1, color: t100)),
          const SizedBox(height: 10),
          RollingText('${rel.isNotEmpty ? '$rel · ' : ''}${enFullDate(d)}',
              direction: dir, style: const TextStyle(fontSize: 12, color: t50)),
          // 진행 중인 일정: 나타날 때 부드럽게 펼쳐지고, 점이 숨 쉬듯 깜빡임
          AnimatedSize(
            duration: Motion.of(context, Motion.base),
            curve: Motion.ease,
            child: nowEv == null
                ? const SizedBox(height: 0)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _Breathing(color: pal.accent),
                      const SizedBox(width: 7),
                      Text('Now · ${nowEv.title} ~${nowEv.end}', style: TextStyle(fontSize: 12, color: pal.accent)),
                    ]),
                  ),
          ),
        ]),
      ),
      Padding(padding: const EdgeInsets.only(bottom: 6, left: 8), child: stat('$count', 'Events')),
      // 날씨 표시 = 분위기 패널을 여는 버튼
      Tooltip(
        message: 'Choose mood',
        child: Pressable(
          hoverGlow: true,
          child: GestureDetector(
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
      ),
    ]);
  }
}

/// 진행 중 일정 옆의 점: 천천히 숨 쉬듯 밝아졌다 흐려짐
class _Breathing extends StatefulWidget {
  final Color color;
  const _Breathing({required this.color});
  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: .35, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
        child: Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
      );
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
              decoration: underlineDecoration(pal.accent, hint: 'Search'),
            ),
          ),
        ),
        Pressable(
          pressedScale: .94,
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.slow),
            width: wide ? 76 : 60,
            height: wide ? 76 : 60,
            color: pal.accent,
            child: Icon(Icons.search, color: pal.accentInk, size: 20),
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
          RollingText(title, direction: state.selDir, style: const TextStyle(fontSize: 13, color: t100)),
          const Spacer(),
          ?trailing,
        ]),
      );

  // 목록 한 줄: 마우스를 올리면 은은하게 밝아지고, 누르면 살짝 눌림, 완료하면 글자가 부드럽게 흐려지며 줄이 그어짐
  Widget _item({required Widget lead, required String text, required String value, VoidCallback? onTap, bool done = false, bool over = false}) =>
      Builder(
        builder: (context) => Pressable(
          pressedScale: .985,
          hoverGlow: true,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(children: [
                lead,
                const SizedBox(width: 10),
                Expanded(child: todoText(context, text, done: done, over: over)),
                Text(value, style: const TextStyle(fontSize: 12, color: t70)),
              ]),
            ),
          ),
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
        _sectionHead('Results  ${hits.length}'),
        if (hits.isEmpty) const Text('No results', style: TextStyle(fontSize: 13, color: t30)),
        for (final (i, e) in hits.take(20).indexed)
          StaggerIn(key: ValueKey('r${e.id}'), index: i, child: _item(
            lead: Container(width: 5, height: 5, decoration: BoxDecoration(color: hexColor(s.store.catOf(e.cat).color), shape: BoxShape.circle)),
            text: e.title,
            value: '${enMonthDay(e.date)} ${e.allDay ? 'All day' : e.start}${e.repeat != 'none' ? ' · Repeats' : ''}',
            onTap: () {
              s.update(() {
                s.sel = e.date;
                s.cursor = parseYmd(e.date);
                s.query = '';
                s.searchCtl.clear();
              });
              s.openEditor(event: e);
            },
          )),
      ]),
    );
  }

  Widget _sections(BuildContext context) {
    final s = state;
    final st = s.store;
    final ds = s.sel;
    final today = todayStr();
    final evs = st.eventsOn(ds);
    final tds = st.todosOn(ds);
    final dayTodos = st.todos.where((t) => t.due == ds).toList();
    final undated = st.undatedTodos;
    final open = undated.where((t) => !t.done).toList();
    final done = undated.where((t) => t.done).toList();
    Widget divider() => const Divider(color: hairline, height: 1);
    // 요약 숫자: 바뀌면 굴러가듯 교체
    Widget kv(String k, String v, {bool warn = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            Text(k, style: const TextStyle(fontSize: 13, color: t50)),
            const Spacer(),
            RollingText(v, direction: s.selDir, alignment: Alignment.centerRight,
                style: TextStyle(fontSize: 13, color: warn ? softRed : t100)),
          ]),
        );
    var n = 0; // 목록이 차례로 나타나는 순서

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 선택한 날의 목록
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionHead(ds == today ? 'Today' : enDayLabel(ds)),
          if (evs.isEmpty && tds.isEmpty)
            StaggerIn(key: ValueKey('empty$ds'), index: 0, child: const Text('Nothing planned', style: TextStyle(fontSize: 13, color: t30))),
          // 날짜를 바꾸면 항목이 하나씩 차례로 떠오름 (key에 날짜를 넣어 매번 다시 재생)
          for (final e in evs)
            StaggerIn(
              key: ValueKey('$ds-e${e.id}'),
              index: n++,
              child: _item(
                lead: Container(width: 5, height: 5, decoration: BoxDecoration(color: hexColor(st.catOf(e.cat).color), shape: BoxShape.circle)),
                text: e.title,
                value: e.allDay ? 'All day' : e.start,
                onTap: () => s.openEditor(event: e),
              ),
            ),
          for (final x in tds)
            StaggerIn(
              key: ValueKey('$ds-t${x.t.id}'),
              index: n++,
              child: _item(
                lead: TodoCircle(done: x.t.done, accent: pal.accent, ink: pal.accentInk, onTap: () => st.toggleTodo(x.t.id)),
                text: x.t.text,
                value: x.over ? 'Due ${enMonthDay(x.t.due)}' : 'Task',
                done: x.t.done,
                over: x.over,
                onTap: () => s.openEditor(todo: x.t),
              ),
            ),
        ]),
      ),
      divider(),
      // 하루 요약: 항목명은 흐리게 왼쪽, 수치는 선명하게 오른쪽
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionHead('Summary'),
          kv('Events', '${evs.length}'),
          kv('Tasks done', '${dayTodos.where((t) => t.done).length} / ${dayTodos.length}'),
          kv('Free time  ${activeHours.start}–${activeHours.end}', hoursMinutes(st.freeMinutes(ds))),
          kv('Overdue', '${st.overdueCount}', warn: st.overdueCount > 0),
        ]),
      ),
      // 마감일 없는 할 일 (접이식)
      if (undated.isNotEmpty) ...[
        divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Pressable(
              pressedScale: .985,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => s.update(() => s.todoOpen = !s.todoOpen),
                child: Row(children: [
                  const Text('Someday', style: TextStyle(fontSize: 13, color: t100)),
                  const SizedBox(width: 8),
                  RollingText(open.isEmpty ? 'All done' : pad2(open.length), style: const TextStyle(fontSize: 13, color: t50)),
                  const Spacer(),
                  AnimatedRotation(
                    turns: s.todoOpen ? .5 : 0,
                    duration: Motion.of(context, Motion.base),
                    curve: Motion.ease,
                    child: const Icon(Icons.expand_more, size: 16, color: t30),
                  ),
                ]),
              ),
            ),
            // 접기·펴기: 높이가 부드럽게 늘었다 줄어듦
            AnimatedSize(
              duration: Motion.of(context, Motion.slow),
              curve: Motion.ease,
              alignment: Alignment.topCenter,
              child: !s.todoOpen
                  ? const SizedBox(width: double.infinity)
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
                    decoration: underlineDecoration(pal.accent, hint: 'Add a task'),
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
                    onPressed: () => s.toast('Cleared ${st.clearDoneUndated()} done'),
                    child: const Text('Clear done'),
                  ),
              ]),
            ]),
            ),
          ]),
        ),
      ],
    ]);
  }
}
