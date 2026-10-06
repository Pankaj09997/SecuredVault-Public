import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:securevault/Data/DataSource/WebSocketService.dart';

class WebRtcService {
  final WebSocketService _signaling;

  // ── Internal state ────────────────────────────────────────────
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  String? _remotePeerId;

  static const int chunkSize = 16 * 1024; // 16KB

  final StreamController<Uint8List> _chunkController =
      StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get onChunkReceived => _chunkController.stream;

  /// Emits true when the data channel opens, false when it closes.
  final StreamController<bool> _dataChannelStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get onDataChannelState => _dataChannelStateController.stream;

  /// Returns true if the data channel is currently open and ready to send data.
  bool get isDataChannelOpen =>
      _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;

  /// Emits true when the full P2P connection is established.
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get onConnectionState => _connectionStateController.stream;

  // ── Signaling listener ────────────────────────────────────────
  StreamSubscription<Map<String, dynamic>>? _signalingSubscription;

  WebRtcService(this._signaling);

  Future<void> initialize(String myPeerId) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ]
    };

    _peerConnection = await createPeerConnection(config);
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_remotePeerId != null) {
        _signaling.sendSignal({
          'type': 'ice-candidate',
          'target_peer': _remotePeerId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      }
    };

    // ── Connection state tracking ─────────────────────────────
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      final connected =
          state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(connected);
      }
    };

    _peerConnection!.onDataChannel = (RTCDataChannel channel) {
      _dataChannel = channel;
      _setupDataChannelListeners(channel);
    };
    _signalingSubscription = _signaling.messages.listen((message) {
      _handleSignalingMessage(message, myPeerId);
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  Sender: Create offer + data channel
  // ═══════════════════════════════════════════════════════════════

  /// The SENDER calls this to create an SDP offer and a data channel.
  ///
  /// An SDP offer is like a "proposal" — it describes what media/data
  /// capabilities this peer has. The receiver responds with an SDP answer.
  ///
  /// [remotePeerId] — the peer ID of the device you want to connect to.
  /// [transferId] — unique ID for this file transfer (used in channel label).
  Future<void> createOffer(String remotePeerId, String transferId) async {
    _remotePeerId = remotePeerId;

    // Create the data channel BEFORE creating the offer.
    // ordered: true ensures chunks arrive in sequence (critical for files).
    // Do NOT set maxRetransmits — that makes the channel "partially reliable"
    // which silently drops chunks after N retries. For file transfers we need
    // a fully reliable channel (the default when maxRetransmits is omitted).
    final channelInit = RTCDataChannelInit()
      ..ordered = true;

    _dataChannel = await _peerConnection!
        .createDataChannel('fileTransfer-$transferId', channelInit);
    _setupDataChannelListeners(_dataChannel!);

    // Create and set the local SDP offer
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Send the offer to the remote peer through the signaling server
    _signaling.sendSignal({
      'type': 'offer',
      'target_peer': remotePeerId,
      'offer': {
        'sdp': offer.sdp,
        'type': offer.type,
      },
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  Data Channel: Send chunks
  // ═══════════════════════════════════════════════════════════════

  /// Sends the ALREADY ENCRYPTED ciphertext over the data channel in chunks.
  ///
  /// The encryption happens in FileTransferRepository BEFORE this is called.
  /// This method only handles the chunking and delivery.
  ///
  /// Returns a stream of progress values (0.0 to 1.0) so the UI can
  /// show a progress bar.
  Stream<double> sendFileChunks(Uint8List encryptedData) async* {
    if (_dataChannel == null) {
      throw Exception("Data channel not ready");
    }

    final totalChunks = (encryptedData.length / chunkSize).ceil();
    if (totalChunks == 0) {
      _dataChannel!.send(RTCDataChannelMessage('{"type":"transfer_done"}'));
      yield 1;
      return;
    }

    // Back-pressure threshold: pause sending when the WebRTC internal
    // buffer exceeds this value. Prevents buffer overflow that silently
    // kills the data channel for large files (e.g. 30MB+ videos).
    const int bufferThreshold = 1 * 1024 * 1024; // 1 MB
    const int maxBufferWaitMs = 30000; // 30s safety timeout per chunk

    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize > encryptedData.length)
          ? encryptedData.length
          : start + chunkSize;

      final chunk = encryptedData.sublist(start, end);

      // Prefix each chunk with a 4-byte big-endian chunk index
      // so the receiver knows the order even if something gets mixed up
      final header = ByteData(4);
      header.setUint32(0, i, Endian.big);
      final message = Uint8List(4 + chunk.length)
        ..setRange(0, 4, header.buffer.asUint8List())
        ..setRange(4, 4 + chunk.length, chunk);

      // ── Back-pressure: wait if the buffer is too full ─────────
      // Without this, we'd push 30MB into the buffer faster than the
      // network can drain it, causing the data channel to crash.
      int waited = 0;
      while ((_dataChannel!.bufferedAmount ?? 0) > bufferThreshold) {
        await Future.delayed(const Duration(milliseconds: 20));
        waited += 20;
        if (waited > maxBufferWaitMs) {
          throw Exception(
            "Data channel buffer not draining — transfer stalled at chunk $i/$totalChunks.",
          );
        }
      }

      _dataChannel!.send(RTCDataChannelMessage.fromBinary(message));

      // Yield progress for the UI
      yield (i + 1) / totalChunks;
    }

    // Send an end-of-transfer marker
    _dataChannel!.send(RTCDataChannelMessage('{"type":"transfer_done"}'));
  }

  // ═══════════════════════════════════════════════════════════════
  //  STREAMING: Send individual pre-formatted chunks
  // ═══════════════════════════════════════════════════════════════

  /// Sends a single pre-formatted binary message with back-pressure.
  /// Used by the streaming FileTransferRepository where each chunk is
  /// encrypted individually and sent immediately (never buffered in RAM).
  ///
  /// The caller is responsible for formatting the message
  /// (e.g. [4-byte index][16-byte GCM tag][encrypted data]).
  Future<void> sendChunk(Uint8List message) async {
    if (_dataChannel == null) {
      throw Exception("Data channel not ready");
    }

    const int bufferThreshold = 1 * 1024 * 1024; // 1 MB
    const int maxBufferWaitMs = 30000; // 30s safety timeout

    // Back-pressure: wait if the buffer is too full
    int waited = 0;
    while ((_dataChannel!.bufferedAmount ?? 0) > bufferThreshold) {
      await Future.delayed(const Duration(milliseconds: 20));
      waited += 20;
      if (waited > maxBufferWaitMs) {
        throw Exception(
          "Data channel buffer not draining — transfer stalled.",
        );
      }
    }

    _dataChannel!.send(RTCDataChannelMessage.fromBinary(message));
  }

  /// Sends the end-of-transfer marker to the receiver.
  void sendTransferDone() {
    if (_dataChannel == null) return;
    _dataChannel!.send(RTCDataChannelMessage('{"type":"transfer_done"}'));
  }

  // ═══════════════════════════════════════════════════════════════
  //  Internal: Handle signaling messages
  // ═══════════════════════════════════════════════════════════════

  void _handleSignalingMessage(
      Map<String, dynamic> message, String myPeerId) async {
    final senderPeer = message['sender_peer'] as String?;
    if (senderPeer == myPeerId) {
      return; // Ignore messages echoed back from ourselves
    }

    final type = message['type'] as String?;

    switch (type) {
      // ── Receiver gets an offer → create answer ────────────
      case 'offer':
        _remotePeerId = message['sender_peer'] as String;
        final offerData = message['offer'] as Map<String, dynamic>;

        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(offerData['sdp'], offerData['type']),
        );

        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);

        _signaling.sendSignal({
          'type': 'answer',
          'target_peer': _remotePeerId,
          'answer': {
            'sdp': answer.sdp,
            'type': answer.type,
          },
        });
        break;

      // ── Sender gets an answer back ────────────────────────
      case 'answer':
        final answerData = message['answer'] as Map<String, dynamic>;
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(answerData['sdp'], answerData['type']),
        );
        break;

      // ── Both sides exchange ICE candidates ────────────────
      case 'ice-candidate':
        final candidateData = message['candidate'] as Map<String, dynamic>;
        final candidate = RTCIceCandidate(
          candidateData['candidate'],
          candidateData['sdpMid'],
          candidateData['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(candidate);
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  Internal: Data channel event listeners
  // ═══════════════════════════════════════════════════════════════

  void _setupDataChannelListeners(RTCDataChannel channel) {
    channel.onDataChannelState = (RTCDataChannelState state) {
      final isOpen = state == RTCDataChannelState.RTCDataChannelOpen;
      if (!_dataChannelStateController.isClosed) {
        _dataChannelStateController.add(isOpen);
      }
    };

    channel.onMessage = (RTCDataChannelMessage message) {
      if (message.isBinary) {
        // Binary message = a file chunk
        if (!_chunkController.isClosed) {
          _chunkController.add(message.binary);
        }
      } else {
        // Text message = control message (e.g. transfer_done)
        try {
          final data = jsonDecode(message.text) as Map<String, dynamic>;
          if (data['type'] == 'transfer_done') {
            // The RoomBloc finalizes transfers by expected chunk count.
            // Keep this broadcast stream alive for later transfers in the room.
          }
        } catch (_) {}
      }
    };
  }

  // ═══════════════════════════════════════════════════════════════
  //  Cleanup
  // ═══════════════════════════════════════════════════════════════

  Future<void> dispose() async {
    _signalingSubscription?.cancel();
    _dataChannel?.close();
    await _peerConnection?.close();
    _peerConnection = null;
    _dataChannel = null;
    _chunkController.close();
    _dataChannelStateController.close();
    _connectionStateController.close();
  }
}
