// 월 보기 · 주/일 보기
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/calendar_logic.dart';
import '../core/models.dart';
import '../data/calendar_store.dart';
import '../mood/forecast.dart';
import 'motion.dart';
import 'palette.dart';
import 'strings.dart';
import 'weather_ui.dart';

/// 달력에서 일어나는 동작을 화면 밖(HomePage)으로 전달
class CalendarActions {
  final void Function(String ds) select;
  final void Function(String ds, {int? hour}) addAt;
  final void Function(CalEvent e) openEvent;
  final void Function(Todo t) openTodo;
  final void Function(String id) toggleTodo;
  final void Function(String ds) showDay;
  final void Function(CalEvent e) duplicateEvent;
  final void Function(CalEvent e) postponeEvent; // 하루 뒤로 미루기
  final void Function(CalEvent e) deleteEvent;
  final void Function(CalEvent e, String ds) rainHelp; // 우산 표시를 누르면: 더 좋은 시간 안내
  final Forecast forecast; // 날씨 예보 (일정 칩 질감·하늘 띠·날씨 보기에 사용)
  const CalendarActions({
    required this.select,
    required this.addAt,
    required this.openEvent,
    required this.openTodo,
    required this.toggleTodo,
    required this.showDay,
    required this.duplicateEvent,
    required this.postponeEvent,
    required this.deleteEvent,
    required this.rainHelp,
    required this.forecast,
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

  // 체크하면 동그라미가 톡 튀며 채워지고, 체크 표시가 커지며 나타남
  @override
  Widget build(BuildContext context) => Pressable(
        pressedScale: .85,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: PopOnChange(
              value: done,
              child: AnimatedContainer(
                duration: Motion.of(context, Motion.base),
                curve: Motion.ease,
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? accent : accent.withAlpha(0),
                  border: Border.all(color: done ? accent : const Color(0x59FFFFFF)),
                ),
                child: AnimatedScale(
                  scale: done ? 1 : 0,
                  duration: Motion.of(context, Motion.base),
                  curve: Curves.easeOutBack,
                  child: Icon(Icons.check, size: size * 0.7, color: ink),
                ),
              ),
            ),
          ),
        ),
      );
}

/// 할 일 글자: 완료하면 흐려지며 줄이 그어짐 (색·줄 바뀜이 부드럽게)
Widget todoText(BuildContext context, String text, {required bool done, required bool over, double size = 13, Color normal = t50}) =>
    AnimatedDefaultTextStyle(
      duration: Motion.of(context, Motion.base),
      curve: Motion.ease,
      style: TextStyle(
        fontFamily: 'DayglowSans',
        fontWeight: FontWeight.w300,
        fontSize: size,
        color: over ? softRed : (done ? t30 : normal),
        decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
        decorationColor: done ? t30 : const Color(0x00FFFFFF),
      ),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    );

/// 일정 위에 마우스를 올리면 나타나는 반투명 알약 버튼 목록 (현재는 비어 있어서 칩이 안 보여요)
/// 다시 쓰고 싶으면 아래 목록에 HoverChipSpec 을 넣으면 돼요. 예:
///   HoverChipSpec(Icons.content_copy, 'Duplicate', () => a.duplicateEvent(e)),
///   if (e.repeat == 'none') HoverChipSpec(Icons.east, 'Move to tomorrow', () => a.postponeEvent(e)),
///   HoverChipSpec(Icons.delete_outline, 'Delete', () => a.deleteEvent(e), danger: true),
List<HoverChipSpec> eventHoverChips(CalEvent e, CalendarActions a) => [];

Widget eventChip(CalendarStore store, CalEvent e, CalendarActions a, String ds) {
  final risk = rainRisk(e, ds, a.forecast);
  return HoverChips(
      chips: eventHoverChips(e, a),
      barColor: hexColor(store.catOf(e.cat).color),
      child: Pressable(
        child: GestureDetector(
          onTap: () => a.openEvent(e),
          behavior: HitTestBehavior.opaque,
          // 날씨 질감이 글자 뒤에 깔림
          child: Stack(children: [
            weatherTexture(a.forecast, e, ds, radius: 5),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
              child: Row(children: [
                Container(width: 5, height: 5, decoration: BoxDecoration(color: hexColor(store.catOf(e.cat).color), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: t70)),
                ),
                if (risk != null) umbrellaBadge(() => a.rainHelp(e, ds), size: 11),
              ]),
            ),
          ]),
        ),
      ),
    );
}

Widget todoChip(({Todo t, bool over}) x, CalendarActions a, Color accent, Color ink) => Builder(
      builder: (context) => Pressable(
        child: GestureDetector(
          onTap: () => a.openTodo(x.t),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(children: [
              TodoCircle(done: x.t.done, size: 10, accent: accent, ink: ink, onTap: () => a.toggleTodo(x.t.id)),
              const SizedBox(width: 4),
              Expanded(child: todoText(context, x.t.text, done: x.t.done, over: x.over, size: 11.5, normal: t70)),
            ]),
          ),
        ),
      ),
    );

/// 호버 칩 하나의 정보: 아이콘 · 설명(마우스를 올리면 뜸) · 누르면 할 일
class HoverChipSpec {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const HoverChipSpec(this.icon, this.label, this.onTap, {this.danger = false});
}

/// 마우스를 올리면 오른쪽에 반투명 알약 버튼들이 부드럽게 나타남 (터치 화면에서는 나타나지 않음)
class HoverChips extends StatefulWidget {
  final Widget child;
  final List<HoverChipSpec> chips;
  final Alignment alignment; // centerRight: 한 줄 일정 · topRight: 큰 블록
  final Color? barColor; // 호버하면 일정 전체가 이 색의 반투명 바로 바뀜 (null이면 바 없음)
  const HoverChips({super.key, required this.child, required this.chips, this.alignment = Alignment.centerRight, this.barColor});
  @override
  State<HoverChips> createState() => _HoverChipsState();
}

class _HoverChipsState extends State<HoverChips> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Stack(clipBehavior: Clip.none, children: [
        // 사진처럼 둥근 모서리의 넓은 칩: 반투명 색 바 + 왼쪽 굵은 줄
        if (widget.barColor != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: Motion.of(context, Motion.base),
                curve: Motion.ease,
                decoration: BoxDecoration(
                  color: widget.barColor!.withAlpha(_hover ? 96 : 0),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.base),
                    width: 3,
                    height: _hover ? double.infinity : 0,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(color: widget.barColor, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ),
            ),
          ),
        widget.child,
        if (widget.chips.isNotEmpty)
        Positioned.fill(
          child: Align(
            alignment: widget.alignment,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: IgnorePointer(
                ignoring: !_hover,
                child: AnimatedOpacity(
                  opacity: _hover ? 1 : 0,
                  duration: Motion.of(context, Motion.fast),
                  curve: Motion.ease,
                  child: AnimatedSlide(
                    offset: _hover ? Offset.zero : const Offset(.15, 0),
                    duration: Motion.of(context, Motion.base),
                    curve: Motion.ease,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final c in widget.chips) _HoverChip(c),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _HoverChip extends StatefulWidget {
  final HoverChipSpec spec;
  const _HoverChip(this.spec);
  @override
  State<_HoverChip> createState() => _HoverChipState();
}

class _HoverChipState extends State<_HoverChip> {
  bool _on = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.spec;
    final fg = c.danger ? softRed : t100;
    return Padding(
      padding: const EdgeInsets.only(left: 3),
      child: Tooltip(
        message: c.label,
        waitDuration: const Duration(milliseconds: 400),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _on = true),
          onExit: (_) => setState(() => _on = false),
          child: GestureDetector(
            onTap: c.onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.fast),
              width: 24,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _on ? const Color(0x4DFFFFFF) : const Color(0x26FFFFFF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(c.icon, size: 12, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

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
  final bool skyMap; // 날짜 칸을 예상 날씨 색으로 칠하기

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
    this.skyMap = false,
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
        ...store.eventsOn(ds).map((e) => eventChip(store, e, actions, ds)),
        ...rest.map((x) => todoChip(x, actions, accent, ink)),
      ];
      final other = d.month != cursor.month;
      final isSel = ds == sel;
      final dayWx = skyMap ? actions.forecast.day(ds) : null; // 날씨 보기: 그날의 예상 날씨
      final tint = dayWx == null ? null : wxTint(dayWx.theme);
      // 날짜 칸: 마우스를 올리면 은은하게 밝아지고, 누르면 살짝 눌림, 선택 배경은 부드럽게 바뀜
      return Pressable(
        pressedScale: .98,
        hoverGlow: true,
        child: GestureDetector(
        // 한 번 클릭 = 그 날짜로 새 일정 만들기 (더블클릭 대기 없이 바로 반응)
        onTap: () => actions.addAt(ds),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.base),
          curve: Motion.ease,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              isSel ? const Color(0x14FFFFFF) : const Color(0x00FFFFFF),
              tint == null ? const Color(0x00FFFFFF) : tint.withAlpha(other ? 26 : 58),
            ),
            border: const Border(top: BorderSide(color: hairline)),
          ),
          padding: EdgeInsets.fromLTRB(compact ? 4 : 8, 8, compact ? 4 : 8, 4),
          child: ClipRect(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
              Container(
                padding: const EdgeInsets.only(bottom: 2),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: ds == today ? BoxDecoration(border: Border(bottom: BorderSide(color: accent))) : null,
                child: AnimatedDefaultTextStyle(
                  duration: Motion.of(context, Motion.base),
                  style: TextStyle(
                    fontFamily: 'DayglowSans',
                    fontSize: 13,
                    color: ds == today || isSel ? t100 : (other ? t30.withAlpha(46) : t50),
                    fontWeight: ds == today ? FontWeight.w400 : FontWeight.w300,
                  ),
                  child: Text(pad2(d.day)),
                ),
              ),
              if (dayWx != null) ...[
                const Spacer(),
                // 날씨 보기: 아이콘 + 최고 기온 (비 올 확률이 높으면 우산)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: compact
                      ? Icon(wxIcon(dayWx.theme), size: 11, color: t70)
                      : Tooltip(
                          message: '${weatherLabelEn(dayWx.theme)} · ${dayWx.tMax}° / ${dayWx.tMin}° · rain ${dayWx.rain}%',
                          child: dayWxMini(dayWx),
                        ),
                ),
              ],
              ]),
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
      ));
    }

    Widget row(int w) => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < 7; i++) Expanded(child: cell(addDays(start, w * 7 + i))),
        ]);

    return Column(children: [
      Row(children: [
        for (final w in weekdayShortEn)
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
            child: Pressable(
              pressedScale: .95,
              child: GestureDetector(
                onTap: () => a.select(ymd(d)),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(weekdayShortEn[weekdayIndex(d)], style: const TextStyle(fontSize: 11, letterSpacing: 1.5, color: t30)),
                      if (a.forecast.day(ymd(d)) != null) ...[
                        const Spacer(),
                        dayWxMini(a.forecast.day(ymd(d))!, full: widget.days.length == 1),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    // 선택한 날의 숫자 색이 부드럽게 바뀜
                    AnimatedDefaultTextStyle(
                      duration: Motion.of(context, Motion.base),
                      style: TextStyle(
                        fontFamily: 'DayglowSans',
                        fontSize: 26,
                        fontWeight: FontWeight.w200,
                        color: ymd(d) == widget.sel ? widget.accent : (ymd(d) == today ? t100 : t70),
                      ),
                      child: Text(pad2(d.day)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]),
      // 종일 일정 · 할 일
      Container(
        decoration: const BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: hairline))),
        constraints: const BoxConstraints(minHeight: 30),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(width: gutter, child: Padding(padding: EdgeInsets.only(top: 9), child: Text('ALL DAY', style: TextStyle(fontSize: 9, letterSpacing: .5, color: t30)))),
          for (final d in widget.days)
            Expanded(
              child: GestureDetector(
                onTap: () => a.addAt(ymd(d)),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final e in s.eventsOn(ymd(d)).where((e) => e.allDay)) eventChip(s, e, a, ymd(d)),
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
                        // 하늘 띠: 새벽 → 낮(날씨 색) → 노을 → 밤
                        Positioned(left: 1, top: 0, bottom: 0, child: SkyStrip(day: a.forecast.day(ds), forecast: a.forecast, ds: ds)),
                        for (final p in layoutDay(s.eventsOn(ds)))
                          Positioned(
                            top: p.startMin / 60 * hh,
                            height: ((p.endMin - p.startMin) / 60 * hh - 2).clamp(20, 24 * hh),
                            left: p.col * width / p.cols + 6,
                            width: width / p.cols - 8,
                            // 일정 블록: 처음 보일 때 위에서부터 차례로 떠오름 + 누르면 살짝 눌림
                            child: StaggerIn(
                              index: p.startMin ~/ 60,
                              distance: 6,
                              child: HoverChips(
                                chips: eventHoverChips(p.e, a),
                                alignment: Alignment.topRight,
                                barColor: hexColor(s.catOf(p.e.cat).color),
                                child: Pressable(
                                  pressedScale: .97,
                                  hoverGlow: true,
                                  child: GestureDetector(
                                    onTap: () => a.openEvent(p.e),
                                    child: Container(
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        color: hexColor(s.catOf(p.e.cat).color).withAlpha(38),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: Stack(children: [
                                        weatherTexture(a.forecast, p.e, ds), // 시작 시각의 날씨 질감
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(9, 4, 6, 2),
                                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(p.e.start, style: const TextStyle(fontSize: 10, color: t50)),
                                            Flexible(
                                              child: Text(p.e.title, overflow: TextOverflow.fade, style: const TextStyle(fontSize: 11.5, color: t100)),
                                            ),
                                          ]),
                                        ),
                                        if (rainRisk(p.e, ds, a.forecast) != null)
                                          Positioned(top: 2, right: 3, child: umbrellaBadge(() => a.rainHelp(p.e, ds))),
                                      ]),
                                    ),
                                  ),
                                ),
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
