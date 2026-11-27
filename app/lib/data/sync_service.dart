// 로그인과 서버(Firebase) 연결을 맡는 곳
// - 로그인: 이메일·비밀번호, 구글(웹 기준)
// - 서버 저장소(Firestore)의 위치: users/{내 계정 번호}/events · todos · cats
//   (보안 규칙으로 '내 계정 번호'와 같은 사람만 읽고 쓸 수 있게 해요 → firestore.rules)
// Firebase를 아직 연결하지 않았으면 available 이 false 이고, 앱은 기기 안 저장으로만 동작해요.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class SyncService extends ChangeNotifier {
  SyncService._(this.available);

  /// Firebase가 연결·준비되었는지 (false 면 기기 안 저장만 사용)
  final bool available;

  /// 지금 로그인한 사람 (없으면 null)
  User? user;

  /// 서버에서 일정을 처음 불러오는 중인지
  bool loading = false;

  /// 서버 연결 중 생긴 문제 (없으면 null)
  String? error;

  /// 로그인 상태가 바뀌면 불리는 함수 — 저장소(CalendarStore)가 이걸 받아서 서버 연결을 시작·중단해요
  void Function(User? user)? onUserChanged;

  StreamSubscription<User?>? _authSub;

  /// [skipFirebase] 가 true 면 Firebase 를 켜지 않고 기기 안 저장으로만 시작해요 (자동 테스트용)
  static Future<SyncService> create({bool skipFirebase = false}) async {
    if (skipFirebase) return SyncService._(false);
    // 설정이 없는 플랫폼(예: 아직 연결 안 한 iOS)은 currentPlatform 이 오류를 던지고, 아래 catch 가 기기 안 저장으로 돌려요
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      try {
        // 인터넷이 끊겨도 일정을 보고 고칠 수 있게 기기 안에도 사본을 둬요 (웹은 기본이 꺼져 있어서 켜 줌)
        FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
      } catch (_) {}
      return SyncService._(true);
    } catch (e) {
      debugPrint('Firebase 시작 실패: $e');
      return SyncService._(false);
    }
  }

  /// 로그인 상태 지켜보기 시작 (저장소가 onUserChanged 를 연결한 뒤에 부르세요)
  void start() {
    if (!available) return;
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      user = u;
      notifyListeners();
      onUserChanged?.call(u);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void setLoading(bool v, {String? err}) {
    loading = v;
    error = err;
    notifyListeners();
  }

  /// 내 데이터 위치: users/{uid}/{name}
  CollectionReference<Map<String, dynamic>> col(String name, String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection(name);

  // ===== 로그인 =====
  Future<void> signInEmail(String email, String password) =>
      FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signUpEmail(String email, String password) =>
      FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> sendResetEmail(String email) => FirebaseAuth.instance.sendPasswordResetEmail(email: email);

  Future<void> signInGoogle() async {
    final provider = GoogleAuthProvider();
    if (kIsWeb) {
      await FirebaseAuth.instance.signInWithPopup(provider);
    } else {
      await FirebaseAuth.instance.signInWithProvider(provider);
    }
  }

  Future<void> signOut() => FirebaseAuth.instance.signOut();

  /// 계정 삭제 (서버의 일정 데이터는 저장소에서 먼저 지워요)
  Future<void> deleteAuthUser() async => FirebaseAuth.instance.currentUser?.delete();
}

/// 오류를 쉬운 한국어로 바꾸기
String syncErrorText(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return '이메일 형식이 올바르지 않아요.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 맞지 않아요.';
      case 'email-already-in-use':
        return '이미 가입된 이메일이에요. Sign in을 눌러 보세요.';
      case 'weak-password':
        return '비밀번호는 6자 이상으로 해 주세요.';
      case 'too-many-requests':
        return '시도가 너무 많아요. 잠시 뒤에 다시 해 주세요.';
      case 'network-request-failed':
        return '인터넷 연결을 확인해 주세요.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'web-context-canceled':
        return '로그인 창이 닫혔어요.';
      case 'operation-not-allowed':
        return 'Firebase 콘솔에서 이 로그인 방식을 아직 켜지 않았어요.';
      case 'requires-recent-login':
        return '보안을 위해 다시 로그인한 뒤에 시도해 주세요.';
    }
    return '로그인 중 문제가 생겼어요. (${e.code})';
  }
  if (e is FirebaseException) {
    if (e.code == 'permission-denied') return '서버에 접근할 권한이 없어요. 보안 규칙(firestore.rules)을 확인해 주세요.';
    if (e.code == 'unavailable') return '서버에 연결할 수 없어요. 인터넷 연결을 확인해 주세요.';
    return '서버 오류가 생겼어요. (${e.code})';
  }
  return '알 수 없는 문제가 생겼어요.';
}
