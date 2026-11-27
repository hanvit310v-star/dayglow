// 동기화 기능 자동 테스트 — Firebase를 연결하지 않은 상태에서도 앱이 멀쩡히 동작하는지 확인
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dayglow/core/models.dart';
import 'package:dayglow/data/calendar_store.dart';
import 'package:dayglow/data/sync_service.dart';
import 'package:dayglow/ui/palette.dart';
import 'package:dayglow/ui/sync_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Firebase 연결 전에는 sync 가 꺼져 있고, 일정은 기기 안에 정상 저장된다', () async {
    SharedPreferences.setMockInitialValues({});
    final sync = await SyncService.create();
    expect(sync.available, isFalse);

    final store = CalendarStore();
    await store.load();
    store.attachSync(sync);
    store.upsertEvent(CalEvent(id: 'a', title: '회의', date: '2026-11-27'));
    store.addTodo('보고서', due: '2026-11-28');
    expect(store.events.length, 1);
    expect(store.todos.length, 1);
    expect(store.signedIn, isFalse);
    expect(syncLabel(store), 'Sign in');

    // 앱을 다시 켜도 남아 있어야 함
    final again = CalendarStore();
    await again.load();
    expect(again.events.single.title, '회의');
    expect(again.todos.single.text, '보고서');
  });

  testWidgets('연결 전 Sync 창에 안내 문구가 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = CalendarStore();
    await store.load();
    store.attachSync(await SyncService.create());
    final pal = paletteOf('clear');
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(onPressed: () => showSyncDialog(context, store: store, pal: pal), child: const Text('open')),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('SYNC'), findsOneWidget);
    expect(find.textContaining('서버가 아직 연결되지 않았어요'), findsOneWidget);
  });
}
