// 앱 시작점
// 폴더 구조 (확장 원칙: 공통 기능과 기기·화면을 분리)
//   core/  날짜 계산·데이터 모양 (어느 기기에서나 같음)
//   data/  저장소 (기기 안 저장 + 로그인하면 Firebase 서버와 동기화)
//   mood/  날씨·상황(분위기) 판단
//   ui/    화면
import 'package:material_ui/material_ui.dart';

import 'data/calendar_store.dart';
import 'data/sync_service.dart';
import 'mood/mood_controller.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = CalendarStore();
  final mood = MoodController();
  final sync = await SyncService.create(); // Firebase 준비 (아직 연결 전이면 기기 안 저장만 써요)
  await Future.wait([store.load(), mood.load()]);
  store.attachSync(sync); // 일정을 먼저 불러온 뒤에 로그인 상태를 지켜봐요
  runApp(DayglowApp(store: store, mood: mood));
}

class DayglowApp extends StatelessWidget {
  final CalendarStore store;
  final MoodController mood;
  const DayglowApp({super.key, required this.store, required this.mood});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dayglow',
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'DayglowSans', // 앱에 포함한 한글 글꼴 (드문 글자는 기기·웹 기본 글꼴이 대신 표시)
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(primary: Color(0xFFA3BDB3), surface: Color(0xFF1C2321)),
        textTheme: _light(ThemeData.dark().textTheme.apply(
            fontFamily: 'DayglowSans', bodyColor: const Color(0xB8FFFFFF), displayColor: const Color(0xF0FFFFFF))),
        splashFactory: NoSplash.splashFactory,
      ),
      // 따로 굵기를 정하지 않은 글자도 모두 '얇게(300)' — 웹 버전과 같은 조용한 느낌
      builder: (context, child) => DefaultTextStyle.merge(style: const TextStyle(fontWeight: FontWeight.w300), child: child!),
      home: HomePage(store: store, mood: mood),
    );
  }
}

/// 기본 글자 굵기를 '얇게(300)'로 — 숫자를 200으로 낮추면 더 가늘어져요
TextTheme _light(TextTheme t) {
  TextStyle? w(TextStyle? s) => s?.copyWith(fontWeight: FontWeight.w300, letterSpacing: 0);
  return t.copyWith(
    displayLarge: w(t.displayLarge),
    displayMedium: w(t.displayMedium),
    displaySmall: w(t.displaySmall),
    headlineLarge: w(t.headlineLarge),
    headlineMedium: w(t.headlineMedium),
    headlineSmall: w(t.headlineSmall),
    titleLarge: w(t.titleLarge),
    titleMedium: w(t.titleMedium),
    titleSmall: w(t.titleSmall),
    bodyLarge: w(t.bodyLarge),
    bodyMedium: w(t.bodyMedium),
    bodySmall: w(t.bodySmall),
    labelLarge: w(t.labelLarge),
    labelMedium: w(t.labelMedium),
    labelSmall: w(t.labelSmall),
  );
}
