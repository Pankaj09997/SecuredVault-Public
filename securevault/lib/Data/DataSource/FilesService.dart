import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:securevault/Data/DataSource/BaseUrl.dart';
import 'package:securevault/Data/DataSource/ThrottlingInterceptor.dart';
import 'package:securevault/Data/DataSource/public_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;

class FilesService {
  final String baseUrl = Baseurl.baseUrl;
  late final Dio dio;
  String? _token;

  Uint8List _deriveKek(String password, Uint8List salt) {
    final generator = pc.Argon2BytesGenerator()
      ..init(pc.Argon2Parameters(pc.Argon2Parameters.ARGON2_id, salt,
          desiredKeyLength: 32, iterations: 3, memory: 65536, lanes: 1));
    final key = Uint8List(32);
    generator.deriveKey(Uint8List.fromList(utf8.encode(password)), 0, key, 0);
    return key;
  }

  Future<Uint8List> _encryptForVault(
      Uint8List plaintext, String password, Map<String, String> fields) async {
    final random = Random.secure();
    Uint8List randomBytes(int count) => Uint8List.fromList(
        List<int>.generate(count, (_) => random.nextInt(256)));
    final salt = randomBytes(16);
    final kek = _deriveKek(password, salt);
    final dek = randomBytes(32);
    final aes = crypto.AesGcm.with256bits();
    final payload =
        await aes.encrypt(plaintext, secretKey: crypto.SecretKey(dek));
    final wrapped = await aes.encrypt(dek, secretKey: crypto.SecretKey(kek));
    fields.addAll({
      'e2ee': '1',
      'e2ee_original_size': plaintext.length.toString(),
      'e2ee_salt': base64Encode(salt),
      'e2ee_wrapped_key': base64Encode(wrapped.cipherText),
      'e2ee_wrap_nonce': base64Encode(wrapped.nonce),
      'e2ee_wrap_tag': base64Encode(wrapped.mac.bytes),
      'e2ee_file_nonce': base64Encode(payload.nonce),
      'e2ee_file_tag': base64Encode(payload.mac.bytes),
    });
    return Uint8List.fromList(payload.cipherText);
  }

  Future<Uint8List> _decryptVaultResponse(
      http.Response response, String password) async {
    if (response.headers['x-vault-e2ee'] != '1') return response.bodyBytes;
    try {
      Uint8List header(String name) =>
          Uint8List.fromList(base64Decode(response.headers[name]!));
      final salt = header('x-vault-salt');
      final kek = _deriveKek(password, salt);
      final aes = crypto.AesGcm.with256bits();
      final dek = await aes.decrypt(
          crypto.SecretBox(header('x-vault-wrapped-key'),
              nonce: header('x-vault-wrap-nonce'),
              mac: crypto.Mac(header('x-vault-wrap-tag'))),
          secretKey: crypto.SecretKey(kek));
      return Uint8List.fromList(await aes.decrypt(
          crypto.SecretBox(response.bodyBytes,
              nonce: header('x-vault-file-nonce'),
              mac: crypto.Mac(header('x-vault-file-tag'))),
          secretKey: crypto.SecretKey(dek)));
    } catch (_) {
      throw Exception(
          'Vault password is incorrect or the encrypted file was altered.');
    }
  }

  FilesService() {
    dio = Dio();
    dio.interceptors
        .add(ThrottlingInterceptor(minIntervalMs: 500)); // 0.5s throttle
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
  }

  Future<Map<String, dynamic>> uploadFiles(File file,
      {required String vaultPassword}) async {
    await _loadToken();
    if (_token == null) {
      throw Exception("Unable to upload the files");
    }
    var url = Uri.parse("$baseUrl/upload/");
    final request = MultipartRequest("POST", url);
    request.headers['Authorization'] = 'Bearer $_token';
    final fields = <String, String>{};
    final cipher =
        await _encryptForVault(await file.readAsBytes(), vaultPassword, fields);
    request.fields.addAll(fields);
    request.files.add(http.MultipartFile.fromBytes('file', cipher,
        filename: file.path.split('/').last));
    var response = await request.send();
    if (response.statusCode == 201) {
      var respStr = await response.stream.bytesToString();
      print("upload Successful:$respStr");
      final jsonData = json.decode(respStr);
      return jsonData;
    } else {
      var errorMessage = await response.stream.bytesToString();
      final jsonData = json.decode(errorMessage);
      print("Upload Failed:$errorMessage");
      return jsonData;
    }
  }

  Future<List<Map<String, dynamic>>> listFiles() async {
    await _loadToken();
    if (_token == null) {
      throw Exception("User is not authorized");
    }

    try {
      final response = await dio.get(
        "$baseUrl/files/",
        options: Options(
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $_token'
          },
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.cast<Map<String, dynamic>>();
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

//on running this code i should get the file,download it and save it to the local storage and returns the downloaded file so it can be used later
  Future<File> downloadFile(int fileId, {required String vaultPassword}) async {
    await _loadToken();
    if (_token == null) {
      throw Exception("Invalid Token");
    }

    final response = await http.get(
      Uri.parse("$baseUrl/download/$fileId"),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $_token'
      },
    );

    if (response.statusCode == 200) {
      final clearBytes = await _decryptVaultResponse(response, vaultPassword);
      // 5. Handle filename
      String? filename;
      final contentDisposition = response.headers['content-disposition'];

      if (contentDisposition != null) {
        final match =
            RegExp(r'filename="(.+?)"').firstMatch(contentDisposition);
        filename = match?.group(1);
      }

      filename ??= 'file_$fileId';

      // 9. Save file
      try {
        final file = await PublicStorageService().saveToDownloads(
          bytes: clearBytes,
          fileName: filename,
        );
        print("Full path of the file is :${file.path}");
        return file;
      } catch (e) {
        throw Exception("Failed to save file: ${e.toString()}");
      }
    } else {
      throw Exception("Download failed with status ${response.statusCode}");
    }
  }

  Future<List<Map<String, dynamic>>> fileAccessLog(int fileId) async {
    await _loadToken();
    if (_token == null) {
      throw Exception("User is not authorized");
    }
    final response = await http
        .get(Uri.parse("$baseUrl/log/$fileId"), headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': "Bearer $_token",
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("$data");
      return data;
    } else {
      final errorData = jsonDecode(response.body);
      print("$errorData");
      throw Exception("$errorData");
    }
  }

  Future<Uint8List> viewFiles(int fileId,
      {required String vaultPassword}) async {
    await _loadToken();
    if (_token == null) {
      throw Exception("User is not authorized to view the files");
    }
    final response = await http.get(Uri.parse("$baseUrl/fileview/$fileId"),
        headers: <String, String>{'Authorization': 'Bearer $_token'});
    if (response.statusCode == 200) {
      return _decryptVaultResponse(response, vaultPassword);
    } else {
      throw Exception("Unable to view the files");
    }
  }

  Future<Map<String, dynamic>> createLink(
      String resourceType, int resourceId) async {
    await _loadToken();
    if (_token == null) {
      throw Exception("User is not authorized");
    }
    try {
      final response = await http.post(Uri.parse("$baseUrl/link/"),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': "Bearer $_token",
          },
          body:
              jsonEncode({"resource_type": "File", "resource_id": resourceId}));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Shareable Link:${response.body}");

        return data;
      } else {
        final errorData = jsonDecode(response.body);
        print("Error Data:${response.body}");

        return errorData;
      }
    } catch (e) {
      print("$e");
      throw Exception("Error $e");
    }
  }

  Future<Map<String, dynamic>> deleteFile(int fileId) async {
    await _loadToken();
    if (_token == null) {
      throw Exception("User is not authorized");
    }
    final response = await http.delete(
        (Uri.parse("$baseUrl/deleteFile/$fileId")),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $_token'
        });
    if (response.statusCode == 200 || response.statusCode == 204) {
      if (response.body.isNotEmpty) {
        return jsonDecode(response.body);
      } else {
        return {"message": "File deleted Successfully"};
      }
    } else {
      final errorData = jsonDecode(response.body);
      return errorData;
    }
  }
}
