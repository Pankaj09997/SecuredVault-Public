import 'dart:io';
import 'package:equatable/equatable.dart';

/// All events the RoomBloc can handle.
///
/// Each event maps to a user action or a system notification:
///   - User creates/joins a room → CreateRoom / JoinRoom
///   - Another peer connects → PeerJoined
///   - User picks a file → InitiateTransfer
///   - Data channel delivers chunks → ChunkReceived / AllChunksReceived
///   - User wants to send another file → ResetForNextTransfer
///   - User wants to leave → LeaveRoom

abstract class RoomEvent extends Equatable {
  const RoomEvent();
  @override
  List<Object?> get props => [];
}

/// User wants to share a file → create a new room.
/// Django generates a 6-digit passcode the user shares out-of-band.
class CreateRoom extends RoomEvent {
  final String roomName;
  const CreateRoom(this.roomName);
  @override
  List<Object?> get props => [roomName];
}

/// User enters a room_id + passcode to join an existing room.
class JoinRoom extends RoomEvent {
  final String roomId;
  final String passcode;
  const JoinRoom({required this.roomId, required this.passcode});
  @override
  List<Object?> get props => [roomId, passcode];
}

/// WebSocket notifies: another device connected to the room.
class PeerJoined extends RoomEvent {
  final String peerId;
  final String userId;
  final String username;
  const PeerJoined({required this.peerId, required this.userId, required this.username});
  @override
  List<Object?> get props => [peerId, userId, username];
}

/// User picks a file and triggers the full 5-step send flow.
class InitiateTransfer extends RoomEvent {
  final File file;
  final String receiverPeerId;
  final String receiverUserId;
  const InitiateTransfer({
    required this.file,
    required this.receiverPeerId,
    required this.receiverUserId,
  });
  @override
  List<Object?> get props => [file, receiverPeerId, receiverUserId];
}

/// Incoming file_metadata from sender — E2EE fields arrive via signaling.
class FileMetadataReceived extends RoomEvent {
  final Map<String, dynamic> metadata;
  const FileMetadataReceived(this.metadata);
  @override
  List<Object?> get props => [metadata];
}

/// A chunk has been received via the data channel.
class ChunkReceived extends RoomEvent {
  final double progress;
  final String fileName;
  const ChunkReceived({required this.progress, required this.fileName});
  @override
  List<Object?> get props => [progress, fileName];
}

/// All chunks have been received from the data channel.
/// Triggers the 4-step receive verification flow.
class AllChunksReceived extends RoomEvent {
  const AllChunksReceived();
}

/// WebSocket connection requested for a specific room.
class ConnectWebSocket extends RoomEvent {
  final String roomId;
  const ConnectWebSocket(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

/// After a transfer completes (success/error/tamper), go back to ReadyToTransfer
/// so the user can send/receive another file in the same session.
class ResetForNextTransfer extends RoomEvent {
  const ResetForNextTransfer();
}

/// User wants to disconnect / leave the room.
class LeaveRoom extends RoomEvent {
  const LeaveRoom();
}