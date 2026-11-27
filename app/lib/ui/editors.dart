// 입력 창(일정·할 일) · 분위기 패널 · 카테고리 메뉴 · 설정
import 'package:material_ui/material_ui.dart';

import '../core/calendar_logic.dart';
import '../core/models.dart';
import '../data/calendar_store.dart';
import '../mood/mood_controller.dart';
import 'motion.dart';
import 'palette.dart';
import 'strings.dart';

const repeatOptions = {'none': 'Never', 'daily': 'Daily', 'weekly': 'Weekly', 'monthly': 'Monthly'};
const remindOptions = <int?, String>{null: 'None', 10: '10 min before', 60: '1 hour before', 1440: '1 day before'};

// ===== 공통 부품 =====
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(text, style: const TextStyle(fontSize: 11, letterSpacing: 1, color: t30)));
}

InputDecoration underlineDecoration(Color accent, {String? hint}) => InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(color: t30, fontWeight: FontWeight.w300),
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: underline)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
    );

/// 밑줄 하나로 된 선택 칸 (날짜·시간·목록)
class UnderlineSelect extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const UnderlineSelect({super.key, required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: underline))),
          child: Row(children: [
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15, color: t100, fontWeight: FontWeight.w300))),
            const Icon(Icons.expand_more, size: 16, color: t30),
          ]),
        ),
      );
}

class TextTab extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  final Color accent;
  final Widget? trailing;
  const TextTab({super.key, required this.label, required this.on, required this.onTap, this.accent = t100, this.trailing});
  // 선택하면 글자가 밝아지고 밑줄이 가운데에서 양옆으로 그어짐
  @override
  Widget build(BuildContext context) => Pressable(
        pressedScale: .94,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedDefaultTextStyle(
                  duration: Motion.of(context, Motion.base),
                  style: TextStyle(fontFamily: 'MyCalendarSans', fontWeight: FontWeight.w300, fontSize: 13, color: on ? t100 : t50),
                  child: Text(label),
                ),
                if (trailing != null) ...[const SizedBox(width: 4), trailing!],
              ]),
              const SizedBox(height: 3),
              AnimatedScale(
                scale: on ? 1 : 0,
                duration: Motion.of(context, Motion.base),
                curve: Motion.ease,
                child: Container(height: 1, width: 40, constraints: const BoxConstraints(maxWidth: 40), color: accent),
              ),
            ]),
          ),
        ),
      );
}

ButtonStyle accentButton(WxPalette pal) => TextButton.styleFrom(
      backgroundColor: pal.accent,
      foregroundColor: pal.accentInk,
      shape: const RoundedRectangleBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w300),
    );

ButtonStyle textButton({Color color = t50}) => TextButton.styleFrom(
      foregroundColor: color,
      shape: const RoundedRectangleBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      textStyle: const TextStyle(fontSize: 13),
    );

Color sheetColor(WxPalette pal) => Color.alphaBlend(pal.w0.withAlpha(110), pal.bg).withAlpha(242);

void showToast(BuildContext context, WxPalette pal, String msg, {VoidCallback? undo}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: t100, fontSize: 13)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: pal.bg.withAlpha(235),
      shape: const RoundedRectangleBorder(side: BorderSide(color: hairline)),
      width: 420,
      action: undo == null ? null : SnackBarAction(label: 'Undo', textColor: pal.accent, onPressed: undo),
      duration: Duration(seconds: undo == null ? 3 : 5),
    ));
}

// ===== 일정·할 일 입력 창 =====
/// 저장하면 알림 문구를, 취소하면 null을 돌려줘요
Future<String?> showEditor(
  BuildContext context, {
  required CalendarStore store,
  required WxPalette pal,
  CalEvent? event,
  Todo? todo,
  String? date,
  int? hour,
  bool fromCell = false,
}) =>
    // 입력 창: 살짝 작게 시작해서 커지며 떠오름
    showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0x8C080B0A),
      transitionDuration: Motion.of(context, const Duration(milliseconds: 160)), // 일정 창이 열리는 속도
      pageBuilder: (_, _, _) => _EditorDialog(store: store, pal: pal, event: event, todo: todo, date: date, hour: hour, fromCell: fromCell),
      transitionBuilder: (_, anim, _, child) {
        final a = CurvedAnimation(parent: anim, curve: Motion.ease, reverseCurve: Curves.easeIn);
        return FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween(begin: .96, end: 1.0).animate(a), child: child),
        );
      },
    );

class _EditorDialog extends StatefulWidget {
  final CalendarStore store;
  final WxPalette pal;
  final CalEvent? event;
  final Todo? todo;
  final String? date;
  final int? hour;
  final bool fromCell;
  const _EditorDialog({required this.store, required this.pal, this.event, this.todo, this.date, this.hour, required this.fromCell});
  @override
  State<_EditorDialog> createState() => _EditorDialogState();
}

class _EditorDialogState extends State<_EditorDialog> {
  late String mode = widget.todo != null ? 'todo' : 'event';
  bool get isNew => widget.event == null && widget.todo == null;

  // 일정
  late final titleCtl = TextEditingController(text: widget.event?.title ?? '');
  late final memoCtl = TextEditingController(text: widget.event?.memo ?? '');
  late final newCatCtl = TextEditingController();
  late String date = widget.event?.date ?? widget.date ?? todayStr();
  late bool allDay = widget.event?.allDay ?? false;
  late String start = widget.event?.start ?? '${pad2(widget.hour ?? 9)}:00';
  late String end = widget.event?.end ?? '${pad2(((widget.hour ?? 9) + 1).clamp(0, 23))}:${widget.hour == 23 ? '59' : '00'}';
  late String cat = widget.event?.cat ?? widget.store.cats.first.id;
  late String repeat = widget.event?.repeat ?? 'none';
  late int? remind = widget.event?.remind;
  bool forceSave = false;
  List<CalEvent> warn = [];

  // 할 일
  late final todoCtl = TextEditingController(text: widget.todo?.text ?? '');
  late String due = widget.todo?.due ?? '';
  late bool done = widget.todo?.done ?? false;
  String err = '';

  WxPalette get pal => widget.pal;

  @override
  void dispose() {
    for (final c in [titleCtl, memoCtl, newCatCtl, todoCtl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _switchTab(String m) {
    // 탭을 바꿔도 입력한 제목·날짜는 옮겨 줌
    if (m == 'todo' && mode == 'event') {
      if (todoCtl.text.isEmpty) todoCtl.text = titleCtl.text;
      if (due.isEmpty && widget.fromCell) due = date;
    }
    if (m == 'event' && mode == 'todo') {
      if (titleCtl.text.isEmpty) titleCtl.text = todoCtl.text;
      if (due.isNotEmpty) date = due;
    }
    setState(() {
      mode = m;
      err = '';
    });
  }

  Future<void> _pickDate(String current, void Function(String) set) async {
    final d = await showDatePicker(
      context: context,
      initialDate: current.isEmpty ? DateTime.now() : parseYmd(current),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => set(ymd(d)));
  }

  Future<void> _pickTime(String current, void Function(String) set) async {
    final m = toMin(current);
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60));
    if (t != null) {
      setState(() {
        set('${pad2(t.hour)}:${pad2(t.minute)}');
        forceSave = false;
        warn = [];
      });
    }
  }

  void _save() {
    setState(() => err = '');
    final s = widget.store;
    if (mode == 'todo') {
      final text = todoCtl.text.trim();
      if (text.isEmpty) return setState(() => err = '할 일을 입력해 주세요.');
      if (widget.todo != null) {
        s.updateTodo(widget.todo!.id, text: text, due: due, done: done);
        return Navigator.pop(context, 'Task updated');
      }
      s.addTodo(text, due: due);
      return Navigator.pop(context, due.isEmpty ? 'Task added · Someday' : 'Task added · ${enMonthDay(due)}');
    }
    final title = titleCtl.text.trim();
    if (title.isEmpty) return setState(() => err = '제목을 입력해 주세요.');
    if (cat == '__new' && newCatCtl.text.trim().isEmpty) return setState(() => err = '새 카테고리 이름을 입력해 주세요.');
    if (!allDay && toMin(end) <= toMin(start)) return setState(() => err = '종료 시간은 시작 시간보다 늦어야 해요.');
    final cand = CalEvent(
      id: widget.event?.id ?? newId(),
      title: title,
      date: date,
      allDay: allDay,
      start: allDay ? '00:00' : start,
      end: allDay ? '23:59' : end,
      cat: cat,
      repeat: repeat,
      remind: remind,
      memo: memoCtl.text.trim(),
    );
    final ov = s.overlaps(cand);
    if (ov.isNotEmpty && !forceSave) {
      return setState(() {
        warn = ov;
        forceSave = true;
      });
    }
    if (cat == '__new') cand.cat = s.addCategory(newCatCtl.text.trim()).id;
    s.upsertEvent(cand);
    Navigator.pop(context, widget.event != null ? 'Event updated' : 'Event added');
  }

  Future<void> _delete() async {
    final isTodo = mode == 'todo';
    final repeating = widget.event != null && widget.event!.repeat != 'none';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: sheetColor(pal),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(isTodo ? '이 할 일을 삭제할까요?' : (repeating ? '반복 일정 전체가 삭제돼요. 삭제할까요?' : '이 일정을 삭제할까요?'),
            style: const TextStyle(color: t100, fontSize: 14)),
        actions: [
          TextButton(style: textButton(), onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(style: textButton(color: softRed), onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (isTodo) {
      widget.store.deleteTodo(widget.todo!.id);
      Navigator.pop(context, 'Task deleted');
    } else {
      widget.store.deleteEvent(widget.event!.id);
      Navigator.pop(context, 'Event deleted');
    }
  }

  Widget _two(Widget a, Widget b) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: a),
        const SizedBox(width: 22),
        Expanded(child: b),
      ]);

  Widget _field(String label, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [FieldLabel(label), child]),
      );

  Widget _dropdown<T>(T value, Map<T, String> items, void Function(T?) onChanged) => DropdownButtonHideUnderline(
        child: Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: underline))),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            isDense: false,
            dropdownColor: sheetColor(pal),
            iconSize: 16,
            iconEnabledColor: t30,
            style: const TextStyle(fontSize: 15, color: t100, fontWeight: FontWeight.w300),
            items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: onChanged,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final textStyle = const TextStyle(fontSize: 15, color: t100, fontWeight: FontWeight.w300);
    final title = isNew ? 'New' : (mode == 'todo' ? 'Edit task' : 'Edit event');
    return Dialog(
      backgroundColor: sheetColor(pal),
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: hairline)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(36, 32, 36, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w200, color: t100)),
            const SizedBox(height: 20),
            if (isNew)
              Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Row(children: [
                  TextTab(label: 'Event', on: mode == 'event', onTap: () => _switchTab('event')),
                  const SizedBox(width: 22),
                  TextTab(label: 'Task', on: mode == 'todo', onTap: () => _switchTab('todo')),
                ]),
              ),
            if (mode == 'event') ...[
              _field('TITLE', TextField(controller: titleCtl, autofocus: isNew, style: textStyle, decoration: underlineDecoration(pal.accent, hint: '예: 팀 회의'))),
              _field(
                'DATE',
                _two(
                  UnderlineSelect(text: enFullDate(parseYmd(date)), onTap: () => _pickDate(date, (v) => date = v)),
                  Row(children: [
                    Checkbox(value: allDay, activeColor: pal.accent, checkColor: pal.accentInk, onChanged: (v) => setState(() => allDay = v ?? false)),
                    const Text('All day', style: TextStyle(fontSize: 13, color: t70)),
                  ]),
                ),
              ),
              if (!allDay)
                _field(
                  'START · END',
                  _two(
                    UnderlineSelect(text: start, onTap: () => _pickTime(start, (v) => start = v)),
                    UnderlineSelect(text: end, onTap: () => _pickTime(end, (v) => end = v)),
                  ),
                ),
              _field(
                'CATEGORY · REPEAT',
                _two(
                  _dropdown<String>(cat, {for (final c in s.cats) c.id: c.name, '__new': '+ New category…'}, (v) => setState(() => cat = v ?? cat)),
                  _dropdown<String>(repeat, repeatOptions, (v) => setState(() => repeat = v ?? 'none')),
                ),
              ),
              if (cat == '__new')
                _field('NEW CATEGORY', TextField(controller: newCatCtl, autofocus: true, style: textStyle, decoration: underlineDecoration(pal.accent))),
              _field('REMINDER  ·  앱 알림은 다음 단계에서 연결', _dropdown<int?>(remind, remindOptions, (v) => setState(() => remind = v))),
              _field('MEMO', TextField(controller: memoCtl, maxLines: 2, style: textStyle, decoration: underlineDecoration(pal.accent))),
              if (warn.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: const BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: hairline))),
                  child: Text(
                    '같은 시간에 겹치는 일정이 있어요.\n${warn.map((o) => '· ${o.title} (${o.start}–${o.end})').join('\n')}\n시간을 바꾸거나, 그대로 저장할 수 있어요.',
                    style: const TextStyle(fontSize: 12, height: 1.6, color: Color(0xFFE9CF9A)),
                  ),
                ),
            ] else ...[
              _field('TASK', TextField(controller: todoCtl, autofocus: isNew, style: textStyle, decoration: underlineDecoration(pal.accent, hint: '예: 보고서 초안 쓰기'))),
              _field(
                'DUE  ·  비워 두면 Someday에 들어가요',
                Row(children: [
                  Expanded(child: UnderlineSelect(text: due.isEmpty ? 'No due date' : enFullDate(parseYmd(due)), onTap: () => _pickDate(due, (v) => due = v))),
                  if (due.isNotEmpty) TextButton(style: textButton(), onPressed: () => setState(() => due = ''), child: const Text('Clear')),
                ]),
              ),
              if (widget.todo != null)
                Row(children: [
                  Checkbox(value: done, activeColor: pal.accent, checkColor: pal.accentInk, onChanged: (v) => setState(() => done = v ?? false)),
                  const Text('Done', style: TextStyle(fontSize: 13, color: t70)),
                ]),
            ],
            if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(err, style: const TextStyle(fontSize: 12, color: softRed))),
            const SizedBox(height: 18),
            Row(children: [
              if (!isNew) TextButton(style: textButton(color: softRed), onPressed: _delete, child: const Text('Delete')),
              const Spacer(),
              TextButton(style: textButton(), onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 12),
              TextButton(style: accentButton(pal), onPressed: _save, child: Text(forceSave ? 'Save anyway' : 'Save')),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ===== 분위기 패널 (날씨·상황 직접 고르기) =====
Future<void> showMoodPanel(BuildContext context, {required MoodController mood, required String Function() extraStatus, required bool wide}) {
  final child = _MoodPanel(mood: mood, extraStatus: extraStatus);
  if (!wide) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => child,
    );
  }
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color(0x33000000),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => Align(
      alignment: Alignment.bottomLeft,
      child: Padding(padding: const EdgeInsets.fromLTRB(96, 0, 0, 230), child: SizedBox(width: 400, child: child)),
    ),
    transitionBuilder: (_, anim, _, c) => FadeTransition(
      opacity: anim,
      child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(anim), child: c),
    ),
  );
}

class _MoodPanel extends StatelessWidget {
  final MoodController mood;
  final String Function() extraStatus;
  const _MoodPanel({required this.mood, required this.extraStatus});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: mood,
      builder: (context, _) {
        final pal = paletteOf(mood.theme);
        Widget chips(Map<String, String> opts, String current, String? detected, void Function(String) set) => Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                TextTab(
                  label: 'Auto',
                  on: current == 'auto',
                  accent: pal.accent,
                  onTap: () => set('auto'),
                  trailing: detected == null ? null : Text(detected, style: const TextStyle(fontSize: 11, color: t30)),
                ),
                for (final e in opts.entries) TextTab(label: e.value, on: current == e.key, accent: pal.accent, onTap: () => set(e.key)),
              ],
            );
        Widget row(String label, Widget child) => Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: hairline))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 64, child: Padding(padding: const EdgeInsets.only(top: 4), child: Text(label, style: const TextStyle(fontSize: 11, letterSpacing: 1, color: t30)))),
                Expanded(child: child),
              ]),
            );
        Widget toggle(String title, String sub, bool v, void Function(bool) set) => Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: hairline))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 13, color: t70)),
                    const SizedBox(height: 3),
                    Text(sub, style: const TextStyle(fontSize: 11, color: t30)),
                  ]),
                ),
                Switch(value: v, onChanged: set, activeTrackColor: pal.accent, activeThumbColor: pal.accentInk, inactiveTrackColor: const Color(0x24FFFFFF)),
              ]),
            );
        final extra = extraStatus();
        return Material(
          color: sheetColor(pal),
          shape: const RoundedRectangleBorder(side: BorderSide(color: hairline)),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  const Text('MOOD', style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: t30)),
                  const Spacer(),
                  TextButton(style: textButton(color: pal.accent), onPressed: mood.resetAll, child: const Text('Reset to auto')),
                ]),
                row('WEATHER', chips(weatherLabel, mood.weatherMode, mood.wx == null ? null : weatherLabel[mood.wx!.theme], mood.setWeatherMode)),
                row('TIME', chips(todLabel, mood.todMode, todLabel[mood.autoTod()], mood.setTodMode)),
                row('TEMP', chips(tempLabel, mood.tempMode, mood.autoTemp == null ? null : tempLabel[mood.autoTemp!], mood.setTempMode)),
                row(
                  'EFFECT',
                  Row(children: [
                    Expanded(
                      child: Slider(
                        value: mood.intensity.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 10,
                        activeColor: pal.accent,
                        inactiveColor: const Color(0x24FFFFFF),
                        onChanged: (v) => mood.setIntensity(v.round()),
                      ),
                    ),
                    SizedBox(width: 38, child: Text(mood.intensity == 0 ? 'Off' : '${mood.intensity}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: t70))),
                  ]),
                ),
                toggle('Calm on busy days', '오늘 일정 $busyEvents개 이상이거나 빈 시간이 ${busyFreeMinutes ~/ 60}시간 미만이면 효과를 줄여요', mood.busyCalm, mood.setBusyCalm),
                toggle('Pause during events', '진행 중인 일정을 왼쪽 아래에 표시해요', mood.focus, mood.setFocus),
                const SizedBox(height: 12),
                Text('Now · ${mood.label}${mood.wx != null ? ' · ${mood.wx!.temp}°' : ''}${mood.windStrong ? ' · Windy' : ''}$extra',
                    style: const TextStyle(fontSize: 12, height: 1.6, color: t50)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ===== 카테고리 메뉴 =====
Future<void> showCategoryMenu(BuildContext context, {required CalendarStore store, required WxPalette pal}) {
  final ctl = TextEditingController();
  return showDialog(
    context: context,
    barrierColor: const Color(0x33000000),
    builder: (_) => Dialog(
      alignment: Alignment.topCenter,
      backgroundColor: sheetColor(pal),
      insetPadding: const EdgeInsets.only(top: 110, left: 16, right: 16),
      shape: const RoundedRectangleBorder(side: BorderSide(color: hairline)),
      child: SizedBox(
        width: 320,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CATEGORIES', style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: t30)),
              const SizedBox(height: 8),
              for (final c in store.cats)
                InkWell(
                  onTap: () => store.setCategoryOn(c.id, !c.on),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Checkbox(value: c.on, activeColor: pal.accent, checkColor: pal.accentInk, onChanged: (v) => store.setCategoryOn(c.id, v ?? true)),
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: hexColor(c.color), shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Text(c.name, style: const TextStyle(fontSize: 13, color: t70)),
                    ]),
                  ),
                ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: ctl,
                    style: const TextStyle(fontSize: 13, color: t100),
                    decoration: underlineDecoration(pal.accent, hint: 'New category'),
                    onSubmitted: (v) {
                      if (v.trim().isEmpty) return;
                      store.addCategory(v.trim());
                      ctl.clear();
                    },
                  ),
                ),
                TextButton(
                  style: textButton(color: pal.accent),
                  onPressed: () {
                    if (ctl.text.trim().isEmpty) return;
                    store.addCategory(ctl.text.trim());
                    ctl.clear();
                  },
                  child: const Text('Add'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    ),
  );
}

// ===== 설정 =====
Future<void> showSettings(BuildContext context, {required MoodController mood, required WxPalette pal, required VoidCallback openMood}) {
  return showDialog(
    context: context,
    barrierColor: const Color(0x33000000),
    builder: (c) => Dialog(
      alignment: Alignment.topCenter,
      backgroundColor: sheetColor(pal),
      insetPadding: const EdgeInsets.only(top: 110, left: 16, right: 16),
      shape: const RoundedRectangleBorder(side: BorderSide(color: hairline)),
      child: SizedBox(
        width: 320,
        child: ListenableBuilder(
          listenable: mood,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('MOOD', style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: t30)),
              const SizedBox(height: 10),
              Text(mood.statusText.isEmpty ? '아직 날씨를 확인하지 않았어요.' : mood.statusText, style: const TextStyle(fontSize: 12, height: 1.6, color: t50)),
              Row(children: [
                TextButton(
                  style: textButton(color: pal.accent),
                  onPressed: () {
                    Navigator.pop(c);
                    openMood();
                  },
                  child: const Text('Choose mood'),
                ),
                TextButton(style: textButton(color: pal.accent), onPressed: () => mood.refresh(force: true), child: const Text('Refresh weather')),
              ]),
              const Text('위치는 날씨를 확인할 때만 쓰고 저장하지 않아요. 약 1km 단위로 뭉갠 좌표만 날씨 서비스(Open-Meteo)로 보내요.',
                  style: TextStyle(fontSize: 11, height: 1.6, color: t30)),
              const Divider(color: hairline, height: 32),
              const Text('COMING SOON', style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: t30)),
              const SizedBox(height: 8),
              const Text('일정 알림 · 백업 불러오기(웹 버전 데이터 옮기기) · 로그인과 기기 간 동기화', style: TextStyle(fontSize: 12, height: 1.6, color: t50)),
            ]),
          ),
        ),
      ),
    ),
  );
}
