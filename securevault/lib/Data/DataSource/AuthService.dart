import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:securevault/Data/DataSource/BaseUrl.dart';
import 'package:securevault/Data/DataSource/ThrottlingInterceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class AuthApiService {
  final String baseUrl = Baseurl.baseUrl;
  late final Dio dio;
  String? _token;
  String? accessToken;
  String? refreshToken;

  AuthApiService() {
    dio = Dio();
    dio.interceptors
        .add(ThrottlingInterceptor(minIntervalMs: 1000)); // 1s throttle
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    accessToken = prefs.getString('access_token');
    refreshToken = prefs.getString('refresh_token');
  }

  Future<void> _saveToken(String token, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('jwt_token', token);
    await prefs.setString('refresh_token', refreshToken);
  }

  Future<void> _saveUserData(String email, String? imageUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final image = await prefs.setString("image", imageUrl ?? "");
    final emailSave = await prefs.setString("email", email);
  }

  Future<void> _loadUserData(String emailKey, String imageKey) async {
    final prefs = await SharedPreferences.getInstance();
    final loadEmail = prefs.getString(emailKey);
    final loadKey = prefs.getString(imageKey);
  }

  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      final response = await dio.post(
        "$baseUrl/login/",
        data: {"email": email, "password": password},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        print("Sign in credentials $data");

        _token = data['token']['access'];
        refreshToken = data['token']['refresh'];
        final emailData = data['email'];
        final imageData = data['imageurl'] ?? "";

        const secureStorage = FlutterSecureStorage();
        await secureStorage.write(key: 'refresh', value: refreshToken);
        _saveToken(_token!, refreshToken!);
        _saveUserData(emailData, imageData ?? "");
        return data;
      } else {
        throw Exception("Failed to sign in: ${response.statusCode}");
      }
    } on DioException catch (e) {
      final errorData = e.response?.data;
      print("Error:$errorData");
      if (errorData is Map && errorData.containsKey('msg')) {
        throw Exception(errorData['msg']);
      }
      if (e.response?.statusCode == 429) {
        throw Exception("Too many requests. Please slow down.");
      }
      throw Exception(errorData ?? "Network Error");
    }
  }

  Future<Map<String, dynamic>> signUp(File? image, String email, String name,
      String password, String password2) async {
    var request = http.MultipartRequest("POST", Uri.parse("$baseUrl/signup/"));
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.fields['name'] = name;
    request.fields['password2'] = password2;

    if (image != null) {
      request.files.add(http.MultipartFile.fromBytes(
          'image', await image.readAsBytes(),
          filename: image.path.split('/').last));
    }

    try {
      var response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return jsonDecode(responseBody);
      } else {
        final errorData = jsonDecode(responseBody);
        if (errorData.containsKey('errors') &&
            errorData['errors'].containsKey('email')) {
          throw Exception(
              errorData['errors']['email'][0]); // Get the first error message
        } else if (errorData.containsKey('errors') &&
            errorData['errors'].containsKey('password')) {
          throw Exception(errorData['errors']['password'][0]);
        } else {
          throw Exception("Hello $responseBody");
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verfiyOtp(String otpCode, String email) async {
    final response = await http.post(Uri.parse("$baseUrl/verify-otp/"),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode({"email": email, "otp_code": otpCode}));
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      _token = data['token']['access'];
      refreshToken = data['token']['refresh'];
      print("The Response data is:$data");
      _saveToken(_token!, refreshToken!);
      return data;
    } else {
      final errorResponse = jsonDecode(response.body);
      print("$errorResponse");
      throw Exception(errorResponse);
    }
  }

  Future<Map<String, dynamic>> resendOtp(String email) async {
    final response = await http.post(
      Uri.parse("$baseUrl/register-resend-otp/"),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8'
      },
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      final errorData = jsonDecode(response.body);
      print("$errorData");
      return errorData;
    }
  }

  Future<Map<String, dynamic>> forgotresendOtp(String email) async {
    final response = await http.post(
      Uri.parse("$baseUrl/forgot-resend-otp/"),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8'
      },
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      final errorData = jsonDecode(response.body);
      print("$errorData");
      return errorData;
    }
  }

  // reset-verify-otp/
  Future<Map<String, dynamic>> verifyResetOtp(
      String email, String resetOtpCode) async {
    final response = await http.post(Uri.parse("$baseUrl/reset-verify-otp/"),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode({"email": email, "reset_otp_code": resetOtpCode}));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      final errorData = jsonDecode(response.body);
      print("$errorData");
      throw Exception("$errorData");
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await http.post(Uri.parse("$baseUrl/forgot-password/"),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode({"email": email}));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      final errorData = jsonDecode(response.body);
      print("$errorData");
      return errorData;
    }
  }

  Future<Map<String, dynamic>> resetPassword(String email, String resetOtpCode,
      String password, String password2) async {
    final response = await http.post(Uri.parse("$baseUrl/reset-password/"),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode({
          'email': email,
          'reset_otp_code': resetOtpCode,
          'password': password,
          'password2': password2
        }));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      final errorData = jsonDecode(response.body);
      return errorData;
    }
  }

  Future<Map<String, dynamic>> logout(String refreshToken) async {
    try {
      await _loadToken();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('emailKey');
      await prefs.remove('image');
      await prefs.remove('email');

      final response = await http.post(
        Uri.parse("$baseUrl/logout/"),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          "refresh": refreshToken,
        }),
      );

      if (response.statusCode == 205 || response.statusCode == 200) {
        Map<String, dynamic> data = {};
        if (response.body.isNotEmpty) {
          data = jsonDecode(response.body);
        } else {
          data = {"msg": "Logout Successful"};
        }
        print("Data is :$data");

        return data;
      } else {
        final errorData = jsonDecode(response.body);
        print("Error:$errorData");
        // Return success locally anyway to ensure navigation to login page
        return {"msg": "Logout Successful"};
      }
    } catch (e) {
      print("Logout Exception: $e");
      // If network fails, still allow local logout
      return {"msg": "Logout Successful"};
    }
  }

  Future<Map<String, dynamic>> changePassword(String password, String password1,
      String currentPassword, String otpCode) async {
    await _loadToken();
    if (_token == null) {
      print("Final Token:$_token");
      throw Exception("User is not authorized");
    }
    try {
      final response = await http.post(Uri.parse("$baseUrl/changepassword/"),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
            if (_token != null) 'Authorization': 'Bearer $_token',
          },
          body: jsonEncode({
            "current_password": currentPassword,
            "password": password,
            "password2": password1,
            "otp_code": otpCode
          }));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return data;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception("Error:$errorData");
      }
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<Map<String, dynamic>> requestForChangePassword() async {
    await _loadToken();
    if (_token == null) {
      throw Exception("Error:User must be authorized");
    }
    try {
      final response = await dio.post("$baseUrl/password/change/request-otp/",
          options: Options(headers: {'Authorization': 'Bearer $_token'}));
      if (response.statusCode == 200) {
        final data = response.data;
        return data;
      } else {
        final errorData = response.data;
        return errorData;
      }
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<Map<String, dynamic>> updateUserProfile(
      String name, String image) async {
    FormData formData = FormData.fromMap({
      "name": name,
      "image": await MultipartFile.fromFile(image),
    });

    await _loadToken();
    if (_token == null) {
      throw Exception("User must be authorized first");
    }
    try {
      final response = await dio.patch("$baseUrl/updateprofile/",
          data: formData,
          options: Options(headers: {"Authorization": "Bearer $_token"}));
      if (response.statusCode == 200) {
        final data = response.data;
        return data;
      } else {
        final errorData = response.data;
        return errorData;
      }
    } catch (e) {
      throw Exception("Error:$e");
    }
  }

  Future<Map<String, dynamic>> getuserProfile() async {
    await _loadToken();
    if (_token == null) {
      throw Exception("User must be authorized first");
    }
    try {
      final response = await dio.get("$baseUrl/getUserProfile/",
          options: Options(headers: {'Authorization': 'Bearer $_token'}));
      if (response.statusCode == 200) {
        final data = response.data['msg'];
        return data;
      } else {
        final errorData = response.data;
        return errorData;
      }
    } catch (e) {
      throw Exception("Error:$e");
    }
  }
}
