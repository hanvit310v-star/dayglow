// 카드 뒤의 흐린 대기 배경 + 시간대·기온 빛 + 날씨 효과(빗줄기·눈송이·별·햇빛·안개·번쩍임)
import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'palette.dart';

class Atmosphere extends StatefulWidget {
  final String theme;
  final String tod;
  final String temp;
  final double effectOpacity; // 효과 세기 (0~1)
  final bool paused; // 일정 진행 중이면 효과 멈춤
  final bool windStrong;

  const Atmosphere({
    super.key,
    required this.theme,
    required this.tod,
    required this.temp,
    required this.effectOpacity,
    required this.paused,
    required this.windStrong,
  });

  @override
  State<Atmosphere> createState() => _AtmosphereState();
}

class _Particle {
  final double x, y, size, alpha, duration, delay;
  _Particle(this.x, this.y, this.size, this.alpha, this.duration, this.delay);
}

class _AtmosphereState extends State<Atmosphere> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(hours: 1));
  List<_Particle> _parts = [];

  @override
  void initState() {
    super.initState();
    _build();
    _syncClock();
  }

  @override
  void didUpdateWidget(Atmosphere old) {
    super.didUpdateWidget(old);
    if (old.theme != widget.theme) _build();
    _syncClock();
  }

  void _syncClock() {
    final moving = !widget.paused && widget.effectOpacity > 0;
    if (moving && !_clock.isAnimating) _clock.repeat();
    if (!moving && _clock.isAnimating) _clock.stop();
  }

  void _build() {
    final r = Random();
    double rr(double a, double b) => a + r.nextDouble() * (b - a);
    final n = switch (widget.theme) { 'storm' => 90, 'rain' => 65, 'snow' || 'night' => 55, _ => 0 };
    _parts = List.generate(n, (_) {
      switch (widget.theme) {
        case 'snow':
          return _Particle(rr(0, 1), 0, rr(1, 2.5), rr(.35, .9), rr(12, 24), rr(0, 24));
        case 'night':
          return _Particle(rr(0, 1), rr(0, .7), 1, 1, rr(3, 7), rr(0, 7));
        default: // 빗줄기
          return _Particle(rr(0, 1.12), 0, rr(40, 90), rr(.25, .9), rr(.7, 1.3), rr(0, 2));
      }
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = paletteOf(widget.theme);
    return Stack(fit: StackFit.expand, children: [
      // 1) 흐린 대기 배경 (테마가 바뀌면 부드럽게 겹쳐 바뀜)
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 1200),
        child: ImageFiltered(
          key: ValueKey(widget.theme),
          imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40, tileMode: TileMode.decal),
          child: CustomPaint(painter: _BlobPainter(pal), size: Size.infinite),
        ),
      ),
      // 2) 시간대 빛 (새벽·노을·밤)
      _glow(widget.tod == 'dawn', const [
        (Alignment(-0.4, 1.16), 0.9, Color(0x3DFFAC96)),
        (Alignment(0.64, 1.04), 0.6, Color(0x24FFD0A5)),
      ]),
      _glow(widget.tod == 'dusk', const [
        (Alignment(-0.7, 1.16), 1.0, Color(0x42FF8E52)),
        (Alignment(0.44, 1.08), 0.8, Color(0x33AC5CA5)),
      ]),
      AnimatedOpacity(
        opacity: widget.tod == 'night' && widget.theme != 'night' ? 1 : 0,
        duration: const Duration(milliseconds: 1600),
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x57040712), Color(0x33040712)],
            ),
          ),
        ),
      ),
      // 3) 기온 빛 (폭염: 붉은 열기 / 한파: 가장자리 냉기)
      _glow(widget.temp == 'heat', const [(Alignment(0, 1.24), 1.1, Color(0x38FF7642))]),
      AnimatedOpacity(
        opacity: widget.temp == 'cold' ? 1 : 0,
        duration: const Duration(milliseconds: 1600),
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(radius: 1.1, stops: [0.55, 1], colors: [Color(0x00E2F0FF), Color(0x2BE2F0FF)]),
          ),
        ),
      ),
      // 4) 날씨 효과
      IgnorePointer(
        child: AnimatedOpacity(
          opacity: widget.effectOpacity,
          duration: const Duration(milliseconds: 600),
          child: AnimatedBuilder(
            animation: _clock,
            builder: (_, _) => CustomPaint(
              size: Size.infinite,
              painter: _FxPainter(
                theme: widget.theme,
                parts: _parts,
                t: _clock.value * 3600,
                windStrong: widget.windStrong,
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _glow(bool on, List<(Alignment, double, Color)> spots) => AnimatedOpacity(
        opacity: on ? 1 : 0,
        duration: const Duration(milliseconds: 1600),
        child: Stack(fit: StackFit.expand, children: [
          for (final s in spots)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(center: s.$1, radius: s.$2, colors: [s.$3, s.$3.withAlpha(0)], stops: const [0, 0.7]),
              ),
            ),
        ]),
      );
}

/// 흐린 덩어리 6개 (웹 버전과 같은 위치·크기)
class _BlobPainter extends CustomPainter {
  final WxPalette pal;
  _BlobPainter(this.pal);

  static const _spots = [
    (0.58, 0.18, 0.30, 0.32),
    (0.72, 0.62, 0.26, 0.30),
    (0.22, 0.40, 0.40, 0.38),
    (0.40, 0.85, 0.35, 0.40),
    (0.88, 0.30, 0.30, 0.30),
    (0.95, 0.95, 0.45, 0.45),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = pal.w0);
    for (var i = 0; i < _spots.length; i++) {
      final (cx, cy, rx, ry) = _spots[i];
      final c = pal.blobs[i];
      final rX = rx * size.width, rY = ry * size.height;
      canvas.save();
      canvas.translate(cx * size.width, cy * size.height);
      canvas.scale(1, rY / rX);
      final paint = Paint()
        ..shader = RadialGradient(colors: [c, c.withAlpha(0)], stops: const [0, 0.7])
            .createShader(Rect.fromCircle(center: Offset.zero, radius: rX));
      canvas.drawCircle(Offset.zero, rX, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.pal != pal;
}

class _FxPainter extends CustomPainter {
  final String theme;
  final List<_Particle> parts;
  final double t; // 흐른 시간(초)
  final bool windStrong;

  _FxPainter({required this.theme, required this.parts, required this.t, required this.windStrong});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    switch (theme) {
      case 'rain':
      case 'storm':
        final tilt = (windStrong ? 22 : 8) * pi / 180;
        final drift = windStrong ? -430.0 : -150.0;
        const fall = 1150.0;
        for (final p in parts) {
          final ph = ((t + p.delay) / p.duration) % 1;
          final x = p.x * w + drift * ph;
          final y = -90 + fall * ph * (h + 90) / fall;
          final dx = -sin(tilt) * p.size, dy = cos(tilt) * p.size;
          final paint = Paint()
            ..strokeWidth = 1
            ..shader = ui.Gradient.linear(Offset(x, y), Offset(x + dx, y + dy),
                [const Color(0x00FFFFFF), Color.fromRGBO(255, 255, 255, 0.28 * p.alpha)]);
          canvas.drawLine(Offset(x, y), Offset(x + dx, y + dy), paint);
        }
        if (theme == 'storm') {
          final f = (t % 11) / 11;
          final a = (f > 0.90 && f < 0.925) ? 0.09 : (f > 0.94 && f < 0.95 ? 0.05 : 0.0);
          if (a > 0) canvas.drawRect(Offset.zero & size, Paint()..color = Color.fromRGBO(220, 214, 255, a));
        }
      case 'snow':
        for (final p in parts) {
          final ph = ((t + p.delay) / p.duration) % 1;
          final y = -20 + ph * (h + 40);
          final x = p.x * w + sin(ph * 2 * pi * 2) * 14;
          canvas.drawCircle(Offset(x, y), p.size,
              Paint()
                ..color = Color.fromRGBO(255, 255, 255, 0.75 * p.alpha)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6));
        }
      case 'night':
        for (final p in parts) {
          final a = 0.12 + 0.58 * (0.5 + 0.5 * sin(2 * pi * (t / p.duration + p.delay)));
          canvas.drawCircle(Offset(p.x * w, p.y * h), 1, Paint()..color = Color.fromRGBO(255, 255, 255, a));
        }
      case 'clear':
        final s = 1 + 0.06 * (0.5 + 0.5 * sin(2 * pi * t / 10));
        final c = Offset(w * 0.93, -h * 0.05);
        final r = max(w, h) * 0.55 * s;
        canvas.drawCircle(
            c,
            r,
            Paint()
              ..shader = RadialGradient(colors: const [Color(0x52FFDDAA), Color(0x1AFFC88C), Color(0x00FFC88C)], stops: const [0, 0.55, 1])
                  .createShader(Rect.fromCircle(center: c, radius: r)));
      case 'fog':
      case 'cloudy':
        final dark = theme == 'cloudy';
        final shift = sin(2 * pi * t / (dark ? 80 : 52)) * w * 0.08;
        final spots = dark
            ? [(0.25, 0.30, 0.30, const Color(0x38000000)), (0.70, 0.25, 0.28, const Color(0x0FFFFFFF))]
            : [(0.30, 0.35, 0.40, const Color(0x24FFFFFF)), (0.75, 0.30, 0.35, const Color(0x1AFFFFFF)), (0.60, 0.70, 0.45, const Color(0x1FFFFFFF))];
        for (final (cx, cy, rr, col) in spots) {
          final c = Offset(cx * w + shift, cy * h);
          final r = rr * w;
          canvas.drawCircle(
              c,
              r,
              Paint()
                ..shader = RadialGradient(colors: [col, col.withAlpha(0)]).createShader(Rect.fromCircle(center: c, radius: r)));
        }
    }
  }

  @override
  bool shouldRepaint(_FxPainter old) => true;
}
