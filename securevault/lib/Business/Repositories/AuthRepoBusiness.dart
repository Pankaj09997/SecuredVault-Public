import 'dart:io';

import 'package:securevault/Business/Entities/AuthEntities.dart';
import 'package:securevault/Data/DataSource/authservice.dart';
import 'package:securevault/Data/Models/AuthModels.dart';

abstract class AuthRepositoriesBusiness {
  Future<Authentities> signIn(String email, String password);
  Future<UserRegistrationEntities> signUp(
      String email, String password, String password2, String name, File image);
  Future<VerifyOtpResponseEntities> verifyOtp(String email, String otpCode);
  Future<ResendOtpEntity> registerResendOtp(String email);
  Future<ResendOtpEntity> forgotPasswordResendOtp(String email);
  Future<ResetOtpVerifyEntity> resetVerifyOtp(
      String email, String resetOtpCode);
  Future<ResetPasswordEntity> resetPassword(
      String email, String resetOtpCode, String password, String password2);
  Future<ForgotPasswordEntity> forgotPassword(String email);
  Future<LogoutEntity> logout(String refreshToken);
  Future<ChangePasswordEntities> changePassword(String password,
      String password1, String otpCode, String currentPassword);
  Future<UpdateProfileEntities> updateProfile(String name, String image);
  Future<GetUserProfileEntities> getUserRepoBusiness();
  Future<RequestForPasswordChangeEntities> requestForPasswordChangeRepo();
}

class AuthRepositoriesBusinessImpl extends AuthRepositoriesBusiness {
  final AuthApiService _authApiService;

  AuthRepositoriesBusinessImpl({required AuthApiService authApiService})
      : _authApiService = authApiService;
  @override
  Future<Authentities> signIn(String email, String password) async {
    final response = await _authApiService.signIn(email, password);
    final authModel = AuthModels.fromJson(response);
    return Authentities(
        email: authModel.email!,
        token: authModel.token,
        imageurl: authModel.imageurl ?? "",
        msg: authModel.msg!);
  }

  @override
  Future<UserRegistrationEntities> signUp(String email, String password,
      String password2, String name, File image) async {
    try {
      final response =
          await _authApiService.signUp(image, email, name, password, password2);
      if (response['status'] == 'failed') {
        throw Exception(response['message'] ?? 'Registration failed');
      }
      final userModel = UserRegistrationModels.fromJson(response);
      return UserRegistrationEntities(
          email: userModel.email, message: userModel.message);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<VerifyOtpResponseEntities> verifyOtp(
      String email, String otpCode) async {
    try {
      final response = await _authApiService.verfiyOtp(otpCode, email);
      // data converted to models
      final verifyOtp = VerifyOtpResponseModel.fromJson(response);
      //now to entity
      return VerifyOtpResponseEntities(
          message: verifyOtp.message,
          token: verifyOtp.token,
          user: VerifyOtpResponseUserModelEntities(
              email: verifyOtp.user.email,
              name: verifyOtp.user.name,
              image: verifyOtp.user.image));
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Future<ResendOtpEntity> registerResendOtp(String email) async {
    try {
      final response = await _authApiService.resendOtp(email);
      final data = RegisterResendOtp.fromJson(response);
      return ResendOtpEntity(email: data.email!);
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Future<ResendOtpEntity> forgotPasswordResendOtp(String email) async {
    try {
      final response = await _authApiService.forgotresendOtp(email);
      final data = ForgotResendOtp.fromJson(response);
      return ResendOtpEntity(email: data.email!);
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Future<ResetOtpVerifyEntity> resetVerifyOtp(
      String email, String resetOtpCode) async {
    try {
      final response =
          await _authApiService.verifyResetOtp(email, resetOtpCode);
      final data = ResetVerifyOtpModels.fromJson(response);
      return ResetOtpVerifyEntity(
          email: data.email!, reset_otp_code: data.reset_otp_code!);
    } catch (e) {
      throw Exception("$e");
    }
  }

  @override
  Future<ResetPasswordEntity> resetPassword(String email, String resetOtpCode,
      String password, String password2) async {
    try {
      final response = await _authApiService.resetPassword(
          email, resetOtpCode, password, password2);
      final data = ResetPasswordModel.fromJson(response);
      return ResetPasswordEntity(
          email: data.email,
          reset_otp_code: data.reset_otp_code,
          password: data.password,
          password2: data.password2);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  @override
  Future<ForgotPasswordEntity> forgotPassword(String email) async {
    try {
      final response = await _authApiService.forgotPassword(email);
      final data = ForgotPasswordModel.fromJson(response);
      return ForgotPasswordEntity(email: data.email!);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  @override
  Future<LogoutEntity> logout(String refreshToken) async {
    try {
      final response = await _authApiService.logout(refreshToken);
      final data = LogoutModels.fromJson(response);
      return LogoutEntity(msg: data.msg);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  @override
  Future<ChangePasswordEntities> changePassword(String password,
      String password1, String otpCode, String currentPassword) async {
    try {
      final response = await _authApiService.changePassword(
          password, password1, otpCode, currentPassword);
      final modelData = ChangePasswordModels.fromJson(response);
      return ChangePasswordEntities(
          msg: modelData.msg, token: modelData.token ?? "");
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  @override
  Future<UpdateProfileEntities> updateProfile(String name, String image) async {
    try {
      final response = await _authApiService.updateUserProfile(name, image);
      final modelData = UserProfileUpdateModels.fromJson(response);
      return UpdateProfileEntities(
          name: modelData.name, image: modelData.image);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  @override
  Future<GetUserProfileEntities> getUserRepoBusiness() async {
    try {
      final response = await _authApiService.getuserProfile();
      final modelData = GetUserProfile.fromJson(response);
      return GetUserProfileEntities(
          name: modelData.name, email: modelData.email, image: modelData.image);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  @override
  Future<RequestForPasswordChangeEntities>
      requestForPasswordChangeRepo() async {
    try {
      final response = await _authApiService.requestForChangePassword();
      final modelData = RequestForPasswordChange.fromJson(response);
      return RequestForPasswordChangeEntities(msg: modelData.msg);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }
}
