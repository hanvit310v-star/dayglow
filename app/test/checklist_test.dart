// 체크리스트 기능 자동 테스트 — 저장·불러오기·체크·마감일 표시용 목록
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dayglow/core/models.dart';
import 'package:dayglow/data/calendar_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('체크리스트 진행률과 JSON 변환', () {
    final l = Checklist(id: 'l1', title: '장보기', due: '2026-11-30', items: [
      CheckItem(id: 'a', text: '우유', done: true),
      CheckItem(id: 'b', text: '계란'),
    ]);
    expect(l.doneCount, 1);
    expect(l.allDone, isFalse);
    l.items[1].done = true;
    expect(l.allDone, isTrue);
    expect(Checklist(id: 'e', title: '빈 목록').allDone, isFalse); // 항목이 없으면 '완료'가 아님
    final back = Checklist.fromJson(l.toJson());
    expect(back.title, '장보기');
    expect(back.items.map((i) => i.text), ['우유', '계란']);
    expect(back.items.first.done, isTrue);
    // 항목이 없는 옛 데이터도 읽힘
    expect(Checklist.fromJson({'id': 'x', 'title': 't'}).items, isEmpty);
  });

  test('저장소: 추가·체크·항목 추가·마감일별 조회·삭제, 앱을 다시 켜도 남는다', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CalendarStore();
    await store.load();
    store.upsertList(Checklist(id: 'l1', title: '여행 짐', due: '2026-12-01', items: [CheckItem(id: 'a', text: '여권')]));
    store.upsertList(Checklist(id: 'l2', title: '언젠가', items: [CheckItem(id: 'b', text: '책 읽기')]));
    expect(store.lists.length, 2);
    expect(store.listsDue('2026-12-01').map((l) => l.id), ['l1']);
    expect(store.listsDue('2026-12-02'), isEmpty);

    store.toggleListItem('l1', 'a');
    store.addListItem('l1', '충전기');
    expect(store.lists.first.doneCount, 1);
    expect(store.lists.first.items.length, 2);

    final again = CalendarStore();
    await again.load();
    expect(again.lists.length, 2);
    expect(again.lists.first.items.map((i) => i.text), ['여권', '충전기']);
    expect(again.lists.first.items.first.done, isTrue);

    again.deleteList('l1');
    expect(again.lists.map((l) => l.id), ['l2']);
  });
}
