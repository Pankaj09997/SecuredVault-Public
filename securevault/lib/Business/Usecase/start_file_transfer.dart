// import 'dart:typed_data';
// import 'package:pointycastle/api.dart';
// import 'package:pointycastle/asymmetric/api.dart';
// import 'package:securevault/Data/DataSource/WebSocketService.dart';
// import 'package:securevault/Data/Models/FileTransferModels.dart';

// class GenerateKeyPairUseCase {
//   Future<AsymmetricKeyPair<PublicKey, PrivateKey>> execute() async {
//     // Implement RSA key generation using pointycastle
//     // This is simplified - actual implementation needs crypto libraries
//     throw UnimplementedError('Key generation not implemented');
//   }
// }

// class EncryptAesKeyUseCase {
//   Uint8List execute(Uint8List aesKey, RSAPublicKey publicKey) {
//     // Implement RSA encryption using pointycastle
//     throw UnimplementedError('Encryption not implemented');
//   }
// }

// class CreateRoomUseCase {
//   final ApiService apiService;

//   CreateRoomUseCase(this.apiService);

//   Future<Room> execute(String roomName) async {
//     final response = await apiService.createRoom(roomName);
//     return Room.fromJson(response['room']);
//   }
// }

// class JoinRoomUseCase {
//   final ApiService apiService;

//   JoinRoomUseCase(this.apiService);

//   Future<Map<String, dynamic>> execute(String roomId, String passcode) async {
//     return await apiService.joinRoom(roomId, passcode);
//   }
// }