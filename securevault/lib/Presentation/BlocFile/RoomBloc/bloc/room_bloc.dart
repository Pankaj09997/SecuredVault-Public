import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:securevault/Data/DataSource/WebRtcService.dart';
import 'package:securevault/Data/DataSource/WebSocketService.dart';
import 'package:securevault/Data/Repositories/FileTransferRepository.dart';
import 'package:securevault/Presentation/BlocFile/RoomBloc/bloc/room_event.dart';
import 'package:securevault/Presentation/BlocFile/RoomBloc/bloc/room_state.dart';
import 'package:uuid/uuid.dart';

/// The RoomBloc connects the UI to the file transfer pipeline.
///
/// It listens for user actions (events) and orchestrates the services:
///   - WebSocketService → room management + signaling
///   - WebRtcService → peer connection + data channel
///   - FileTransferRepositoryImpl → E2EE send/receive flow
///
/// Supports multiple file transfers within a single room session.
class RoomBloc extends Bloc<RoomEvent, RoomState> {
  final WebSocketService _webSocketService;
  final WebRtcService _webRtcService;
  final FileTransferRepositoryImpl _transferRepo;

  // This device's unique peer ID — generated once per session.
  final String _myPeerId = const Uuid().v4();

  // Current room ID for the active session.
  String? _currentRoomId;

  // ── Persistent session info (survives state transitions) ─────
  String? _connectedPeerId;
  String? _connectedUserId;
  String? _connectedUsername;
  String _currentRoomName = '';

  // Transfer history for the current session.
  final List<TransferRecord> _transferHistory = [];

  // Cache the pending file name so we don't need to access
  // the repository's private _pendingMetadata field.
  String _pendingFileName = 'file';



  // Subscriptions to clean up on close.
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  StreamSubscription<bool>? _dataChannelSubscription;
  StreamSubscription<Uint8List>? _chunkSubscription;

  RoomBloc({
    required WebSocketService webSocketService,
    required WebRtcService webRtcService,
    required FileTransferRepositoryImpl transferRepo,
  })  : _webSocketService = webSocketService,
        _webRtcService = webRtcService,
        _transferRepo = transferRepo,
        super(const RoomInitial()) {
    // Register event handlers
    on<CreateRoom>(_onCreateRoom);
    on<JoinRoom>(_onJoinRoom);
    on<ConnectWebSocket>(_onConnectWebSocket);
    on<PeerJoined>(_onPeerJoined);
    on<InitiateTransfer>(_onInitiateTransfer);
    on<FileMetadataReceived>(_onFileMetadataReceived);
    on<ChunkReceived>(_onChunkReceived);
    on<AllChunksReceived>(_onAllChunksReceived);
    on<ResetForNextTransfer>(_onResetForNextTransfer);
    on<LeaveRoom>(_onLeaveRoom);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Getters for UI access
  // ═══════════════════════════════════════════════════════════════

  String? get connectedPeerId => _connectedPeerId;
  String? get connectedUserId => _connectedUserId;
  String? get connectedUsername => _connectedUsername;
  String get currentRoomName => _currentRoomName;
  bool get isInRoom => _currentRoomId != null;
  List<TransferRecord> get transferHistory =>
      List.unmodifiable(_transferHistory);

  // ═══════════════════════════════════════════════════════════════
  //  Event Handlers
  // ═══════════════════════════════════════════════════════════════

  /// CREATE ROOM — User wants to share a file.
  /// 1. POST to Django → get room_id + auto-generated passcode
  /// 2. Connect WebSocket for real-time signaling
  /// 3. Initialize WebRTC peer connection
  /// 4. Emit RoomCreated so UI shows the passcode
  Future<void> _onCreateRoom(
    CreateRoom event,
    Emitter<RoomState> emit,
  ) async {
    emit(const RoomLoading());
    try {
      // REST call to create room — Django generates the passcode
      final response = await _webSocketService.createRoom(event.roomName);
      final room = response['room'] as Map<String, dynamic>;
      final roomId = room['id'] as String;
      final passcode = room['passcode'] as String;
      _currentRoomId = roomId;
      _currentRoomName = event.roomName;

      // Open WebSocket for real-time signaling
      await _webSocketService.connectWebSocket(roomId);

      // Initialize WebRTC (creates RTCPeerConnection + STUN setup)
      await _webRtcService.initialize(_myPeerId);

      // Authenticate with the signaling server via WebSocket
      _webSocketService.sendSignal({
        'type': 'authenticate',
        'peer_id': _myPeerId,
        'device_name': 'Flutter Device',
      });

      // Start listening for signaling messages
      _listenToSignaling();

      emit(RoomCreated(
        roomId: roomId,
        passcode: passcode,
        roomName: event.roomName,
      ));
    } catch (e) {
      emit(RoomError("Failed to create room: $e"));
    }
  }

  /// JOIN ROOM — User enters room_id + passcode.
  /// 1. POST to Django → validate passcode, create Peer record
  /// 2. Connect WebSocket
  /// 3. Initialize WebRTC
  /// 4. Send 'join' signal so room owner knows someone connected
  Future<void> _onJoinRoom(
    JoinRoom event,
    Emitter<RoomState> emit,
  ) async {
    emit(const RoomLoading());
    try {
      final response = await _webSocketService.joinRoom(
        roomId: event.roomId,
        passcode: event.passcode,
        peerId: _myPeerId,
        deviceName: 'Flutter Device',
      );
      _currentRoomId = event.roomId;
      final room = response['room'] as Map<String, dynamic>;
      _currentRoomName = room['name'] as String? ?? 'Room';

      // Open WebSocket
      await _webSocketService.connectWebSocket(event.roomId);

      // Initialize WebRTC
      await _webRtcService.initialize(_myPeerId);

      // Authenticate via WebSocket
      _webSocketService.sendSignal({
        'type': 'authenticate',
        'peer_id': _myPeerId,
        'device_name': 'Flutter Device',
      });

      // Notify the room that we joined
      _webSocketService.sendSignal({'type': 'join'});

      // Start listening for signaling messages
      _listenToSignaling();

      emit(RoomJoined(
        roomId: event.roomId,
        roomName: _currentRoomName,
      ));
    } catch (e) {
      emit(RoomError("Failed to join room: $e"));
    }
  }

  /// CONNECT WEBSOCKET — standalone WebSocket connection.
  Future<void> _onConnectWebSocket(
    ConnectWebSocket event,
    Emitter<RoomState> emit,
  ) async {
    try {
      await _webSocketService.connectWebSocket(event.roomId);
      _listenToSignaling();
      emit(const WebSocketConnected());
    } catch (e) {
      emit(RoomError("WebSocket connection failed: $e"));
    }
  }

  /// PEER JOINED — Another device connected to the room.
  /// Store the peer info persistently so it survives state changes.
  Future<void> _onPeerJoined(
    PeerJoined event,
    Emitter<RoomState> emit,
  ) async {
    _connectedPeerId = event.peerId;
    _connectedUserId = event.userId;
    _connectedUsername = event.username;

    emit(PeerConnected(
        peerId: event.peerId, userId: event.userId, username: event.username));
  }

  /// INITIATE TRANSFER — User picked a file, start the 5-step send flow.
  /// 1. Create WebRTC offer → establish data channel (or reuse existing)
  /// 2. Start the E2EE send pipeline via FileTransferRepository
  /// 3. Emit progress updates as chunks are sent
  Future<void> _onInitiateTransfer(
    InitiateTransfer event,
    Emitter<RoomState> emit,
  ) async {
    try {
      final fileName = event.file.path.split('/').last;

      if (!_webRtcService.isDataChannelOpen) {
        // IMPORTANT: Subscribe to the data channel state stream BEFORE
        // creating the offer. onDataChannelState is a broadcast stream —
        // if the channel opens during createOffer() and we haven't started
        // listening yet, the event is lost and we'd time out.
        final dataChannelOpenFuture = _webRtcService.onDataChannelState
            .firstWhere((isOpen) => isOpen == true)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw Exception(
                "Data channel did not open in time. "
                "The peer connection may have failed.",
              ),
            );

        // Create a new WebRTC offer + data channel for the first transfer.
        // For subsequent transfers, we reuse the existing data channel.
        await _webRtcService.createOffer(
          event.receiverPeerId,
          const Uuid().v4(),
        );

        // Now await the future that was already listening
        await dataChannelOpenFuture;
      }

      // Execute the full E2EE send flow
      // sendFile returns a stream of progress (0.0 to 1.0)
      await for (final progress in _transferRepo.sendFile(
        file: event.file,
        receiverId: event.receiverUserId,
        receiverPeerId: event.receiverPeerId,
        roomId: _currentRoomId!,
        senderId: _myPeerId,
      )) {
        emit(TransferInProgress(progress: progress, fileName: fileName));
      }

      // Record successful transfer in history
      _transferHistory.add(TransferRecord(
        fileName: fileName,
        savedPath: '',
        isSender: true,
        result: TransferResult.success,
        timestamp: DateTime.now(),
      ));

      emit(TransferSuccess(fileName: fileName, savedPath: ''));
    } catch (e) {
      // Record failed transfer in history
      _transferHistory.add(TransferRecord(
        fileName: event.file.path.split('/').last,
        savedPath: '',
        isSender: true,
        result: TransferResult.error,
        timestamp: DateTime.now(),
      ));

      emit(RoomError("Transfer failed: $e"));
    }
  }

  Future<void> _onFileMetadataReceived(
    FileMetadataReceived event,
    Emitter<RoomState> emit,
  ) async {
    // handleIncomingMetadata is now async — it unwraps the AES key
    // and opens a temp file for streaming writes.
    await _transferRepo.handleIncomingMetadata(event.metadata);
    _pendingFileName = event.metadata['file_name'] as String;
    final int expectedCount = event.metadata['chunk_count'] as int;
    final receivedIndexes = <int>{};

    // Listen to data channel chunks to track progress and trigger finalization.
    // Note: the actual decryption + disk write happens inside the repository's
    // chunk listener. This listener only tracks progress for the UI.
    _chunkSubscription?.cancel();
    _chunkSubscription = _webRtcService.onChunkReceived.listen((chunk) {
      // New chunk format: [4-byte index][16-byte GCM tag][encrypted data]
      // We only need the index (first 4 bytes) for progress tracking.
      if (chunk.length < 20) {
        return;
      }

      final chunkIndex = ByteData.sublistView(chunk, 0, 4).getUint32(0);
      receivedIndexes.add(chunkIndex);
      final receivedCount = receivedIndexes.length;

      add(ChunkReceived(
        progress: expectedCount == 0 ? 1 : receivedCount / expectedCount,
        fileName: _pendingFileName,
      ));

      if (receivedCount >= expectedCount) {
        // Cancel immediately to prevent duplicate AllChunksReceived
        // events from late-arriving chunks on the broadcast stream.
        _chunkSubscription?.cancel();
        _chunkSubscription = null;
        add(const AllChunksReceived());
      }
    });

    _webSocketService.sendSignal({
      'type': 'data_channel_ready',
      'sender_peer': event.metadata['sender_peer'],
      'transfer_id': event.metadata['transfer_id'],
    });

    emit(TransferMetadataReceived(
      fileName: _pendingFileName,
      fileSize: event.metadata['file_size'] as int,
      chunkCount: expectedCount,
    ));

    if (expectedCount == 0) {
      add(const AllChunksReceived());
    }
  }

  /// CHUNK RECEIVED — Update progress bar for receiver.
  Future<void> _onChunkReceived(
    ChunkReceived event,
    Emitter<RoomState> emit,
  ) async {
    emit(
        TransferInProgress(progress: event.progress, fileName: event.fileName));
  }

  /// ALL CHUNKS RECEIVED — Run the 4-step receive verification.
  /// This is where tamper detection and impersonation checks happen.
  Future<void> _onAllChunksReceived(
    AllChunksReceived event,
    Emitter<RoomState> emit,
  ) async {
    try {
      emit(const RoomLoading());
      final savedPath = await _transferRepo.finalizeReceive();

      // Record successful receive in history
      _transferHistory.add(TransferRecord(
        fileName: _pendingFileName,
        savedPath: savedPath,
        isSender: false,
        result: TransferResult.success,
        timestamp: DateTime.now(),
      ));

      emit(TransferSuccess(
        fileName: _pendingFileName,
        savedPath: savedPath,
      ));
    } on TamperDetectedException catch (e) {
      _transferHistory.add(TransferRecord(
        fileName: _pendingFileName,
        savedPath: '',
        isSender: false,
        result: TransferResult.tampered,
        timestamp: DateTime.now(),
      ));
      // GCM tag mismatch — file was modified in transit
      emit(TransferTampered(e.message));
    } on ImpersonationDetectedException catch (e) {
      _transferHistory.add(TransferRecord(
        fileName: _pendingFileName,
        savedPath: '',
        isSender: false,
        result: TransferResult.impersonation,
        timestamp: DateTime.now(),
      ));
      // Ed25519 signature invalid — sender identity not verified
      emit(TransferImpersonation(e.message));
    } catch (e) {
      _transferHistory.add(TransferRecord(
        fileName: _pendingFileName,
        savedPath: '',
        isSender: false,
        result: TransferResult.error,
        timestamp: DateTime.now(),
      ));
      emit(RoomError("Receive failed: $e"));
    }
  }

  /// RESET FOR NEXT TRANSFER — After a transfer completes, return to
  /// the ready state so the user can send/receive another file.
  Future<void> _onResetForNextTransfer(
    ResetForNextTransfer event,
    Emitter<RoomState> emit,
  ) async {
    if (_connectedPeerId != null &&
        _connectedUserId != null &&
        _connectedUsername != null) {
      emit(ReadyToTransfer(
        peerId: _connectedPeerId!,
        userId: _connectedUserId!,
        username: _connectedUsername!,
        roomName: _currentRoomName,
        history: List.unmodifiable(_transferHistory),
      ));
    } else {
      // Peer disconnected while we were in a terminal state — go back to initial
      emit(const RoomInitial());
    }
  }

  /// LEAVE ROOM — cleanup everything.
  Future<void> _onLeaveRoom(
    LeaveRoom event,
    Emitter<RoomState> emit,
  ) async {
    await _cleanup();
    emit(const RoomDisconnected());
  }

  // ═══════════════════════════════════════════════════════════════
  //  Internal: Listen to signaling messages
  // ═══════════════════════════════════════════════════════════════

  /// Routes incoming WebSocket messages to the appropriate BLoC events.
  /// The WebSocketService just delivers raw JSON — this method decides
  /// what each message means and fires the corresponding event.
  void _listenToSignaling() {
    _wsSubscription?.cancel();
    _wsSubscription = _webSocketService.messages.listen((message) {
      final type = message['type'] as String?;

      switch (type) {
        case 'peer-joined':
          add(PeerJoined(
            peerId: message['peer_id'] as String,
            userId: message['user_id'] as String,
            username: message['username'] as String? ?? 'Unknown',
          ));
          break;

        case 'file_metadata':
          // E2EE metadata from the sender — store for decryption later
          add(FileMetadataReceived(message));
          break;

        case 'disconnected':
          add(const LeaveRoom());
          break;
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  Cleanup
  // ═══════════════════════════════════════════════════════════════

  Future<void> _cleanup() async {
    _wsSubscription?.cancel();
    _dataChannelSubscription?.cancel();
    _chunkSubscription?.cancel();
    await _transferRepo.close();
    _webSocketService.disconnect();
    _currentRoomId = null;
    _connectedPeerId = null;
    _connectedUserId = null;
    _connectedUsername = null;
    _currentRoomName = '';

    _transferHistory.clear();
  }

  @override
  Future<void> close() {
    _cleanup();
    return super.close();
  }
}
