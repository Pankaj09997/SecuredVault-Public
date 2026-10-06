import 'dart:io';

/// Abstract contract for the signaling layer.
///
/// WebSocketService implements this. The FileTransferRepository
/// depends on this abstraction, not the concrete class — making
/// it testable with mocks.
abstract class SignalingRepository {
  Future<Map<String, dynamic>> createRoom(String name);
  Future<Map<String, dynamic>> joinRoom({
    required String roomId,
    required String passcode,
    required String peerId,
    String deviceName,
  });
  Future<void> connectWebSocket(String roomId);
  void sendSignal(Map<String, dynamic> message);
  Stream<Map<String, dynamic>> get messages;
  Future<void> exchangeKeys({
    required String rsaPublicKeyPem,
    required String ed25519PublicKeyBase64,
  });
  Future<Map<String, dynamic>> fetchReceiverKeys(String userId);
  void disconnect();
  void dispose();
}

/// Abstract contract for the file transfer orchestration.
///
/// FileTransferRepositoryImpl implements this. The RoomBloc
/// depends on this abstraction.
abstract class FileTransferRepository {
  /// Full send flow: encrypt → sign → wrap key → send metadata → send chunks.
  /// Returns a stream of progress (0.0 to 1.0).
  Stream<double> sendFile({
    required File file,
    required String receiverId,
    required String receiverPeerId,
    required String roomId,
    required String senderId,
  });

  /// Called when file_metadata arrives — stores E2EE fields and prepares
  /// the receiver for streaming decryption (unwraps AES key, opens temp file).
  Future<void> handleIncomingMetadata(Map<String, dynamic> metadata);

  /// Full receive flow: reassemble chunks → unwrap key → decrypt → verify.
  /// Returns the decrypted file bytes, or throws on tamper/impersonation.
  Future<String> finalizeReceive();

  /// Cleanup all transfer state.
  Future<void> close();
}
