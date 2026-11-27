// Firebase 연결 정보 (임시 자리)
// 아직 Firebase 프로젝트를 연결하지 않은 상태예요. 이 상태에서는 앱이 기기 안 저장으로만 동작해요.
// 연결하려면 app 폴더에서 `flutterfire configure` 를 실행하세요 (Firebase_설정_가이드.md 참고).
// 실행하면 이 파일이 진짜 값으로 자동으로 바뀌어요.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  /// 연결 전에는 이 값이 들어 있어요. sync_service.dart 가 이 값을 보고 '아직 설정 안 됨'을 알아봐요.
  static const notConfiguredKey = 'NOT_CONFIGURED';

  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: notConfiguredKey,
    appId: 'not-configured',
    messagingSenderId: 'not-configured',
    projectId: 'not-configured',
  );
}
