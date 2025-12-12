import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../utils/app_logger.dart';

/// Authentication service for handling Firebase Auth
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final AppLogger _logger;

  AuthService(this._logger);

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Get auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Signing in with email: $email');
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
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

  /// Sign up with email and password
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Signing up with email: $email');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _logger.i('Successfully signed up with email');
      return credential;
    } on FirebaseAuthException catch (e) {
      _logger.e('Email sign up error', e);
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during email sign up', e, stackTrace);
      rethrow;
    }
  }

  /// Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      _logger.i('Starting Google sign in');
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Google sign in was cancelled');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      _logger.i('Signing in to Firebase with Google credential');
      final userCredential = await _auth.signInWithCredential(credential);
      _logger.i('Successfully signed in with Google');
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      _logger.e('Google sign in error', e);
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during Google sign in', e, stackTrace);
      rethrow;
    }
  }

  /// Sign in with Apple (iOS only)
  Future<UserCredential> signInWithApple() async {
    try {
      if (!Platform.isIOS) {
        throw UnsupportedError('Apple Sign-In is only available on iOS');
      }

      _logger.i('Starting Apple sign in');

      // Request credential for the currently signed in Apple account
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create an `OAuthCredential` from the credential returned by Apple
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase with the Apple credential
      _logger.i('Signing in to Firebase with Apple credential');
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      _logger.i('Successfully signed in with Apple');
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      _logger.e('Apple sign in error', e);
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during Apple sign in', e, stackTrace);
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      _logger.i('Signing out');
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      _logger.i('Successfully signed out');
    } catch (e, stackTrace) {
      _logger.e('Error signing out', e, stackTrace);
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      _logger.i('Sending password reset email to: $email');
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

