// lib/domain/entities/file_transfer.dart
class FileTransfer {
  final String transferId;
  final String senderId;
  final String receiverId;
  final String fileName;
  final int fileSize;
  final String fileType;
  final int chunkCount;
  final String encryptedKey; // Base64 encoded
  final String iv; // Base64 encoded

  FileTransfer({
    required this.transferId,
    required this.senderId,
    required this.receiverId,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.chunkCount,
    required this.encryptedKey,
    required this.iv,
  });
}

// lib/domain/entities/peer.dart
class Peer {
  final String peerId;
  final String userId;
  final String deviceName;

  Peer({
    required this.peerId,
    required this.userId,
    required this.deviceName,
  });
}

// lib/domain/entities/signaling_message.dart
class SignalingMessage {
  final String type;
  final dynamic data;

  SignalingMessage({required this.type, this.data});
}