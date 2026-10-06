class Room {
  final String id;
  final String name;
  final String passcode;

  Room({required this.id, required this.name, required this.passcode});

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'],
      name: json['name'],
      passcode: json['passcode'],
    );
  }
}

class Peer {
  final String id;
  final String userId;
  final String deviceName;

  Peer({required this.id, required this.userId, required this.deviceName});

  factory Peer.fromJson(Map<String, dynamic> json) {
    return Peer(
      id: json['id'],
      userId: json['user_id'],
      deviceName: json['device_name'],
    );
  }
}

class FileMetadata {
  final String transferId;
  final String fileName;
  final int fileSize;
  final String fileType;
  final int chunkCount;
  final String encryptedKey;
  final String iv;

  FileMetadata({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.chunkCount,
    required this.encryptedKey,
    required this.iv,
  });

  factory FileMetadata.fromJson(Map<String, dynamic> json) {
    return FileMetadata(
      transferId: json['transfer_id'],
      fileName: json['file_name'],
      fileSize: json['file_size'],
      fileType: json['file_type'],
      chunkCount: json['chunk_count'],
      encryptedKey: json['encrypted_key'],
      iv: json['iv'],
    );
  }
}