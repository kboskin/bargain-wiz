import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../utils/app_logger.dart';

/// Firebase Auth for an app that never forces sign-in (see CONVERSATIONS.md §2).
///
/// Every install is signed in **anonymously** on first use, so there is always a uid for the
/// backend and for Firestore rules. Signing in with Google / Apple / email *links* that
/// credential to the anonymous user, keeping the uid and everything stored under it. When the
/// credential already belongs to another account we switch to that account instead (the
/// anonymous history stays behind until the server-side merge ships). Signing out signs in
/// anonymously again right away, so the device is never without a uid.
class AuthService {
  AuthService(this._logger, {FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final AppLogger _logger;

  Future<User?>? _signingIn;
  DateTime? _retryNotBefore;

  /// After a failed anonymous sign-in (offline, emulator down), callers get null without a
  /// new network attempt for this long. Every backend call asks for a token, so without a
  /// cooldown a dead network turns into a retry storm.
  static const Duration retryCooldown = Duration(seconds: 5);

  /// The anonymous uid we left behind when switching to an existing account (input for the
  /// future `POST /me/merge`).
  String? previousAnonymousUid;

  /// Current Firebase user, anonymous or not.
  User? get currentUser => _auth.currentUser;

  /// Fires on sign-in / sign-out (a link keeps the uid, so it is silent here).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Also fires when the user is linked to a provider or its profile changes.
  Stream<User?> get userChanges => _auth.userChanges();

  /// The uid over time: anonymous → same uid after linking → a new one after sign-out.
  Stream<String?> get uidChanges => userChanges.map((user) => user?.uid).distinct();

  /// A Firebase user exists (anonymous counts).
  bool get isSignedIn => _auth.currentUser != null;

  /// Signed in with a real provider, not anonymously.
  bool get hasAccount => isAccount(_auth.currentUser);

  static bool isAccount(User? user) => user != null && !user.isAnonymous;

  /// Signs in anonymously when there is no user yet. Cheap to call often; concurrent calls
  /// share one request. Returns null when Firebase is unreachable (offline first launch):
  /// callers carry on without a uid and try again on the next call.
  Future<User?> ensureSignedIn() {
    final current = _auth.currentUser;
    if (current != null) return Future.value(current);
    final notBefore = _retryNotBefore;
    if (notBefore != null && DateTime.now().isBefore(notBefore)) return Future.value(null);
    return _signingIn ??= _signInAnonymously().whenComplete(() => _signingIn = null);
  }

  /// The uid, signing in anonymously first when needed.
  Future<String?> ensureUid() async => (await ensureSignedIn())?.uid;

  /// ID token for backend calls, signing in anonymously first when needed.
  Future<String?> idToken({bool forceRefresh = false}) async {
    final user = await ensureSignedIn();
    if (user == null) return null;
    try {
      return await user.getIdToken(forceRefresh);
    } on Object catch (e) {
      _logger.w('Could not get an ID token: $e');
      return null;
    }
  }

  Future<User?> _signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      _logger.i('Signed in anonymously (${credential.user?.uid})');
      return credential.user;
    } on Object catch (e) {
      _retryNotBefore = DateTime.now().add(retryCooldown);
      _logger.w('Anonymous sign-in failed (offline?), next attempt in ${retryCooldown.inSeconds}s: $e');
      return null;
    }
  }

  /// Sign in to an existing email account. An existing account always has its own uid, so
  /// this switches accounts rather than linking.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Signing in with email');
      _rememberAnonymous();
      final credential = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      _logger.i('Successfully signed in with email');
      return credential;
    } on FirebaseAuthException catch (e) {
      _logger.e('Email sign in error', e);
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during email sign in', e, stackTrace);
      rethrow;
    }
  }

  /// Create an email account: links the credential to the anonymous user so the uid (and
  /// the deals under it) survive.
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Signing up with email');
      final credential = EmailAuthProvider.credential(email: email.trim(), password: password);
      final anonymous = _auth.currentUser;
      final UserCredential result;
      if (anonymous != null && anonymous.isAnonymous) {
        result = await anonymous.linkWithCredential(credential);
        await _afterLink(result);
      } else {
        result = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      }
      _logger.i('Successfully signed up with email');
      return result;
    } on FirebaseAuthException catch (e) {
      _logger.e('Email sign up error', e);
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during email sign up', e, stackTrace);
      rethrow;
    }
  }

  /// Sign in with Google: link to the anonymous user, or switch to the existing account.
  Future<UserCredential> signInWithGoogle() async {
    try {
      _logger.i('Starting Google sign in');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign in was cancelled');
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _linkOrSignIn(credential);
      _logger.i('Successfully signed in with Google');
      return result;
    } on FirebaseAuthException catch (e) {
      _logger.e('Google sign in error', e);
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during Google sign in', e, stackTrace);
      rethrow;
    }
  }

  /// Sign in with Apple (iOS only): link to the anonymous user, or switch to the existing account.
  Future<UserCredential> signInWithApple() async {
    try {
      if (!Platform.isIOS) {
        throw UnsupportedError('Apple Sign-In is only available on iOS');
      }
      _logger.i('Starting Apple sign in');
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      final result = await _linkOrSignIn(oauthCredential);
      _logger.i('Successfully signed in with Apple');
      return result;
    } on FirebaseAuthException catch (e) {
      _logger.e('Apple sign in error', e);
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during Apple sign in', e, stackTrace);
      rethrow;
    }
  }

  /// Link [credential] to the anonymous user (uid unchanged). When the credential already has
  /// an account, sign in to it instead and remember the anonymous uid for a later merge.
  Future<UserCredential> _linkOrSignIn(AuthCredential credential) async {
    var toUse = credential;
    final anonymous = _auth.currentUser;
    if (anonymous != null && anonymous.isAnonymous) {
      try {
        final result = await anonymous.linkWithCredential(toUse);
        await _afterLink(result);
        _logger.i('Linked ${toUse.providerId} to the anonymous user');
        return result;
      } on FirebaseAuthException catch (e) {
        if (!_isConflict(e.code)) rethrow;
        _logger.i('Credential already has an account (${e.code}); switching to it');
        toUse = e.credential ?? toUse;
      }
    }
    _rememberAnonymous();
    return _auth.signInWithCredential(toUse);
  }

  static bool _isConflict(String code) =>
      code == 'credential-already-in-use' ||
      code == 'email-already-in-use' ||
      code == 'account-exists-with-different-credential' ||
      code == 'provider-already-linked';

  void _rememberAnonymous() {
    final user = _auth.currentUser;
    if (user != null && user.isAnonymous) previousAnonymousUid = user.uid;
  }

  /// Refresh the ID token so the backend sees the new provider claim right away.
  Future<void> _afterLink(UserCredential result) async {
    try {
      await result.user?.getIdToken(true);
    } on Object catch (e) {
      _logger.w('Token refresh after link failed: $e');
    }
  }

  /// Sign out of the account and continue anonymously with a fresh, empty uid. The account's
  /// deals stay on the server.
  Future<void> signOut() async {
    try {
      _logger.i('Signing out');
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      await ensureSignedIn();
      _logger.i('Successfully signed out');
    } catch (e, stackTrace) {
      _logger.e('Error signing out', e, stackTrace);
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      _logger.i('Sending password reset email');
      await _auth.sendPasswordResetEmail(email: email.trim());
      _logger.i('Password reset email sent');
    } on FirebaseAuthException catch (e) {
      _logger.e('Password reset error', e);
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      _logger.e('Unexpected error sending password reset', e, stackTrace);
      rethrow;
    }
  }

  /// Handle Firebase Auth exceptions and return user-friendly messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'credential-already-in-use':
        return 'This account is already linked to another user.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'invalid-email':
        return 'Invalid email address. Please check and try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return e.message ?? 'An error occurred during authentication.';
    }
  }

  /// Check if Apple Sign-In is available
  bool get isAppleSignInAvailable => Platform.isIOS;
}
