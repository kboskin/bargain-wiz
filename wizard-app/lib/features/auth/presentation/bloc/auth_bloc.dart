import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';
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

    // The current user is read synchronously (no screen waits on auth); the subscription
    // keeps the state in sync and the anonymous sign-in runs in the background.
    add(const AuthCheckRequested());
    _userChanges = _authService.userChanges.listen((_) => add(const AuthCheckRequested()));
    unawaited(_authService.ensureSignedIn());
  }

  StreamSubscription<User?>? _userChanges;

  /// Anonymous users (every install has one) count as "no account": the drawer, the
  /// profile card and the router treat [AuthAuthenticated] as "signed in with a provider".
  static AuthState stateFor(User? user) =>
      AuthService.isAccount(user) ? AuthAuthenticated(user!) : const AuthUnauthenticated();

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(stateFor(_authService.currentUser));
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
    } catch (e, stackTrace) {
      _logger.e('Email sign in failed', e, stackTrace);
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
    } catch (e, stackTrace) {
      _logger.e('Email sign up failed', e, stackTrace);
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
    } catch (e, stackTrace) {
      _logger.e('Google sign in failed', e, stackTrace);
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
    } catch (e, stackTrace) {
      _logger.e('Apple sign in failed', e, stackTrace);
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
    } catch (e, stackTrace) {
      _logger.e('Sign out failed', e, stackTrace);
      emit(AuthError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _userChanges?.cancel();
    return super.close();
  }

  Future<void> _onResetPasswordRequested(
    ResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _authService.sendPasswordResetEmail(event.email);
      // Don't change state, just show success message
    } catch (e, stackTrace) {
      _logger.e('Password reset failed', e, stackTrace);
      emit(AuthError(e.toString()));
    }
  }
}

