class AuthModels {
  final String? email;

  final String? token;
  final String? msg;
  final String? imageurl;

  AuthModels({
    this.email,
    this.token,
    this.msg,
    this.imageurl,
  });

  factory AuthModels.fromJson(Map<String, dynamic> json) {
    return AuthModels(
      email: json['email'] as String?,
      token:
          json['token'] != null ? (json['token']['access'] as String?) : null,
      msg: json['msg'] as String?,
      imageurl: json['imageurl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'token': token != null ? {'access': token} : null,
      'msg': msg,
      'imageurl': imageurl,
    };
  }
}

class UserRegistrationModels {
  final String message;
  final String email;

  UserRegistrationModels({required this.message, required this.email});

  factory UserRegistrationModels.fromJson(Map<String, dynamic> json) {
    return UserRegistrationModels(
      message: json['name'] ?? "default",
      email: json['email'] ?? "default@gmail.com",
    );
  }
}

class VerifyOtpModels {
  final String email;
  final String otp_code;

  VerifyOtpModels({required this.email, required this.otp_code});

  factory VerifyOtpModels.fromJson(Map<String, dynamic> json) {
    return VerifyOtpModels(
        email: json['email'] ?? "", otp_code: json['otp_code'] ?? "");
  }
  Map<String, dynamic> toJson() {
    return {'email': email, 'otp_code': otp_code};
  }
}

class VerifyOtpResponseUserModel {
  final String email;
  final String name;
  final String? image;

  VerifyOtpResponseUserModel({
    required this.email,
    required this.name,
    this.image,
  });

  factory VerifyOtpResponseUserModel.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponseUserModel(
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      image: json['image'] ?? '',
    );
  }
}

class VerifyOtpResponseModel {
  final String token;
  final String message;
  final VerifyOtpResponseUserModel user;

  VerifyOtpResponseModel({
    required this.token,
    required this.message,
    required this.user,
  });

  factory VerifyOtpResponseModel.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponseModel(
      token: json['token']['access'] ?? "",
      message: json['message'] ?? '',
      user: VerifyOtpResponseUserModel.fromJson(json['user'] ?? {}),
    );
  }
}

final class RegisterResendOtp {
  final String? email;

  RegisterResendOtp({required this.email});
  factory RegisterResendOtp.fromJson(Map<String, dynamic> json) {
    return RegisterResendOtp(email: json['email'] ?? "");
  }
  Map<String, dynamic> toJson() {
    return {'email': email};
  }
}

final class ForgotResendOtp {
  final String? email;

  ForgotResendOtp({required this.email});
  factory ForgotResendOtp.fromJson(Map<String, dynamic> json) {
    return ForgotResendOtp(email: json['email'] ?? "");
  }
  Map<String, dynamic> toJson() {
    return {'email': email};
  }
}

class ResetVerifyOtpModels {
  final String? email;
  final String? reset_otp_code;

  ResetVerifyOtpModels({required this.email, required this.reset_otp_code});

  factory ResetVerifyOtpModels.fromJson(Map<String, dynamic> json) {
    return ResetVerifyOtpModels(
        email: json['email'] ?? "",
        reset_otp_code: json['reset_otp_code'] ?? "");
  }
  Map<String, dynamic> toJson() {
    return {'email': email, 'reset_otp_code': reset_otp_code};
  }
}

class ForgotPasswordModel {
  final String? email;

  ForgotPasswordModel({required this.email});

  factory ForgotPasswordModel.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordModel(email: json['email'] ?? "");
  }
}

class ResetPasswordModel {
  final String? email;
  final String? reset_otp_code;
  final String? password;
  final String? password2;

  ResetPasswordModel(
      {required this.email,
      required this.reset_otp_code,
      required this.password,
      required this.password2});

  factory ResetPasswordModel.fromJson(Map<String, dynamic> json) {
    return ResetPasswordModel(
        email: json['email'] ?? "",
        reset_otp_code: json['reset_otp_code'] ?? "",
        password: json['password'] ?? "",
        password2: json['password2'] ?? "");
  }
}

class LogoutModels {
  final String msg;

  LogoutModels({required this.msg});
  factory LogoutModels.fromJson(Map<String, dynamic> json) {
    return LogoutModels(msg: json['msg']);
  }
}

class ChangePasswordModels {
  final String msg;
  final String? token;

  ChangePasswordModels({required this.msg, required this.token});
  factory ChangePasswordModels.fromJson(Map<String, dynamic> json) {
    return ChangePasswordModels(
        msg: json['msg'] ?? "",
        token: json['token'] != null ? (json['token']['access']) : "");
  }
}

class UserProfileUpdateModels {
  final String name;
  final String image;

  UserProfileUpdateModels({required this.name, required this.image});
  factory UserProfileUpdateModels.fromJson(Map<String, dynamic> json) {
    return UserProfileUpdateModels(name: json['name'], image: json['image']);
  }
}

class GetUserProfile {
  final String name;
  final String email;
  final String image;

  GetUserProfile(
      {required this.name, required this.email, required this.image});
  factory GetUserProfile.fromJson(Map<String, dynamic> json) {
    return GetUserProfile(
        name: json['name'], email: json['email'], image: json['image']);
  }
}

class RequestForPasswordChange {
  final String msg;

  RequestForPasswordChange({required this.msg});
  factory RequestForPasswordChange.fromJson(Map<String, dynamic> json) {
    return RequestForPasswordChange(msg: json['msg']);
  }
}
