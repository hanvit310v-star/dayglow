// 날씨를 화면에 입히는 부품들
//  · 일정 칩의 날씨 질감 · 하늘 띠(새벽→낮→노을→밤) · 우산 표시 · 비 안내 창 · 산책 카드
import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../core/calendar_logic.dart';
import '../core/models.dart';
import '../mood/forecast.dart';
import 'editors.dart';
import 'motion.dart';
import 'palette.dart';
import 'strings.dart';

// ===== 날씨 아이콘 · 색 =====
IconData wxIcon(String theme) => switch (theme) {
      'clear' => Icons.wb_sunny_outlined,
      'night' => Icons.nights_stay_outlined,
      'cloudy' => Icons.cloud_outlined,
      'rain' => Icons.water_drop_outlined,
      'snow' => Icons.ac_unit,
      'fog' => Icons.foggy,
      'storm' => Icons.thunderstorm_outlined,
      _ => Icons.cloud_outlined,
    };

/// 월간 '날씨 보기'에서 날짜 칸에 입히는 색 (날씨마다 다른 색)
Color wxTint(String theme) => switch (theme) {
      'clear' => const Color(0xFFE3B665),
      'cloudy' => const Color(0xFF9AA3A8),
      'rain' => const Color(0xFF5E8FC7),
      'snow' => const Color(0xFFCFE3F2),
      'storm' => const Color(0xFF8A72C4),
      'fog' => const Color(0xFF8FA39B),
      _ => const Color(0xFF6E7CB5),
    };

const rainBlue = Color(0xFF8FB3D9);

// ===== 일정 칩에 깔리는 날씨 질감 =====
/// 일정 시작 시각의 예보에 따라 칩 표면이 달라져요 (맑음=따뜻한 빛, 비=빗줄기, 눈=눈송이, 흐림=구름, 안개=뿌연 막)
/// 반드시 Stack 안에서 Positioned.fill 로 쓰세요.
Widget weatherTexture(Forecast f, CalEvent e, String ds, {double radius = 7}) {
  final theme = e.allDay ? f.day(ds)?.theme : (f.hour(ds, toMin(e.start) ~/ 60)?.theme ?? f.day(ds)?.theme);
  if (theme == null) return const SizedBox.shrink();
  return Positioned.fill(
    child: IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(painter: _TexturePainter(theme, e.id.hashCode)),
      ),
    ),
  );
}

class _TexturePainter extends CustomPainter {
  final String theme;
  final int seed;
  _TexturePainter(this.theme, this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rnd = Random(seed);
    final rect = Offset.zero & size;
    final area = size.width * size.height;
    void gradient(Alignment a, Alignment b, Color c1, Color c2) =>
        canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: a, end: b, colors: [c1, c2]).createShader(rect));

    switch (theme) {
      case 'clear':
        gradient(Alignment.topLeft, Alignment.bottomRight, const Color(0x3CF5D28A), const Color(0x00F5D28A));
      case 'cloudy':
        final p = Paint()
          ..color = const Color(0x22FFFFFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawOval(Rect.fromCenter(center: Offset(size.width * .3, size.height * .38), width: size.width * .55, height: size.height * .7), p);
        canvas.drawOval(Rect.fromCenter(center: Offset(size.width * .72, size.height * .62), width: size.width * .5, height: size.height * .6), p);
      case 'fog':
        gradient(Alignment.topCenter, Alignment.bottomCenter, const Color(0x30FFFFFF), const Color(0x0EFFFFFF));
      case 'rain' || 'storm':
        final storm = theme == 'storm';
        canvas.drawRect(rect, Paint()..color = storm ? const Color(0x228A72C4) : const Color(0x185E8FC7));
        final p = Paint()
          ..color = Color(storm ? 0x70FFFFFF : 0x4EFFFFFF)
          ..strokeWidth = .9
          ..strokeCap = StrokeCap.round;
        final n = (area / (storm ? 240 : 340)).clamp(3, 46).toInt();
        for (var i = 0; i < n; i++) {
          final x = rnd.nextDouble() * (size.width + 6), y = rnd.nextDouble() * size.height;
          canvas.drawLine(Offset(x, y), Offset(x - 2, y + 6), p);
        }
      case 'snow':
        final p = Paint()..color = const Color(0x78FFFFFF);
        final n = (area / 380).clamp(3, 32).toInt();
        for (var i = 0; i < n; i++) {
          canvas.drawCircle(Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height), .8 + rnd.nextDouble() * .8, p);
        }
      case 'night':
        final p = Paint()..color = const Color(0x55FFFFFF);
        final n = (area / 900).clamp(2, 10).toInt();
        for (var i = 0; i < n; i++) {
          canvas.drawCircle(Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height), .6, p);
        }
    }
  }

  @override
  bool shouldRepaint(_TexturePainter old) => old.theme != theme || old.seed != seed;
}

// ===== 우산 표시 (야외 일정이 비를 맞을 때) =====
Widget umbrellaBadge(VoidCallback onTap, {double size = 12}) => Tooltip(
      message: 'Rain expected · tap for better times',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(Icons.umbrella, size: size, color: rainBlue),
        ),
      ),
    );

// ===== 하늘 띠: 새벽 → 낮(날씨 색) → 노을 → 밤 =====
const _night = Color(0xFF182046), _dawn = Color(0xFFE2A68A), _dusk = Color(0xFFE59B6E), _twilight = Color(0xFF6D5C9E);

Color _dayColor(String? theme) => switch (theme) {
      'rain' => const Color(0xFF6C8CAE),
      'storm' => const Color(0xFF6B6896),
      'snow' => const Color(0xFFD8E6F0),
      'cloudy' => const Color(0xFF9AA6AF),
      'fog' => const Color(0xFFA9B5B0),
      _ => const Color(0xFFA8D2EC),
    };

/// 하루 중 [m]분 시각의 하늘 색
Color skyColorAt(int m, int sr, int ss, String? theme) {
  Color l(Color a, Color b, int from, int to) => Color.lerp(a, b, ((m - from) / (to - from)).clamp(0.0, 1.0))!;
  final day = _dayColor(theme);
  if (m < sr - 60 || m >= ss + 90) return _night;
  if (m < sr) return l(_night, _dawn, sr - 60, sr);
  if (m < sr + 60) return l(_dawn, day, sr, sr + 60);
  if (m < ss - 90) return day;
  if (m < ss) return l(day, _dusk, ss - 90, ss);
  if (m < ss + 45) return l(_dusk, _twilight, ss, ss + 45);
  return l(_twilight, _night, ss + 45, ss + 90);
}

/// 시간 칸 왼쪽의 가는 세로 띠. 해 뜨고 지는 시각과 시간별 날씨를 반영해요.
class SkyStrip extends StatelessWidget {
  final DayWx? day;
  final Forecast forecast;
  final String ds;
  const SkyStrip({super.key, required this.day, required this.forecast, required this.ds});

  @override
  Widget build(BuildContext context) {
    final sr = day?.sunriseMin ?? 6 * 60 + 30, ss = day?.sunsetMin ?? 18 * 60;
    final colors = <Color>[], stops = <double>[];
    for (var h = 0; h < 24; h++) {
      colors.add(skyColorAt(h * 60 + 30, sr, ss, forecast.hour(ds, h)?.theme ?? day?.theme));
      stops.add((h + .5) / 24);
    }
    colors
      ..insert(0, colors.first)
      ..add(colors.last);
    stops
      ..insert(0, 0)
      ..add(1);
    // 예보가 없는 날(지난 날·16일 밖)은 기본 해 뜨고 지는 시각만 쓰고 흐리게 보여서, 실제 예보처럼 보이지 않게 해요
    return Opacity(
      opacity: day == null ? .3 : 1,
      child: Container(
        width: 3,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors, stops: stops),
        ),
      ),
    );
  }
}

/// 요일 머리에 붙는 작은 날씨 표시: 아이콘 + 최고(/최저) 기온
Widget dayWxMini(DayWx d, {bool full = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(wxIcon(d.theme), size: 11, color: t50),
      const SizedBox(width: 3),
      Text(full ? '${d.tMax}° / ${d.tMin}°' : '${d.tMax}°', style: const TextStyle(fontSize: 10, color: t50)),
    ]);

// ===== 비 안내 창: 더 좋은 시간 후보 =====
/// 고른 후보를 돌려줘요 (그대로 두면 null)
Future<Slot?> showRainHelp(
  BuildContext context, {
  required WxPalette pal,
  required CalEvent event,
  required String ds,
  required RainRisk risk,
  required List<Slot> slots,
}) =>
    showDialog<Slot>(
      context: context,
      barrierColor: const Color(0x8C080B0A),
      builder: (ctx) {
        final repeats = event.repeat != 'none';
        return Dialog(
          backgroundColor: sheetColor(pal),
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: hairline)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  const Icon(Icons.umbrella, size: 18, color: rainBlue),
                  const SizedBox(width: 10),
                  Text(risk.theme == 'snow' ? 'Snow expected' : 'Rain expected',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w200, color: t100)),
                ]),
                const SizedBox(height: 10),
                Text(
                  '${event.title} · ${enDayLabel(ds)} ${pad2(risk.fromHour)}:00–${pad2(risk.toHour)}:00 · ${risk.maxRain}% chance',
                  style: const TextStyle(fontSize: 12, height: 1.5, color: t50),
                ),
                const SizedBox(height: 22),
                if (repeats)
                  const Text('반복 일정은 한 번만 옮길 수 없어요. 일정을 열어서 직접 바꿔 주세요.',
                      style: TextStyle(fontSize: 12, height: 1.6, color: Color(0xFFE9CF9A)))
                else if (slots.isEmpty)
                  const Text('앞으로 열흘 안에서, 비가 안 오고 다른 일정과 안 겹치는 시간을 찾지 못했어요.',
                      style: TextStyle(fontSize: 12, height: 1.6, color: Color(0xFFE9CF9A)))
                else ...[
                  const FieldLabel('BETTER TIMES · TAP TO MOVE'),
                  for (final s in slots)
                    Pressable(
                      pressedScale: .985,
                      hoverGlow: true,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, s),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Row(children: [
                            Icon(wxIcon(s.wx?.theme ?? 'clear'), size: 15, color: t70),
                            const SizedBox(width: 12),
                            Expanded(child: Text('${enDayLabel(s.ds)}  ·  ${s.startText}–${s.endText}', style: const TextStyle(fontSize: 14, color: t100))),
                            if (s.wx != null) Text('${s.wx!.temp}° · ${s.wx!.rain}%', style: const TextStyle(fontSize: 12, color: t50)),
                          ]),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(style: textButton(), onPressed: () => Navigator.pop(ctx), child: const Text('Keep as is')),
                ),
              ]),
            ),
          ),
        );
      },
    );

// ===== 산책하기 좋은 시간 카드 (오른쪽 패널) =====
class WalkCard extends StatelessWidget {
  final Slot slot;
  final WxPalette pal;
  final VoidCallback onAdd;
  const WalkCard({super.key, required this.slot, required this.pal, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final w = slot.wx;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: wxTint(w?.theme ?? 'clear').withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: wxTint(w?.theme ?? 'clear').withAlpha(70)),
      ),
      child: Row(children: [
        Icon(wxIcon(w?.theme ?? 'clear'), size: 18, color: t70),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Good for a walk', style: TextStyle(fontSize: 13, color: t100)),
            const SizedBox(height: 3),
            Text(
              '${slot.startText}–${slot.endText} · free${w != null ? ' · ${weatherLabelEn(w.theme)} ${w.temp}°' : ''}',
              style: const TextStyle(fontSize: 11.5, color: t50),
            ),
          ]),
        ),
        TextButton(style: textButton(color: pal.accent), onPressed: onAdd, child: const Text('Add')),
      ]),
    );
  }
}

String weatherLabelEn(String theme) => switch (theme) {
      'clear' => 'Clear',
      'night' => 'Clear',
      'cloudy' => 'Cloudy',
      'rain' => 'Rain',
      'snow' => 'Snow',
      'fog' => 'Fog',
      'storm' => 'Storm',
      _ => '',
    };
