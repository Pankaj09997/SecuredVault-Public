import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' as typed_data; // Added alias

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:securevault/Data/DataSource/BaseUrl.dart';
import 'package:securevault/Data/DataSource/ThrottlingInterceptor.dart';
import 'package:securevault/Data/DataSource/public_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImageService {
  final String baseUrl = Baseurl.baseUrl;
  late final Dio dio;
  String? _token;

  ImageService() {
    dio = Dio();
    dio.interceptors
        .add(ThrottlingInterceptor(minIntervalMs: 500)); // 0.5s throttle
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
  }

  Future<Map<String, dynamic>> uploadImage(File image) async {
    await _loadToken();
    if (_token == null) {
      throw Exception("User is not authorized");
    }
    var url = Uri.parse("$baseUrl/UploadImage/");
    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(http.MultipartFile.fromBytes(
        'file', await image.readAsBytes(),
        filename: image.path.split('/').last));
    var response = await request.send();
    if (response.statusCode == 201) {
      var respStr = await response.stream.bytesToString();
      print("upload SuccessFul");
      final jsonData = json.decode(respStr);
      return jsonData;
    } else {
      final errorData = await response.stream.bytesToString();
      return json.decode(errorData);
    }
  }

  Future<List<Map<String, dynamic>>> listImages() async {
    await _loadToken();
    if (_token == null) {
      throw Exception("User is not authorized");
    }

    try {
      final response = await dio.get(
        "$baseUrl/Listimages/",
        options: Options(headers: {'Authorization': "Bearer $_token"}),
      );

      if (response.statusCode == 200) {
        final dynamic decoded = response.data;

        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
        throw const FormatException("Unexpected response format");
      } else {
        throw Exception("Failed to load images: ${response.statusCode}");
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw Exception("Too many requests. Please wait.");
      }
      throw Exception(e.message);
    }
  }

  Future<List<Map<String, dynamic>>> accessLog(int imageId) async {
    await _loadToken();
    if (_token == null) {
      throw Exception("User is not authenticated");
    }
    final response = await http
        .get(Uri.parse("$baseUrl/imagelog/$imageId"), headers: <String, String>{
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json ; charset=UTF-8',
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("$data");
      return data;
    } else {
      final errorData = jsonDecode(response.body);
      print("$errorData");
      return errorData;
    }
  }

  Future<File> downloadImage(int imageId) async {
    // loading the token
    await _loadToken();
    if (_token == null) {
      throw Exception("User is not authorized");
    }
    // get request
    final response = await http.get(
      Uri.parse("$baseUrl/DownloadImage/$imageId"),
      headers: <String, String>{
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json ; charset=UTF-8',
      },
    );
    if (response.statusCode == 200) {
      String? filename;
      // i got the headers that we have send using the backend
      final contentDisposition = response.headers['content-disposition'];
      if (contentDisposition != null) {
        final match =
            RegExp(r'filename="(.+?)"').firstMatch(contentDisposition);
        filename = match?.group(1);
      }
      filename ??= "file $imageId";

      try {
        final file = await PublicStorageService().saveToDownloads(
          bytes: response.bodyBytes,
          fileName: filename,
        );
        print("Full path of the file is :${file.path}");
        return file;
      } catch (e) {
        throw Exception("Error:$e");
      }
    } else {
      throw Exception("Download failed with status ${response.body}");
    }
  }

  Future<typed_data.Uint8List> viewImage(int imageId) async {
    // Used aliased type
    await _loadToken();
    if (_token == null) {
      throw Exception("User is not authorized");
    }
    final response = await http.get(
      Uri.parse("$baseUrl/imageview/$imageId"),
      headers: <String, String>{
        'Authorization': 'Bearer $_token',
      },
    );
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception(
          "Unable to show the image (Status: ${response.statusCode})");
    }
  }

  Future<Map<String, dynamic>> deleteImage(int fileId) async {
    await _loadToken();
    if (_token == null) {
      throw Exception("User is not authorized ");
    }
    final response = await http.delete(
        Uri.parse("$baseUrl/deleteImage/$fileId"),
        headers: <String, String>{
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json; charset=UTF-8'
        });
    if (response.statusCode == 200 || response.statusCode == 204) {
      if (response.body.isNotEmpty) {
        return jsonDecode(response.body);
      } else {
        return {"message": "File deleted successfully"};
      }
    } else {
      // Decode and return error info from backend
      return jsonDecode(response.body);
    }
  }

  Future<Map<String, dynamic>> shareableImageLink(
      String resourceType, int resourceId) async {
    await _loadToken();
    if (_token == null) {
      throw Exception("User is not authorized");
    }
    final response = await http.post(
      Uri.parse("$baseUrl/link/"),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': "Bearer $_token",
      },
      body: jsonEncode({'resource_type': "Image", "resource_id": resourceId}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      final errorData = jsonDecode(response.body);
      print("Error:$errorData");
      return errorData;
    }
  }
}
