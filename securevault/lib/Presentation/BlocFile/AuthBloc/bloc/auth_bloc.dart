import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:securevault/Business/Entities/AuthEntities.dart';
import 'package:securevault/Business/Usecase/AuthUseCase.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  Timer? _timer;
  final SignInUseCase signInUseCase;
  final SignUpUseCase signUpUseCase;
  final VerifyOtpUseCase verifyOtpUseCase;
  final ResendOtpUseCase resendOtpUseCase;
  final ForgotResendOtpUseCase forgotPassResendOtpUseCase;
  final VerifyResetOtpUseCase verifyResetOtpUseCase;
  final ResetPasswordUseCase resetPasswordUseCase;
  final ForgotPasswordUseCase forgotPasswordUseCase;
  final LogoutUseCase logoutUseCase;
  final ChangePasswordUseCase changePasswordUseCase;
  final UpdateProfileuseCase updateProfileuseCase;
  final GetUserProfileUseCase getUserProfileUseCase;
  final RequestForPasswordChange requestForPasswordChange;
  AuthBloc(
      this.signInUseCase,
      this.signUpUseCase,
      this.verifyOtpUseCase,
      this.resendOtpUseCase,
      this.forgotPassResendOtpUseCase,
      this.verifyResetOtpUseCase,
      this.resetPasswordUseCase,
      this.forgotPasswordUseCase,
      {required this.logoutUseCase,
      required this.changePasswordUseCase,
      required this.updateProfileuseCase,
      required this.getUserProfileUseCase,
      required this.requestForPasswordChange})
      : super(AuthInitial()) {
    on<SignInEvent>(signInEvent);
    on<SignUpEvent>(signUpEvent);
    on<NavigateToSignUpEvent>(navigateToSignUpEvent);
    on<NavigateToLoginEvent>(navigateToLoginEvent);
    on<VerifyOtpEvent>(verifyOtpEvent);
    on<RegisterResendOtpCode>(registerresendOtpCode);
    on<ForgotPassResendOtp>(handleForgotPassResendOtp);
    on<VerifyResetPasswordOtp>(verifyResetPasswordOtp);
    on<NavigateToForgotPasswordEvent>(navigateToForgotPasswordEvent);
    on<ForgotPasswordSendOtp>(forgotPasswordSendOtp);
    on<ResetPassword>(resetPassword);
    on<LogoutEvent>(logOutEvent);
    on<ChangePasswordEvent>(changePasswordEvent);
    on<UpdateProfileEvent>(updateProfileEvent);
    on<GetUserProfileEvent>(getUserProfile);
    on<RequestForPasswordChangeOtpEvent>(requestForPasswordChangeOtpEvent);
  }
  Future<void> signInEvent(SignInEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response =
          await signInUseCase.signInUseCase(event.email, event.password);

      emit(AuthSuccess(user: response));
    } catch (e) {
      print("Error:$e");
      String errorStr = e.toString();
      
      // Handle Security Violations specifically
      if (errorStr.contains("Account temporarily blocked") || 
          errorStr.contains("Suspicious activity detected")) {
        
        String reason = "Security Violation";
        String details = "Your account has been restricted due to unusual activity. Please verify your identity via email.";
        
        if (errorStr.contains("impossible travel")) {
          reason = "Impossible Travel";
          details = "We detected a login attempt from a location that is geographically impossible given your last login time.";
        } else if (errorStr.contains("multiple failed login")) {
          reason = "Brute Force Protection";
          details = "Too many failed login attempts have been detected. Your account is locked for 15 minutes.";
        }
        
        emit(AccountLockedState(reason: reason, details: details));
        return;
      }

      String errorMessage = "Login Failed: Please Check Your Credentials";
      if (errorStr.contains("Invalid credentials")) {
        errorMessage = "Invalid credentials";
      } else if (errorStr.contains("Please verify this device before logging in.")) {
        errorMessage = "New device detected. Please verify this device before logging in by clicking at the link sent to your mail";
      }
      
      emit(AuthError(message: errorMessage));
    }
  }

  Future<void> signUpEvent(SignUpEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await signUpUseCase.signUpUseCase(
        event.image,
        event.email,
        event.name,
        event.password,
        event.password2,
      );
      emit(UserRegistrationSuccessState(userRegistrationEntities: response));
      // emit(AuthSignupSuccess(userRegistrationEntities: response));
    } catch (e) {
      debugPrint("SignUp Error: $e");

      // Handle specific error cases
      if (e.toString().contains("email") &&
          e.toString().contains("already exists")) {
        emit(AuthError(message: "Something went wrong"));
      } else if (e.toString().contains("Passwords do not match")) {
        emit(AuthError(message: "Passwords do not match"));
      } else {
        emit(AuthError(message: "Registration failed. Please try again."));
      }
    }
  }

  Future<void> navigateToSignUpEvent(
      NavigateToSignUpEvent event, Emitter<AuthState> emit) async {
    emit(NavigateToSignUpPage());
  }

  Future<void> navigateToLoginEvent(
      NavigateToLoginEvent event, Emitter<AuthState> emit) async {
    try {
      emit(NavigateToLoginPage());
    } catch (e) {
      emit(AuthError(message: "Error on navigating to the login page"));
    }
  }

  Future<void> verifyOtpEvent(
      VerifyOtpEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response =
          await verifyOtpUseCase.verifyotpUseCase(event.email, event.otp_code);

      print("$response");
      emit(VerifyOtpSuccess(verifyOtpResponseEntities: response));
      emit(NavigateToHomeScreenState());
    } catch (e) {
      emit(VerifyOtpFailure(message: "$e"));
    }
  }

  Future<void> registerresendOtpCode(
      RegisterResendOtpCode event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await resendOtpUseCase.registerResendOtp(event.email);
      emit(ResendOtpSuccessState(resendOtpEntity: response));

      _timer?.cancel();
      for (int seconds = 60; seconds > 0; seconds--) {
        emit(ResendOtpCoolDownState(countdown: seconds));
        await Future.delayed(const Duration(seconds: 1));
      }
      emit(AuthInitial());
    } catch (e) {
      emit(AuthError(message: "$e"));
    }
  }

  Future<void> handleForgotPassResendOtp(
      ForgotPassResendOtp event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response =
          await forgotPassResendOtpUseCase.forgotpassResendOtp(event.email);
      emit(ResendOtpSuccessState(resendOtpEntity: response));
    } catch (e) {
      emit(AuthError(message: "$e"));
    }
  }

  Future<void> verifyResetPasswordOtp(
      VerifyResetPasswordOtp event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await verifyResetOtpUseCase.verifyResetOtpUseCase(
          event.email, event.reset_otp_code);
      emit(ResetVerifyOtpSuccessState(resetOtpVerifyEntity: response));
    } catch (e) {
      emit(VerifyOtpFailure(
          message:
              "THe OTP You Have Entered Is Incorrect,Can You Provide The Correct OTP"));
      throw Exception(ResetVerifyOtpFailure(message: "$e"));
    }
  }

  Future<void> navigateToForgotPasswordEvent(
      NavigateToForgotPasswordEvent event, Emitter<AuthState> emit) async {
    emit(NavigateToForgotPasswordState());
  }

  Future<void> forgotPasswordSendOtp(
      ForgotPasswordSendOtp event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await forgotPasswordUseCase.forgotPassword(event.email);
      emit(ForgotPasswordSendOtpSuccess(forgotPasswordEntity: response));
    } catch (e) {
      emit(AuthError(message: "$e"));
    }
  }

  Future<void> resetPassword(
      ResetPassword event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await resetPasswordUseCase.resetPassword(
          event.email, event.reset_otp_code, event.password, event.password2);
      emit(ResetPasswordSuccessState(resetPasswordEntity: response));
    } catch (e) {
      emit(AuthError(message: "$e"));
    }
  }

  Future<void> logOutEvent(LogoutEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await logoutUseCase.logoutEntity(event.refreshToken);
      emit(NavigateToLoginPage());
    } catch (e) {
      emit(AuthError(message: "$e"));
    }
  }

  Future<void> changePasswordEvent(
      ChangePasswordEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await changePasswordUseCase.changePasswordEntities(
          event.password,
          event.password1,
          event.current_password,
          event.otp_code);
      emit(ChangePasswordState(changePasswordEntitites: response));
      emit(ChangePasswordSucessState());
    } catch (e) {
      emit(AuthError(message: "$e"));
    }
  }

  Future<void> updateProfileEvent(
      UpdateProfileEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await updateProfileuseCase.updateProfileUseCase(
          event.name, event.image);
      emit(UpdateProfileState(updateProfileEntities: response));
    } catch (e) {
      emit(AuthError(message: "$e"));
    }
  }

  Future<void> getUserProfile(
      GetUserProfileEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await getUserProfileUseCase.getUserProfileUseCase();
      emit(GetUserProfileState(getUserProfileEntities: response));
    } catch (e) {
      emit(AuthError(message: "$e"));
    }
  }

  Future<void> requestForPasswordChangeOtpEvent(
      RequestForPasswordChangeOtpEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response =
          await requestForPasswordChange.requestForPasswordChange();
      emit(RequestForPasswordChangeOtpState(
          requestForPasswordChangeEntities: response));
    } catch (e) {
      emit(AuthError(message: "$e"));
    }
  }
}
