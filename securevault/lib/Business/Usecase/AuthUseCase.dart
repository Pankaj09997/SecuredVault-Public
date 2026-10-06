import 'dart:io';

import 'package:http/http.dart';
import 'package:securevault/Business/Entities/AuthEntities.dart';
import 'package:securevault/Business/Repositories/AuthRepoBusiness.dart';
import 'package:securevault/Data/DataSource/AuthService.dart';

class SignInUseCase {
  final AuthRepositoriesBusiness authRepositoriesBusiness;

  SignInUseCase({required this.authRepositoriesBusiness});
  Future<Authentities> signInUseCase(String email, String password) async {
    return await authRepositoriesBusiness.signIn(email, password);
  }
}

class SignUpUseCase {
  final AuthRepositoriesBusiness authRepositoriesBusiness;

  SignUpUseCase({required this.authRepositoriesBusiness});
  Future<UserRegistrationEntities> signUpUseCase(File image, String email,
      String name, String password, String password2) async {
    return await authRepositoriesBusiness.signUp(
        email, password, password2, name, image);
  }
}

class VerifyOtpUseCase {
  final AuthRepositoriesBusiness authRepositoriesBusiness;

  VerifyOtpUseCase({required this.authRepositoriesBusiness});
  Future<VerifyOtpResponseEntities> verifyotpUseCase(
      String email, String otpCode) async {
    final response = await authRepositoriesBusiness.verifyOtp(email, otpCode);
    return response;
  }
}

class ResendOtpUseCase {
  final AuthRepositoriesBusiness authRepositoriesBusiness;

  ResendOtpUseCase({required this.authRepositoriesBusiness});

  Future<ResendOtpEntity> registerResendOtp(String email) async {
    return await authRepositoriesBusiness.registerResendOtp(email);
  }
}

class ForgotResendOtpUseCase {
  final AuthRepositoriesBusiness authRepositoriesBusiness;

  ForgotResendOtpUseCase({required this.authRepositoriesBusiness});

  Future<ResendOtpEntity> forgotpassResendOtp(String email) async {
    return await authRepositoriesBusiness.forgotPasswordResendOtp(email);
  }
}

class VerifyResetOtpUseCase {
  final AuthRepositoriesBusiness authRepositoriesBusiness;

  VerifyResetOtpUseCase({required this.authRepositoriesBusiness});
  Future<ResetOtpVerifyEntity> verifyResetOtpUseCase(
      String email, String resetOtpCode) async {
    return await authRepositoriesBusiness.resetVerifyOtp(email, resetOtpCode);
  }
}

class ForgotPasswordUseCase {
  final AuthRepositoriesBusiness authRepositoriesBusiness;
  ForgotPasswordUseCase({required this.authRepositoriesBusiness});
  Future<ForgotPasswordEntity> forgotPassword(String email) async {
    return await authRepositoriesBusiness.forgotPassword(email);
  }
}

class ResetPasswordUseCase {
  final AuthRepositoriesBusiness authRepositoriesBusiness;

  ResetPasswordUseCase({required this.authRepositoriesBusiness});
  Future<ResetPasswordEntity> resetPassword(String email, String resetOtpCode,
      String password, String password2) async {
    return authRepositoriesBusiness.resetPassword(
        email, resetOtpCode, password, password2);
  }
}

class LogoutUseCase {
  final AuthRepositoriesBusiness authRepositoriesBusiness;

  LogoutUseCase({required this.authRepositoriesBusiness});
  Future<LogoutEntity> logoutEntity(String refreshToken) async {
    final response = await authRepositoriesBusiness.logout(refreshToken);

    return response;
  }
}

class ChangePasswordUseCase {
  final AuthRepositoriesBusiness authRepositoriesBusiness;

  ChangePasswordUseCase({required this.authRepositoriesBusiness});
  Future<ChangePasswordEntities> changePasswordEntities(String password,
      String password1, String current_password, String otp_code) async {
    return await authRepositoriesBusiness.changePassword(
        password, password1, current_password, otp_code);
  }
}

class UpdateProfileuseCase {
  final AuthRepositoriesBusiness authRepositoriesBusiness;

  UpdateProfileuseCase({required this.authRepositoriesBusiness});
  Future<UpdateProfileEntities> updateProfileUseCase(
      String name, String image) async {
    return await authRepositoriesBusiness.updateProfile(name, image);
  }
}

class GetUserProfileUseCase {
  final AuthRepositoriesBusiness authRepositoriesBusiness;

  GetUserProfileUseCase({required this.authRepositoriesBusiness});
  Future<GetUserProfileEntities> getUserProfileUseCase() async {
    return await authRepositoriesBusiness.getUserRepoBusiness();
  }
}

class RequestForPasswordChange {
  final AuthRepositoriesBusiness authRepositoriesBusiness;

  RequestForPasswordChange({required this.authRepositoriesBusiness});
  Future<RequestForPasswordChangeEntities> requestForPasswordChange() async {
    return await authRepositoriesBusiness.requestForPasswordChangeRepo();
  }
}
