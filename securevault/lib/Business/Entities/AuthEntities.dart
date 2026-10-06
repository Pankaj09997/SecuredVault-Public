import 'dart:io';

class Authentities {
  final String? email;
  final String? name;
  final String? token;
  final String? imageurl;
  final String? msg;

  Authentities({
    this.email,
    this.name,
    this.token,
    this.imageurl,
    this.msg,
  });

  @override
  String toString() => 'Authentities(email:$email)';
}

class UserRegistrationEntities {
  final String message;
  final String email;

  UserRegistrationEntities({required this.message, required this.email});

  @override
  String toString() => 'UserRegistrationEntities( )';
}

class VerifyOtpResponseUserModelEntities {
  final String email;
  final String name;
  final String? image;

  VerifyOtpResponseUserModelEntities(
      {required this.email, required this.name, required this.image});
}

class VerifyOtpResponseEntities {
  final String token;
  final String message;
  final VerifyOtpResponseUserModelEntities user;

  VerifyOtpResponseEntities(
      {required this.token, required this.message, required this.user});
}

class VerifyOtpEntity {
  final String email;
  final String otp_code;

  VerifyOtpEntity({required this.email, required this.otp_code});
}

class ResendOtpEntity {
  final String email;

  ResendOtpEntity({required this.email});
}

class ResetOtpVerifyEntity {
  final String email;
  final String reset_otp_code;

  ResetOtpVerifyEntity({required this.email, required this.reset_otp_code});
}

class ForgotPasswordEntity {
  final String email;

  ForgotPasswordEntity({required this.email});
}

class ResetPasswordEntity {
  final String? email;
  final String? reset_otp_code;
  final String? password;
  final String? password2;

  ResetPasswordEntity(
      {required this.email,
      required this.reset_otp_code,
      required this.password,
      required this.password2});
}

class LogoutEntity {
  final String msg;

  LogoutEntity({required this.msg});
}

class ChangePasswordEntities {
  final String msg;
  final String token;

  ChangePasswordEntities({required this.msg, required this.token});
}

class UpdateProfileEntities {
  final String name;
  final String image;

  UpdateProfileEntities({required this.name, required this.image});
}

class GetUserProfileEntities {
  final String name;
  final String email;
  final String image;

  GetUserProfileEntities(
      {required this.name, required this.email, required this.image});
}

class RequestForPasswordChangeEntities {
  final String msg;

  RequestForPasswordChangeEntities({required this.msg});
}
