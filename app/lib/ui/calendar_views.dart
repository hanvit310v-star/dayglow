// 월 보기 · 주/일 보기
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/calendar_logic.dart';
import '../core/models.dart';
import '../data/calendar_store.dart';
import 'palette.dart';

/// 달력에서 일어나는 동작을 화면 밖(HomePage)으로 전달
class CalendarActions {
  final void Function(String ds) select;
  final void Function(String ds, {int? hour}) addAt;
  final void Function(CalEvent e) openEvent;
  final void Function(Todo t) openTodo;
  final void Function(String id) toggleTodo;
  final void Function(String ds) showDay;
  const CalendarActions({
    required this.select,
    required this.addAt,
    required this.openEvent,
    required this.openTodo,
    required this.toggleTodo,
    required this.showDay,
  });
}

// ===== 작은 부품 =====
class TodoCircle extends StatelessWidget {
  final bool done;
  final double size;
  final Color accent;
  final Color ink;
  final VoidCallback onTap;
  const TodoCircle({super.key, required this.done, required this.onTap, required this.accent, required this.ink, this.size = 14});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? accent : null,
              border: Border.all(color: done ? accent : const Color(0x59FFFFFF)),
            ),
            child: done ? Icon(Icons.check, size: size * 0.7, color: ink) : null,
          ),
        ),
      );
}

Widget eventChip(CalendarStore store, CalEvent e, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: hexColor(store.catOf(e.cat).color), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: t70)),
          ),
        ]),
      ),
    );

Widget todoChip(({Todo t, bool over}) x, CalendarActions a, Color accent, Color ink) => GestureDetector(
      onTap: () => a.openTodo(x.t),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(children: [
          TodoCircle(done: x.t.done, size: 10, accent: accent, ink: ink, onTap: () => a.toggleTodo(x.t.id)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              x.t.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: x.over ? softRed : (x.t.done ? t30 : t70),
                decoration: x.t.done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ]),
      ),
    );

// ===== 월 보기 =====
class MonthView extends StatelessWidget {
  final CalendarStore store;
  final DateTime cursor;
  final String sel;
  final CalendarActions actions;
  final Color accent;
  final Color ink;
  final bool fillHeight; // 넓은 화면: 남은 높이를 채움 / 폰: 칸 높이 고정
  final bool compact;

  const MonthView({
    super.key,
    required this.store,
    required this.cursor,
    required this.sel,
    required this.actions,
    required this.accent,
    required this.ink,
    required this.fillHeight,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(cursor.year, cursor.month, 1);
    final start = addDays(first, -weekdayIndex(first));
    final daysInMonth = DateTime(cursor.year, cursor.month + 1, 0).day;
    final weeks = ((weekdayIndex(first) + daysInMonth) / 7).ceil();
    final today = todayStr();
    const maxShown = 2; // 정보 밀도: 칸마다 2개까지만

    Widget cell(DateTime d) {
      final ds = ymd(d);
      final tds = store.todosOn(ds);
      final late = ds == today ? tds.where((x) => x.over).toList() : <({Todo t, bool over})>[];
      final rest = tds.where((x) => !late.contains(x)).toList();
      final items = <Widget>[
        ...late.map((x) => todoChip(x, actions, accent, ink)),
        ...store.eventsOn(ds).map((e) => eventChip(store, e, () => actions.openEvent(e))),
        ...rest.map((x) => todoChip(x, actions, accent, ink)),
      ];
      final other = d.month != cursor.month;
      final isSel = ds == sel;
      return GestureDetector(
        onTap: () => actions.select(ds),
        onDoubleTap: () => actions.addAt(ds),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSel ? const Color(0x0FFFFFFF) : null,
            border: const Border(top: BorderSide(color: hairline)),
          ),
          padding: EdgeInsets.fromLTRB(compact ? 4 : 8, 8, compact ? 4 : 8, 4),
          child: ClipRect(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.only(bottom: 2),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: ds == today ? BoxDecoration(border: Border(bottom: BorderSide(color: accent))) : null,
                child: Text(
                  pad2(d.day),
                  style: TextStyle(
                    fontSize: 13,
                    color: ds == today || isSel ? t100 : (other ? t30.withAlpha(46) : t50),
                    fontWeight: ds == today ? FontWeight.w400 : FontWeight.w300,
                  ),
                ),
              ),
              if (compact)
                Wrap(spacing: 3, children: [
                  for (final e in store.eventsOn(ds).take(3))
                    Container(width: 5, height: 5, decoration: BoxDecoration(color: hexColor(store.catOf(e.cat).color), shape: BoxShape.circle)),
                  if (tds.isNotEmpty) Container(width: 5, height: 5, decoration: BoxDecoration(border: Border.all(color: t50), shape: BoxShape.circle)),
                ])
              else ...[
                ...items.take(maxShown),
                if (items.length > maxShown)
                  GestureDetector(
                    onTap: () => actions.showDay(ds),
                    child: Text('+${items.length - maxShown}', style: const TextStyle(fontSize: 11, color: t30)),
                  ),
              ],
            ]),
          ),
        ),
      );
    }

    Widget row(int w) => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < 7; i++) Expanded(child: cell(addDays(start, w * 7 + i))),
        ]);

    return Column(children: [
      Row(children: [
        for (final w in weekdayKo)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Text(w, style: const TextStyle(fontSize: 11, letterSpacing: 1.5, color: t30)),
            ),
          ),
      ]),
      if (fillHeight)
        Expanded(child: Column(children: [for (var w = 0; w < weeks; w++) Expanded(child: row(w))]))
      else
        for (var w = 0; w < weeks; w++) SizedBox(height: compact ? 56 : 84, child: row(w)),
    ]);
  }
}

// ===== 주 · 일 보기 (시간 칸) =====
class TimeGridView extends StatefulWidget {
  final CalendarStore store;
  final List<DateTime> days;
  final String sel;
  final CalendarActions actions;
  final Color accent;
  final Color ink;
  final double bodyHeight;

  const TimeGridView({
    super.key,
    required this.store,
    required this.days,
    required this.sel,
    required this.actions,
    required this.accent,
    required this.ink,
    required this.bodyHeight,
  });

  @override
  State<TimeGridView> createState() => _TimeGridViewState();
}

class _TimeGridViewState extends State<TimeGridView> {
  static const hh = 44.0; // 1시간 높이
  late final ScrollController _scroll;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final hasToday = widget.days.any((d) => ymd(d) == ymd(now));
    _scroll = ScrollController(initialScrollOffset: ((hasToday ? now.hour - 2 : 8).clamp(0, 23)) * hh);
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {})); // 현재 시각 선 이동
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store, a = widget.actions;
    final today = todayStr();
    final now = DateTime.now();
    const gutter = 44.0;

    return Column(children: [
      // 요일 머리 (누르면 그날 선택)
      Row(children: [
        const SizedBox(width: gutter),
        for (final d in widget.days)
          Expanded(
            child: GestureDetector(
              onTap: () => a.select(ymd(d)),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(weekdayKo[weekdayIndex(d)], style: const TextStyle(fontSize: 11, letterSpacing: 1.5, color: t30)),
                  const SizedBox(height: 4),
                  Text(
                    pad2(d.day),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w200,
                      color: ymd(d) == widget.sel ? widget.accent : (ymd(d) == today ? t100 : t70),
                    ),
                  ),
                ]),
              ),
            ),
          ),
      ]),
      // 종일 일정 · 할 일
      Container(
        decoration: const BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: hairline))),
        constraints: const BoxConstraints(minHeight: 30),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(width: gutter, child: Padding(padding: EdgeInsets.only(top: 9), child: Text('종일', style: TextStyle(fontSize: 10, color: t30)))),
          for (final d in widget.days)
            Expanded(
              child: GestureDetector(
                onTap: () => a.addAt(ymd(d)),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final e in s.eventsOn(ymd(d)).where((e) => e.allDay)) eventChip(s, e, () => a.openEvent(e)),
                    for (final x in s.todosOn(ymd(d))) todoChip(x, a, widget.accent, widget.ink),
                  ]),
                ),
              ),
            ),
        ]),
      ),
      // 시간 칸
      SizedBox(
        height: widget.bodyHeight,
        child: SingleChildScrollView(
          controller: _scroll,
          child: SizedBox(
            height: 24 * hh,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: gutter,
                child: Column(children: [
                  for (var i = 0; i < 24; i++)
                    SizedBox(
                      height: hh,
                      child: i == 0
                          ? null
                          : Transform.translate(
                              offset: const Offset(0, -6),
                              child: Text('${pad2(i)}:00', style: const TextStyle(fontSize: 10, color: t30)),
                            ),
                    ),
                ]),
              ),
              for (final d in widget.days)
                Expanded(
                  child: LayoutBuilder(builder: (ctx, c) {
                    final ds = ymd(d);
                    final width = c.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (det) => a.addAt(ds, hour: (det.localPosition.dy ~/ hh).clamp(0, 23)),
                      child: Stack(children: [
                        Column(children: [
                          for (var i = 0; i < 24; i++)
                            Container(height: hh, decoration: const BoxDecoration(border: Border(top: BorderSide(color: hairline)))),
                        ]),
                        for (final p in layoutDay(s.eventsOn(ds)))
                          Positioned(
                            top: p.startMin / 60 * hh,
                            height: ((p.endMin - p.startMin) / 60 * hh - 2).clamp(20, 24 * hh),
                            left: p.col * width / p.cols + 2,
                            width: width / p.cols - 4,
                            child: GestureDetector(
                              onTap: () => a.openEvent(p.e),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(7, 4, 6, 2),
                                decoration: BoxDecoration(
                                  color: hexColor(s.catOf(p.e.cat).color).withAlpha(38),
                                  border: Border(left: BorderSide(color: hexColor(s.catOf(p.e.cat).color), width: 2)),
                                ),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(p.e.start, style: const TextStyle(fontSize: 10, color: t50)),
                                  Flexible(
                                    child: Text(p.e.title, overflow: TextOverflow.fade, style: const TextStyle(fontSize: 11.5, color: t100)),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                        if (ds == today)
                          Positioned(
                            top: (now.hour * 60 + now.minute) / 60 * hh,
                            left: 0,
                            right: 0,
                            child: Container(height: 1, color: widget.accent),
                          ),
                      ]),
                    );
                  }),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }
}
