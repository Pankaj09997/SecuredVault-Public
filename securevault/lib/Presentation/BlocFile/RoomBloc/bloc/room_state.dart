import 'package:equatable/equatable.dart';

/// All states the RoomBloc can emit.
///
/// The UI reacts to each state differently:
///   - RoomCreated → show passcode for user to share
///   - RoomJoined → show "Connected"
///   - ReadyToTransfer → peer connected, send-file card shown
///   - TransferInProgress → show progress bar
///   - TransferSuccess → show "File received securely" + option to send more
///   - TransferTampered → show CRITICAL alert (file modified in transit)
///   - TransferImpersonation → show CRITICAL alert (signature invalid)

abstract class RoomState extends Equatable {
  const RoomState();
  @override
  List<Object?> get props => [];
}

/// Initial state — no room activity yet.
class RoomInitial extends RoomState {
  const RoomInitial();
}

/// Loading state for async operations.
class RoomLoading extends RoomState {
  const RoomLoading();
}

/// Room created successfully — UI shows the passcode for the user
/// to share with the receiver out-of-band.
class RoomCreated extends RoomState {
  final String roomId;
  final String passcode;
  final String roomName;
  const RoomCreated({
    required this.roomId,
    required this.passcode,
    required this.roomName,
  });
  @override
  List<Object?> get props => [roomId, passcode, roomName];
}

/// Successfully joined an existing room.
class RoomJoined extends RoomState {
  final String roomId;
  final String roomName;
  const RoomJoined({required this.roomId, required this.roomName});
  @override
  List<Object?> get props => [roomId, roomName];
}

/// WebSocket connected — ready for signaling.
class WebSocketConnected extends RoomState {
  const WebSocketConnected();
}

/// Another peer has connected to the room.
class PeerConnected extends RoomState {
  final String peerId;
  final String userId;
  final String username;
  const PeerConnected({required this.peerId, required this.userId, required this.username});
  @override
  List<Object?> get props => [peerId, userId, username];
}

/// Connected and ready to initiate or receive another file transfer.
/// This is the "idle-in-room" state that allows multi-transfer sessions.
class ReadyToTransfer extends RoomState {
  final String peerId;
  final String userId;
  final String username;
  final String roomName;
  /// Completed transfers this session (for the transfer history list).
  final List<TransferRecord> history;
  const ReadyToTransfer({
    required this.peerId,
    required this.userId,
    required this.username,
    required this.roomName,
    this.history = const [],
  });
  @override
  List<Object?> get props => [peerId, userId, username, roomName, history];
}

/// File transfer is in progress — UI shows a progress bar.
class TransferInProgress extends RoomState {
  final double progress; // 0.0 to 1.0
  final String fileName;
  const TransferInProgress({required this.progress, required this.fileName});
  @override
  List<Object?> get props => [progress, fileName];
}

/// Incoming file metadata received — waiting for chunks.
class TransferMetadataReceived extends RoomState {
  final String fileName;
  final int fileSize;
  final int chunkCount;
  const TransferMetadataReceived({
    required this.fileName,
    required this.fileSize,
    required this.chunkCount,
  });
  @override
  List<Object?> get props => [fileName, fileSize, chunkCount];
}

/// All checks passed — file received securely.
class TransferSuccess extends RoomState {
  final String fileName;
  final String savedPath;
  const TransferSuccess({required this.fileName, required this.savedPath});
  @override
  List<Object?> get props => [fileName, savedPath];
}

/// CRITICAL: GCM authentication tag mismatch.
/// The file was modified after encryption — tampering detected.
class TransferTampered extends RoomState {
  final String message;
  const TransferTampered(this.message);
  @override
  List<Object?> get props => [message];
}

/// CRITICAL: Ed25519 signature verification failed.
/// Someone is impersonating the sender.
class TransferImpersonation extends RoomState {
  final String message;
  const TransferImpersonation(this.message);
  @override
  List<Object?> get props => [message];
}

/// Generic error state.
class RoomError extends RoomState {
  final String message;
  const RoomError(this.message);
  @override
  List<Object?> get props => [message];
}

/// Disconnected from the room.
class RoomDisconnected extends RoomState {
  const RoomDisconnected();
}

// ═══════════════════════════════════════════════════════════════
//  Transfer history record
// ═══════════════════════════════════════════════════════════════

/// A completed transfer in the current session.
class TransferRecord extends Equatable {
  final String fileName;
  final String savedPath;
  final bool isSender;
  final TransferResult result;
  final DateTime timestamp;

  const TransferRecord({
    required this.fileName,
    required this.savedPath,
    required this.isSender,
    required this.result,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [fileName, savedPath, isSender, result, timestamp];
}

enum TransferResult { success, tampered, impersonation, error }