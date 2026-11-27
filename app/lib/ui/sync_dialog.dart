// 로그인 · 기기 간 동기화 창
// 세 가지 모습: ① 서버 연결 전 안내 ② 로그인 전(이메일·구글) ③ 로그인 후(상태·로그아웃·계정 삭제)
import 'package:material_ui/material_ui.dart';

import '../data/calendar_store.dart';
import '../data/sync_service.dart';
import 'editors.dart';
import 'palette.dart';

/// 상단 바 버튼에 보일 글자
String syncLabel(CalendarStore store) {
  final s = store.sync;
  if (s == null || !s.available) return 'Sign in';
  if (s.user == null) return 'Sign in';
  if (s.error != null) return 'Sync issue';
  return s.loading ? 'Syncing…' : 'Synced';
}

Future<void> showSyncDialog(BuildContext context, {required CalendarStore store, required WxPalette pal}) {
  return showDialog(
    context: context,
    barrierColor: const Color(0x33000000),
    builder: (_) => Dialog(
      alignment: Alignment.topCenter,
      backgroundColor: sheetColor(pal),
      insetPadding: const EdgeInsets.only(top: 110, left: 16, right: 16),
      shape: const RoundedRectangleBorder(side: BorderSide(color: hairline)),
      child: SizedBox(width: 340, child: _SyncBody(store: store, pal: pal)),
    ),
  );
}

class _SyncBody extends StatefulWidget {
  final CalendarStore store;
  final WxPalette pal;
  const _SyncBody({required this.store, required this.pal});
  @override
  State<_SyncBody> createState() => _SyncBodyState();
}

class _SyncBodyState extends State<_SyncBody> {
  final emailCtl = TextEditingController();
  final pwCtl = TextEditingController();
  bool busy = false;
  String? message; // 화면에 보여줄 안내·오류
  bool confirmDelete = false;

  CalendarStore get store => widget.store;
  WxPalette get pal => widget.pal;

  @override
  void dispose() {
    emailCtl.dispose();
    pwCtl.dispose();
    super.dispose();
  }

  /// 버튼 동작을 감싸서: 처리 중 표시 + 오류를 쉬운 문장으로 보여줌
  Future<void> _run(Future<void> Function() job, {String? okMessage}) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await job();
      if (mounted) setState(() => message = okMessage);
    } catch (e) {
      if (mounted) setState(() => message = e is String ? e : syncErrorText(e)); // 문장이 그대로 온 경우는 그대로 보여줌
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool get _inputOk {
    if (emailCtl.text.trim().isEmpty || pwCtl.text.isEmpty) {
      setState(() => message = '이메일과 비밀번호를 입력해 주세요.');
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final sync = store.sync;
    return ListenableBuilder(
      listenable: Listenable.merge([store, ?sync]),
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SYNC', style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: t30)),
            const SizedBox(height: 10),
            if (sync == null || !sync.available) ..._notReady() else if (sync.user == null) ..._signedOut(sync) else ..._signedIn(sync),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!, style: const TextStyle(fontSize: 12, height: 1.6, color: t70)),
            ],
          ],
        ),
      ),
    );
  }

  // ① 서버 연결 전
  List<Widget> _notReady() => const [
        Text('서버가 아직 연결되지 않았어요. 지금은 이 기기 안에만 저장돼요.',
            style: TextStyle(fontSize: 12, height: 1.6, color: t50)),
        SizedBox(height: 8),
        Text('여러 기기에서 같은 일정을 보려면 Firebase 설정이 필요해요. (Firebase_설정_가이드.md 참고)',
            style: TextStyle(fontSize: 11, height: 1.6, color: t30)),
      ];

  // ② 로그인 전
  List<Widget> _signedOut(SyncService sync) => [
        const Text('로그인하면 폰·PC 어디서나 같은 일정을 볼 수 있어요. 지금 이 기기의 일정은 처음 로그인할 때 함께 올라가요.',
            style: TextStyle(fontSize: 12, height: 1.6, color: t50)),
        const SizedBox(height: 14),
        TextField(
          controller: emailCtl,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          style: const TextStyle(fontSize: 13, color: t100),
          decoration: underlineDecoration(pal.accent, hint: 'Email'),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: pwCtl,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          style: const TextStyle(fontSize: 13, color: t100),
          decoration: underlineDecoration(pal.accent, hint: 'Password (6+)'),
          onSubmitted: (_) {
            if (_inputOk) _run(() => sync.signInEmail(emailCtl.text.trim(), pwCtl.text));
          },
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 4, children: [
          TextButton(
            style: textButton(color: pal.accent),
            onPressed: busy
                ? null
                : () {
                    if (_inputOk) _run(() => sync.signInEmail(emailCtl.text.trim(), pwCtl.text));
                  },
            child: const Text('Sign in'),
          ),
          TextButton(
            style: textButton(color: pal.accent),
            onPressed: busy
                ? null
                : () {
                    if (_inputOk) _run(() => sync.signUpEmail(emailCtl.text.trim(), pwCtl.text));
                  },
            child: const Text('Create account'),
          ),
        ]),
        Wrap(spacing: 4, children: [
          TextButton(
            style: textButton(),
            onPressed: busy ? null : () => _run(sync.signInGoogle),
            child: const Text('Continue with Google'),
          ),
          TextButton(
            style: textButton(),
            onPressed: busy
                ? null
                : () {
                    if (emailCtl.text.trim().isEmpty) {
                      setState(() => message = '비밀번호를 다시 만들 이메일을 위에 입력해 주세요.');
                      return;
                    }
                    _run(() => sync.sendResetEmail(emailCtl.text.trim()), okMessage: '비밀번호 재설정 메일을 보냈어요. 메일함(스팸함 포함)을 확인해 주세요.');
                  },
            child: const Text('Forgot password'),
          ),
        ]),
      ];

  // ③ 로그인 후
  List<Widget> _signedIn(SyncService sync) {
    final status = sync.error != null ? sync.error! : (sync.loading ? '서버에서 일정을 불러오는 중이에요…' : '동기화 중이에요. 다른 기기에서 바꾼 일정이 바로 반영돼요.');
    return [
      Text(sync.user?.email ?? '로그인됨', style: const TextStyle(fontSize: 14, color: t100)),
      const SizedBox(height: 6),
      Text(status, style: TextStyle(fontSize: 12, height: 1.6, color: sync.error != null ? const Color(0xFFE09B8F) : t50)),
      const SizedBox(height: 12),
      TextButton(
        style: textButton(color: pal.accent),
        onPressed: busy
            ? null
            : () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: sheetColor(pal),
                    content: const Text('로그아웃하면 이 기기의 일정이 지워져요.\n서버에는 그대로 남아 있어서, 다시 로그인하면 돌아와요.',
                        style: TextStyle(fontSize: 13, height: 1.6, color: t70)),
                    actions: [
                      TextButton(style: textButton(), onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      TextButton(style: textButton(color: pal.accent), onPressed: () => Navigator.pop(c, true), child: const Text('Sign out')),
                    ],
                  ),
                );
                if (ok == true) await _run(store.signOut);
              },
        child: const Text('Sign out'),
      ),
      const Divider(color: hairline, height: 28),
      if (!confirmDelete)
        TextButton(
          style: textButton(),
          onPressed: busy ? null : () => setState(() => confirmDelete = true),
          child: const Text('Delete account'),
        )
      else ...[
        const Text('계정과 서버에 저장된 모든 일정이 영구히 지워지고, 되돌릴 수 없어요.',
            style: TextStyle(fontSize: 12, height: 1.6, color: Color(0xFFE09B8F))),
        Row(children: [
          TextButton(style: textButton(), onPressed: busy ? null : () => setState(() => confirmDelete = false), child: const Text('Cancel')),
          TextButton(
            style: textButton(color: const Color(0xFFE09B8F)),
            onPressed: busy
                ? null
                : () => _run(() async {
                      final err = await store.deleteAccount();
                      if (err != null) throw err;
                    }),
            child: const Text('Delete forever'),
          ),
        ]),
      ],
    ];
  }
}
