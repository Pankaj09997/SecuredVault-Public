part of 'auth_bloc.dart';

@immutable
sealed class AuthEvent {}

final class SignInEvent extends AuthEvent {
  final String email;
  final String password;

  SignInEvent({required this.email, required this.password});
}

final class NavigateToForgotPasswordEvent extends AuthEvent {}

final class SignUpEvent extends AuthEvent {
  final File image;
  final String email;
  final String name;
  final String password;
  final String password2;

  SignUpEvent(
      {required this.image,
      required this.email,
      required this.name,
      required this.password,
      required this.password2});
}

final class NavigateToSignUpEvent extends AuthEvent {}

final class NavigateToLoginEvent extends AuthEvent {}

final class VerifyOtpEvent extends AuthEvent {
  final String email;
  final String otp_code;

  VerifyOtpEvent({required this.email, required this.otp_code});
}

final class RegisterResendOtpCode extends AuthEvent {
  final String email;
  final int countdown;
  final bool hasSentOtp;

  RegisterResendOtpCode(this.countdown, this.hasSentOtp, {required this.email});
}

final class ForgotPassResendOtp extends AuthEvent {
  final String email;

  ForgotPassResendOtp({required this.email});
}

final class VerifyResetPasswordOtp extends AuthEvent {
  final String email;
  final String reset_otp_code;

  VerifyResetPasswordOtp({required this.email, required this.reset_otp_code});
}

final class NavigateToHomePage extends AuthEvent {}

final class ForgotPasswordSendOtp extends AuthEvent {
  final String email;

  ForgotPasswordSendOtp({required this.email});
}

final class ResetPassword extends AuthEvent {
  final String email;
  final String reset_otp_code;
  final String password;
  final String password2;

  ResetPassword(
      {required this.email,
      required this.reset_otp_code,
      required this.password,
      required this.password2});
}

final class NavigateToVerifyOtpPageEvent extends AuthEvent {
  final String email;

  NavigateToVerifyOtpPageEvent({required this.email});
}

final class ResendOtpCodeCoolDown extends AuthEvent {}

final class LogoutEvent extends AuthEvent {
  final String refreshToken;

  LogoutEvent({required this.refreshToken});
}

final class ChangePasswordEvent extends AuthEvent {
  final String password;
  final String password1;
  final String otp_code;
  final String current_password;

  ChangePasswordEvent(
      {required this.password,
      required this.password1,
      required this.otp_code,
      required this.current_password});
}

final class ChangePasswordSuccessEvent extends AuthEvent {
  final ChangePasswordEntities changePasswordEntities;

  ChangePasswordSuccessEvent({required this.changePasswordEntities});
}

final class UpdateProfileEvent extends AuthEvent {
  final String name;
  final String image;

  UpdateProfileEvent({required this.name, required this.image});
}

final class GetUserProfileEvent extends AuthEvent {}

final class RequestForPasswordChangeOtpEvent extends AuthEvent {}
