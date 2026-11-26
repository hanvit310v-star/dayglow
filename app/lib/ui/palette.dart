// 날씨 테마별 색 묶음 · 글자 명도 — 분위기를 바꾸려면 여기만 고치세요
import 'package:material_ui/material_ui.dart';

class WxPalette {
  final Color w0; // 카드 배경 기본색
  final List<Color> blobs; // 흐린 덩어리 6개 (웹 버전의 w1~w6)
  final Color bg; // 페이지 바탕
  final Color accent; // 유일한 강조색
  final Color accentInk; // 강조색 위 글자
  final Color glass; // 오른쪽 유리 패널

  const WxPalette({
    required this.w0,
    required this.blobs,
    required this.bg,
    required this.accent,
    required this.accentInk,
    required this.glass,
  });
}

const palettes = <String, WxPalette>{
  // 비: 차분한 청록 (기본값)
  'rain': WxPalette(
    w0: Color(0xFF34423E),
    blobs: [Color(0xFF121816), Color(0xFF18201E), Color(0xFF5D726C), Color(0xFF46574F), Color(0xFF3D4C47), Color(0xFF2B3734)],
    bg: Color(0xFF141917),
    accent: Color(0xFFA3BDB3),
    accentInk: Color(0xFF17201D),
    glass: Color(0x7A181F1D),
  ),
  // 맑음: 따뜻한 샴페인·모래빛
  'clear': WxPalette(
    w0: Color(0xFF5A4C3D),
    blobs: [Color(0xFF2A241D), Color(0xFF3A3128), Color(0xFFA08B6C), Color(0xFF7D6A52), Color(0xFFC2A47A), Color(0xFF3D342A)],
    bg: Color(0xFF17140F),
    accent: Color(0xFFDCC39A),
    accentInk: Color(0xFF231C12),
    glass: Color(0x73241E17),
  ),
  // 맑은 밤: 깊은 남색
  'night': WxPalette(
    w0: Color(0xFF1E2645),
    blobs: [Color(0xFF0C1020), Color(0xFF121831), Color(0xFF3A4A78), Color(0xFF26315A), Color(0xFF4A5A8C), Color(0xFF1A2040)],
    bg: Color(0xFF0B0E18),
    accent: Color(0xFFAEBBE6),
    accentInk: Color(0xFF11162A),
    glass: Color(0x800E1222),
  ),
  // 흐림: 슬레이트 회색
  'cloudy': WxPalette(
    w0: Color(0xFF424A4F),
    blobs: [Color(0xFF1C1F21), Color(0xFF25292C), Color(0xFF6E777C), Color(0xFF535B60), Color(0xFF7D868B), Color(0xFF2F3438)],
    bg: Color(0xFF151719),
    accent: Color(0xFFC3CBD0),
    accentInk: Color(0xFF1B1F22),
    glass: Color(0x7A1C2023),
  ),
  // 눈: 차가운 얼음빛 청회색
  'snow': WxPalette(
    w0: Color(0xFF55626E),
    blobs: [Color(0xFF2F3A45), Color(0xFF3E4A56), Color(0xFF93A5B4), Color(0xFF738595), Color(0xFFB4C4D1), Color(0xFF4A5763)],
    bg: Color(0xFF161B20),
    accent: Color(0xFFE2ECF4),
    accentInk: Color(0xFF1C2530),
    glass: Color(0x991A222A),
  ),
  // 안개: 회백색 그레이지
  'fog': WxPalette(
    w0: Color(0xFF5E5C56),
    blobs: [Color(0xFF2C2B28), Color(0xFF3A3935), Color(0xFF8C8981), Color(0xFF77746C), Color(0xFFA29E94), Color(0xFF4A4843)],
    bg: Color(0xFF171715),
    accent: Color(0xFFD8D1C3),
    accentInk: Color(0xFF22201B),
    glass: Color(0x73282724),
  ),
  // 뇌우: 짙은 남보라
  'storm': WxPalette(
    w0: Color(0xFF23263A),
    blobs: [Color(0xFF0B0C12), Color(0xFF11131C), Color(0xFF3E4459), Color(0xFF2C3144), Color(0xFF4C4566), Color(0xFF1A1C28)],
    bg: Color(0xFF0B0C10),
    accent: Color(0xFFBCB0E0),
    accentInk: Color(0xFF18152A),
    glass: Color(0x8510111A),
  ),
};

WxPalette paletteOf(String theme) => palettes[theme] ?? palettes['rain']!;

// 글자 명도 위계: 색을 늘리지 않고 투명도로 중요도를 나눔
const t100 = Color(0xF0FFFFFF); // 주인공
const t70 = Color(0xB8FFFFFF); // 일반 내용
const t50 = Color(0x80FFFFFF); // 항목명·보조
const t30 = Color(0x4DFFFFFF); // 아주 흐린 정보
const hairline = Color(0x17FFFFFF); // 얇은 구분선
const underline = Color(0x2EFFFFFF); // 입력창 밑줄
const softRed = Color(0xFFE8968F); // 삭제·마감 지남

Color hexColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.tryParse('FF$h', radix: 16) ?? 0xFFA7AAA8);
}
