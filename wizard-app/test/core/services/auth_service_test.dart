import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// Signed-out Firebase Auth whose anonymous sign-in always fails (offline / emulator down).
class _OfflineAuth implements FirebaseAuth {
  int attempts = 0;

  @override
  User? get currentUser => null;

  @override
  Future<UserCredential> signInAnonymously() async {
    attempts++;
    throw FirebaseAuthException(code: 'network-request-failed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('a failed anonymous sign-in is not retried within the cooldown', () async {
    final auth = _OfflineAuth();
    final service = AuthService(AppLogger(null), auth: auth);

    expect(await service.ensureSignedIn(), isNull);
    expect(await service.ensureSignedIn(), isNull);
    expect(await service.idToken(), isNull);
    expect(await service.ensureUid(), isNull);

    expect(auth.attempts, 1); // one network attempt, then the cooldown answers
  });

  test('concurrent callers share one sign-in attempt', () async {
    final auth = _OfflineAuth();
    final service = AuthService(AppLogger(null), auth: auth);

    await Future.wait([service.ensureSignedIn(), service.ensureSignedIn(), service.idToken()]);

    expect(auth.attempts, 1);
  });
}
