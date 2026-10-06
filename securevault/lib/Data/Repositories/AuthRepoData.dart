import 'dart:io';
import 'package:securevault/Data/DataSource/authservice.dart';
import 'package:securevault/Data/Models/AuthModels.dart';

//in this data needs to be converted into the models
class AuthRepositoriesData {
  final AuthApiService authApiService = AuthApiService();
  Future<AuthModels> signinRepositories(String email, String password) async {
    try {
      final response = await authApiService.signIn(email, password);
      return AuthModels.fromJson(response);
    } catch (e) {
      throw Exception("Signing in Failed:$e");
    }
  }

  Future<UserRegistrationModels> signupRepositories(File image, String email,
      String name, String password, String password2) async {
    try {
      final response =
          await authApiService.signUp(image, email, name, password, password2);
      return UserRegistrationModels.fromJson(response);
    } catch (e) {
      throw Exception("Signup failed $e");
    }
  }

  Future<LogoutModels> logoutRepositories(String refreshToken) async {
    try {
      final response = await authApiService.logout(refreshToken);
      return LogoutModels.fromJson(response);
    } catch (e) {
      throw Exception("Logout failed: $e");
    }
  }
}

class VerifyOtpRepository {
  final AuthApiService authApiService;

  VerifyOtpRepository({required this.authApiService});
  Future<VerifyOtpResponseModel> verifyOtpRepository(
      String email, String otpCode) async {
    try {
      final response = await authApiService.verfiyOtp(otpCode, email);
      return VerifyOtpResponseModel.fromJson(response);
    } catch (e) {
      throw Exception(e);
    }
  }
}

class ResendOtp {
  final AuthApiService authApiService;
  ResendOtp({required this.authApiService});
  Future<RegisterResendOtp> registerresendOtp(String email) async {
    try {
      final response = await authApiService.resendOtp(email);
      return RegisterResendOtp.fromJson(response);
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<ForgotResendOtp> forgotresendOtp(String email) async {
    try {
      final response = await authApiService.forgotresendOtp(email);
      return ForgotResendOtp.fromJson(response);
    } catch (e) {
      throw Exception("$e");
    }
  }

  Future<ResetVerifyOtpModels> resetverifyOtp(
      String email, String resetOtpCode) async {
    try {
      final response = await authApiService.verifyResetOtp(email, resetOtpCode);
      return ResetVerifyOtpModels.fromJson(response);
    } catch (e) {
      throw Exception("$e");
    }
  }

  Future<ResetPasswordModel> resetPasswordRepository(String email,
      String resetOtpCode, String password, String password2) async {
    try {
      final response = await authApiService.resetPassword(
          email, resetOtpCode, password, password2);
      return ResetPasswordModel.fromJson(response);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<ForgotPasswordModel> forgotPassword(String email) async {
    try {
      final response = await authApiService.forgotPassword(email);
      return ForgotPasswordModel.fromJson(response);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<ChangePasswordModels> changePasswordModels(String password,
      String password1, String current_password, String otp_code) async {
    try {
      final response = await authApiService.changePassword(
          password, password1, current_password, otp_code);
      return ChangePasswordModels.fromJson(response);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<UserProfileUpdateModels> updateUserProfileRepo(
      String name, String image) async {
    try {
      final response = await authApiService.updateUserProfile(name, image);
      return UserProfileUpdateModels.fromJson(response);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<GetUserProfile> getUserProfile() async {
    try {
      final response = await authApiService.getuserProfile();
      return GetUserProfile.fromJson(response);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<RequestForPasswordChange> requestForPasswordChangeRepo() async {
    try {
      final response = await authApiService.requestForChangePassword();
      return RequestForPasswordChange.fromJson(response);
    } catch (e) {
      throw Exception("Error:$e");
    }
  }
}
