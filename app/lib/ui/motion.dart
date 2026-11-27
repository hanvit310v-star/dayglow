// 마이크로 인터랙션 부품 — 짧고(0.12~0.4초) 부드러운 움직임만 사용
// 기기에서 '동작 줄이기'를 켠 사용자에게는 움직임을 끔
import 'package:material_ui/material_ui.dart';

/// 움직임 기준값 — 속도·느낌을 바꾸려면 여기만 고치세요
class Motion {
  // 반응이 빠르게 느껴지도록 전체적으로 짧게 조정 (숫자가 클수록 느긋해짐)
  static const fast = Duration(milliseconds: 100); // 누르기·마우스 올리기
  static const base = Duration(milliseconds: 180); // 색·밑줄 바뀜
  static const slow = Duration(milliseconds: 260); // 숫자 굴러가기·화면 넘기기
  static const stagger = Duration(milliseconds: 30); // 목록이 차례로 나타나는 간격
  static const ease = Curves.easeOutCubic;

  /// '동작 줄이기'를 켰으면 true
  static bool reduced(BuildContext c) => MediaQuery.maybeDisableAnimationsOf(c) ?? false;
  static Duration of(BuildContext c, Duration d) => reduced(c) ? Duration.zero : d;
}

/// 누르면 살짝 눌리고(97%), 마우스를 올리면 손가락 커서 + 은은하게 밝아짐
/// (안쪽의 GestureDetector·버튼 동작은 그대로 둠)
class Pressable extends StatefulWidget {
  final Widget child;
  final double pressedScale;
  final bool hoverGlow;
  final BorderRadius? radius;
  const Pressable({super.key, required this.child, this.pressedScale = .97, this.hoverGlow = false, this.radius});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false, _hover = false;
  @override
  Widget build(BuildContext context) {
    final d = Motion.of(context, Motion.fast);
    Widget child = AnimatedScale(
      scale: _down ? widget.pressedScale : 1,
      duration: d,
      curve: Motion.ease,
      child: widget.child,
    );
    if (widget.hoverGlow) {
      child = AnimatedContainer(
        duration: Motion.of(context, Motion.base),
        decoration: BoxDecoration(
          color: _hover ? const Color(0x0AFFFFFF) : const Color(0x00FFFFFF),
          borderRadius: widget.radius,
        ),
        child: child,
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: child,
      ),
    );
  }
}

/// 글자가 바뀌면 위(또는 아래)로 굴러가듯 교체 — 큰 날짜·숫자용
class RollingText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int direction; // 1: 아래에서 위로, -1: 위에서 아래로
  final Alignment alignment;
  const RollingText(this.text, {super.key, this.style, this.direction = 1, this.alignment = Alignment.bottomLeft});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.slow),
      switchInCurve: Motion.ease,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (cur, prev) => Stack(alignment: alignment, clipBehavior: Clip.none, children: [...prev, ?cur]),
      transitionBuilder: (child, anim) {
        final incoming = child.key == ValueKey(text);
        final dy = 0.45 * (direction >= 0 ? 1 : -1);
        final offset = Tween(begin: Offset(0, incoming ? dy : -dy), end: Offset.zero).animate(anim);
        return ClipRect(
          child: FadeTransition(opacity: anim, child: SlideTransition(position: offset, child: child)),
        );
      },
      child: Text(text, key: ValueKey(text), style: style, maxLines: 1, overflow: TextOverflow.visible, softWrap: false),
    );
  }
}

/// 처음 나타날 때 순서대로(index) 살짝 떠오르며 나타남 — 목록용
class StaggerIn extends StatefulWidget {
  final int index;
  final Widget child;
  final double distance;
  const StaggerIn({super.key, required this.index, required this.child, this.distance = 8});
  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Motion.ease);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status == AnimationStatus.dismissed) {
      if (Motion.reduced(context)) {
        _c.value = 1;
      } else {
        Future.delayed(Motion.stagger * widget.index.clamp(0, 12), () {
          if (mounted) _c.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        child: widget.child,
        builder: (_, child) => Opacity(
          opacity: _a.value,
          child: Transform.translate(offset: Offset(0, widget.distance * (1 - _a.value)), child: child),
        ),
      );
}

/// 화면(달력)이 바뀔 때: 들어오는 쪽은 방향대로 살짝 밀려 들어오고, 나가는 쪽은 사라짐
class SlideSwitcher extends StatelessWidget {
  final Object switchKey;
  final int direction; // -1: 이전(왼쪽에서), 1: 다음(오른쪽에서), 0: 아래에서 살짝
  final bool fill;
  final Widget child;
  const SlideSwitcher({super.key, required this.switchKey, required this.direction, required this.child, this.fill = false});

  @override
  Widget build(BuildContext context) {
    final key = ValueKey(switchKey);
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.slow),
      switchInCurve: Motion.ease,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (cur, prev) => Stack(
        fit: fill ? StackFit.expand : StackFit.loose,
        alignment: Alignment.topLeft,
        children: [...prev, ?cur],
      ),
      transitionBuilder: (child, anim) {
        if (child.key != key) return FadeTransition(opacity: anim, child: child); // 나가는 화면
        final begin = direction == 0 ? const Offset(0, .015) : Offset(.035 * direction, 0);
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: Tween(begin: begin, end: Offset.zero).animate(anim), child: child),
        );
      },
      child: KeyedSubtree(key: key, child: child),
    );
  }
}

/// 체크하면 톡 튀어 오르는 효과
class PopOnChange extends StatelessWidget {
  final bool value;
  final Widget child;
  const PopOnChange({super.key, required this.value, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey(value),
        tween: Tween(begin: Motion.reduced(context) ? 1 : .7, end: 1),
        duration: Motion.of(context, const Duration(milliseconds: 340)),
        curve: Curves.easeOutBack,
        builder: (_, s, c) => Transform.scale(scale: s, child: c),
        child: child,
      );
}
