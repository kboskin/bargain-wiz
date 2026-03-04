import 'package:firebase_auth/firebase_auth.dart';
import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';

/// Authentication states
abstract class AuthState extends BaseState {
  const AuthState();
}

/// Initial state - checking authentication
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading state - authentication in progress
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Authenticated state - user is signed in
class AuthAuthenticated extends AuthState {
  final User user;

  const AuthAuthenticated(this.user);

  @override
  List<Object> get props => [user];
}

/// Unauthenticated state - user is not signed in
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Authentication error state
class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object> get props => [message];
}

