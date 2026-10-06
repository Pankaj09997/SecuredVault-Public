import 'package:dio/dio.dart';
import 'package:securevault/Data/DataSource/BaseUrl.dart';
import 'package:securevault/Data/DataSource/ThrottlingInterceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardService {
  final String baseUrl = Baseurl.baseUrl;
  late final Dio dio;
  String? _token;

  DashboardService() {
    dio = Dio();
    dio.interceptors.add(ThrottlingInterceptor(
        minIntervalMs: 2000)); // 2s throttle for dashboard
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
  }

  Future<Map<String, dynamic>> getDashboardData() async {
    await _loadToken();
    if (_token == null) {
      throw Exception("User is not authorized");
    }

    try {
      final response = await dio.get(
        "$baseUrl/dashboard/",
        options: Options(
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $_token',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception("Error: ${response.statusCode}");
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw Exception("Too many requests. Please wait.");
      }
      throw Exception(e.message);
    }
  }
}
