part of 'auth_bloc.dart';

@immutable
sealed class AuthState {}

final class AuthInitial extends AuthState {}

final class AuthLoading extends AuthState {}

final class AuthSuccess extends AuthState {
  final Authentities user;

  AuthSuccess({required this.user});
}

final class AuthError extends AuthState {
  final String message;

  AuthError({required this.message});
}

final class AuthLoadingState extends AuthState {}

final class NavigateToSignUpPage extends AuthState {}

final class NavigateToLoginPage extends AuthState {}

final class VerifyOtpState extends AuthState {}

final class VerifyOtpSuccess extends AuthState {
  final VerifyOtpResponseEntities verifyOtpResponseEntities;

  VerifyOtpSuccess({required this.verifyOtpResponseEntities});
}

final class VerifyOtpFailure extends AuthState {
  final String message;

  VerifyOtpFailure({required this.message});
}

final class ResendOtpSuccessState extends AuthState {
  final ResendOtpEntity resendOtpEntity;

  ResendOtpSuccessState({required this.resendOtpEntity});
}

final class ResetVerifyOtpFailure extends AuthState {
  final String message;

  ResetVerifyOtpFailure({required this.message});
}

final class ResetVerifyOtpSuccessState extends AuthState {
  final ResetOtpVerifyEntity resetOtpVerifyEntity;

  ResetVerifyOtpSuccessState({required this.resetOtpVerifyEntity});
}

final class NavigateToHomeScreenState extends AuthState {}

final class NavigateToForgotPasswordState extends AuthState {}

final class ForgotPasswordSendOtpSuccess extends AuthState {
  final ForgotPasswordEntity forgotPasswordEntity;

  ForgotPasswordSendOtpSuccess({required this.forgotPasswordEntity});
}

final class ResetPasswordSuccessState extends AuthState {
  final ResetPasswordEntity resetPasswordEntity;

  ResetPasswordSuccessState({required this.resetPasswordEntity});
}

final class UserRegistrationSuccessState extends AuthState {
  final UserRegistrationEntities userRegistrationEntities;

  UserRegistrationSuccessState({required this.userRegistrationEntities});
}

final class NavigateToVerifyOtpPage extends AuthState {}

final class ResendOtpCoolDownState extends AuthState {
  final int countdown;

  ResendOtpCoolDownState({required this.countdown});
}

final class LogoutState extends AuthState {
  final LogoutEntity logoutEntity;

  LogoutState({required this.logoutEntity});
}

final class ChangePasswordState extends AuthState {
  final ChangePasswordEntities changePasswordEntitites;

  ChangePasswordState({required this.changePasswordEntitites});
}

final class ChangePasswordSucessState extends AuthState {}

final class UpdateProfileState extends AuthState {
  final UpdateProfileEntities updateProfileEntities;

  UpdateProfileState({required this.updateProfileEntities});
}

final class GetUserProfileState extends AuthState {
  final GetUserProfileEntities getUserProfileEntities;

  GetUserProfileState({required this.getUserProfileEntities});
}

final class RequestForPasswordChangeOtpState extends AuthState {
  final RequestForPasswordChangeEntities requestForPasswordChangeEntities;

  RequestForPasswordChangeOtpState(
      {required this.requestForPasswordChangeEntities});
}

final class AuthSignupSuccess extends AuthState {
  final UserRegistrationEntities userRegistrationEntities;

  AuthSignupSuccess({required this.userRegistrationEntities});
}

final class AccountLockedState extends AuthState {
  final String reason;
  final String details;

  AccountLockedState({required this.reason, required this.details});
}
