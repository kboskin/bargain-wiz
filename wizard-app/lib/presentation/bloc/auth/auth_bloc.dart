import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:appwizard/presentation/bloc/base_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';

/// Authentication BLoC
class AuthBloc extends BaseBloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final AppLogger _logger;

  AuthBloc({
    required AuthService authService,
    required AppLogger logger,
  })  : _authService = authService,
        _logger = logger,
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<SignInWithEmailRequested>(_onSignInWithEmailRequested);
    on<SignUpWithEmailRequested>(_onSignUpWithEmailRequested);
    on<SignInWithGoogleRequested>(_onSignInWithGoogleRequested);
    on<SignInWithAppleRequested>(_onSignInWithAppleRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<ResetPasswordRequested>(_onResetPasswordRequested);

    // Check auth status on initialization
    add(const AuthCheckRequested());
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      // Wait for Firebase Auth to initialize by listening to the first auth state change
      // This ensures Firebase Auth has restored any cached authentication state
      // The stream emits the current user immediately if already authenticated
      User? user;
      try {
        user = await _authService.authStateChanges
            .first
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        // If timeout or error, fall back to checking currentUser directly
        _logger.w('Auth state stream timeout, using currentUser fallback');
        user = _authService.currentUser;
      }
      
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e, stackTrace) {
      _logger.e('Error checking auth status', e, stackTrace);
      // Final fallback: check currentUser directly
      try {
        final user = _authService.currentUser;
        if (user != null) {
          emit(AuthAuthenticated(user));
        } else {
          emit(const AuthUnauthenticated());
        }
      } catch (fallbackError, fallbackStackTrace) {
        _logger.e('Fallback auth check also failed', fallbackError, fallbackStackTrace);
        emit(AuthError('Failed to check authentication status'));
      }
    }
  }

  Future<void> _onSignInWithEmailRequested(
    SignInWithEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final credential = await _authService.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(credential.user!));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignUpWithEmailRequested(
    SignUpWithEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final credential = await _authService.signUpWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(credential.user!));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignInWithGoogleRequested(
    SignInWithGoogleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final credential = await _authService.signInWithGoogle();
      emit(AuthAuthenticated(credential.user!));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignInWithAppleRequested(
    SignInWithAppleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final credential = await _authService.signInWithApple();
      emit(AuthAuthenticated(credential.user!));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService.signOut();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onResetPasswordRequested(
    ResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _authService.sendPasswordResetEmail(event.email);
      // Don't change state, just show success message
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}

