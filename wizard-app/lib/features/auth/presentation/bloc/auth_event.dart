import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';

/// Authentication events
abstract class AuthEvent extends BaseEvent {
  const AuthEvent();
}

/// Check authentication status
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// Sign in with email and password
class SignInWithEmailRequested extends AuthEvent {
  final String email;
  final String password;

  const SignInWithEmailRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [email, password];
}

/// Sign up with email and password
class SignUpWithEmailRequested extends AuthEvent {
  final String email;
  final String password;

  const SignUpWithEmailRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [email, password];
}

/// Sign in with Google
class SignInWithGoogleRequested extends AuthEvent {
  const SignInWithGoogleRequested();
}

/// Sign in with Apple
class SignInWithAppleRequested extends AuthEvent {
  const SignInWithAppleRequested();
}

/// Sign out
class SignOutRequested extends AuthEvent {
  const SignOutRequested();
}

/// Reset password
class ResetPasswordRequested extends AuthEvent {
  final String email;

  const ResetPasswordRequested(this.email);

  @override
  List<Object> get props => [email];
}

