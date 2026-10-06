import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/asn1.dart';
import 'package:securevault/Business/Repositories/file_transfer_repository.dart';
import 'package:securevault/Data/DataSource/CryptographyService.dart';
import 'package:securevault/Data/DataSource/WebRtcService.dart';
import 'package:securevault/Data/DataSource/WebSocketService.dart';
import 'package:securevault/Data/DataSource/file_transfer_local_data_source.dart';
import 'package:uuid/uuid.dart';

/// The conductor — orchestrates CryptographyService, WebSocketService,
/// and WebRtcService to execute the full E2EE send/receive flow.
///
/// ═══════════════════════════════════════════════════════════════════
///  STREAMING ARCHITECTURE
/// ═══════════════════════════════════════════════════════════════════
///
/// Old approach (Uint8List):
///   Read 30MB → RAM. Encrypt 30MB → 60MB RAM. Send chunks. Peak: ~90MB.
///
/// New approach (Streaming):
///   Read 16KB from disk → encrypt → send → forget. Peak: ~1MB.
///
/// SEND FLOW:
///   Pass 1: Stream-hash the file (SHA256) → sign the hash → send metadata
///   Pass 2: Read file in 16KB chunks → encrypt each chunk → send each chunk
///
/// RECEIVE FLOW:
///   Each chunk arrives → decrypt it → write to temp file on disk
///   After all chunks: hash the temp file → verify signature → move to Downloads
///
/// Chunk wire format: [4-byte index][16-byte GCM tag][encrypted data]
///   - Index: big-endian chunk number for ordering
///   - Tag: per-chunk GCM authentication tag (tamper detection per chunk)
///   - Data: AES-256-GCM ciphertext of the plaintext chunk
class FileTransferRepositoryImpl implements FileTransferRepository {
  final CryptographyService _crypto;
  final WebSocketService _signaling;
  final WebRtcService _webRtc;
  final FileTransferLocalDataSource _localDataSource;

  // ── Transfer state ────────────────────────────────────────────
  Map<String, dynamic>? _pendingMetadata;
  String? _activeTransferId;

  // Streaming receiver state: chunks are decrypted and written to
  // this temp file immediately — never accumulated in RAM.
  IOSink? _tempFileSink;
  String? _tempFilePath;
  Uint8List? _receiverAesKey;
  Uint8List? _receiverBaseNonce;
  int _receivedChunkCount = 0;

  StreamSubscription<Uint8List>? _chunkSubscription;

  // Chunk size must match WebRtcService.chunkSize (plaintext size).
  static const int _chunkSize = 16 * 1024; // 16KB

  FileTransferRepositoryImpl({
    required CryptographyService crypto,
    required WebSocketService signaling,
    required WebRtcService webRtc,
    required FileTransferLocalDataSource localDataSource,
  })  : _crypto = crypto,
        _signaling = signaling,
        _webRtc = webRtc,
        _localDataSource = localDataSource;

  // ═══════════════════════════════════════════════════════════════
  //  SEND FLOW — Streaming (2-pass)
  // ═══════════════════════════════════════════════════════════════

  /// Orchestrates the full streaming send flow:
  ///   Pass 1: Hash the file (streaming SHA256) → sign → send metadata
  ///   Pass 2: Read file in 16KB chunks → encrypt each → send each
  ///
  /// Memory usage: ~1MB regardless of file size.
  /// Returns a stream of progress values (0.0 to 1.0).
  @override
  Stream<double> sendFile({
    required File file,
    required String receiverId,
    required String receiverPeerId,
    required String roomId,
    required String senderId,
  }) async* {
    final fileName = file.path.split('/').last;
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final fileStat = await file.stat();
    final fileSizeBytes = fileStat.size;

    // ── Pass 1: Stream-hash the file (only ~64KB in RAM) ───────
    // This reads the file from disk in small chunks, computing the
    // SHA256 incrementally. The entire file NEVER sits in RAM.
    final fileHashHex = await _crypto.computeFileHashStreaming(file);

    // ── Step 1: Build the transfer payload from the hash ──────
    final payload = _crypto.buildTransferPayloadFromHash(
      fileHashHex: fileHashHex,
      senderId: senderId,
      timestamp: timestamp,
    );

    // ── Step 2: Sign the payload with YOUR Ed25519 private key ─
    final ed25519PrivKey = await _crypto.loadEd25519PrivKey();
    if (ed25519PrivKey == null) {
      throw Exception("Ed25519 private key not found. Generate keys first.");
    }
    final signature = await _crypto.signPayLoad(payload, ed25519PrivKey);

    // ── Step 3: Generate AES key + base nonce for streaming ────
    final aesKey = _crypto.generateAesKey();
    final baseNonce = _crypto.generateBaseNonce();

    // ── Step 4: Wrap the AES key with RECEIVER's RSA public key ─
    final receiverKeys = await _signaling.fetchReceiverKeys(receiverId);
    final receiverRsaPem = receiverKeys['rsa_public_key'] as String;
    final receiverRsaPublicKey = _parseRsaPublicKeyFromPem(receiverRsaPem);
    final wrappedKey = _crypto.wrapWithRsa(aesKey, receiverRsaPublicKey);

    // ── Compute chunk count ───────────────────────────────────
    final chunkCount = (fileSizeBytes / _chunkSize).ceil();
    final transferId = const Uuid().v4();
    final readyAcknowledgement = _signaling.messages.firstWhere(
      (message) =>
          message['type'] == 'data_channel_ready' &&
          message['transfer_id'] == transferId,
    );

    // ── Step 5a: Send metadata via signaling (WebSocket) ──────
    _signaling.sendSignal({
      'type': 'file_metadata',
      'transfer_id': transferId,
      'receiver_id': receiverPeerId,
      'file_name': fileName,
      'file_size': fileSizeBytes,
      'file_type': 'application/octet-stream',
      'chunk_count': chunkCount,
      // ── E2EE fields ─────────────────────────────────────────
      'encrypted_aes_key': base64Encode(wrappedKey),
      'file_nonce': base64Encode(baseNonce),
      'file_tag': base64Encode(Uint8List(16)), // Dummy tag to satisfy backend validation
      'sender_signature': base64Encode(signature),
      'sender_public_key': '',
      'payload_hash': base64Encode(payload),
      'timestamp': timestamp,
    });

    // Scale timeout with file size: 30s base + 10s per 10MB
    final timeoutSeconds =
        30 + ((fileSizeBytes / (10 * 1024 * 1024)) * 10).ceil();
    await readyAcknowledgement.timeout(
      Duration(seconds: timeoutSeconds),
      onTimeout: () => throw Exception(
        "Receiver did not acknowledge the file metadata in time.",
      ),
    );

    // ── Pass 2: Stream-read → encrypt → send (16KB at a time) ─
    // This is the core streaming loop. Only ~32KB is in RAM at any
    // moment: one plaintext chunk + one ciphertext chunk.
    final raf = await file.open(mode: FileMode.read);
    try {
      for (int i = 0; i < chunkCount; i++) {
        final start = i * _chunkSize;
        final end = (start + _chunkSize > fileSizeBytes)
            ? fileSizeBytes
            : start + _chunkSize;
        final readLength = end - start;

        // Read one chunk from disk (only ~16KB in RAM)
        await raf.setPosition(start);
        final plainChunk = await raf.read(readLength);

        // Derive a unique nonce for this chunk
        final chunkNonce = _crypto.deriveChunkNonce(baseNonce, i);

        // Encrypt the chunk (produces ciphertext + GCM tag)
        final encResult =
            await _crypto.encryptChunkAesGcm(plainChunk, aesKey, chunkNonce);
        final cipherChunk = encResult['ciphertext']!;
        final tag = encResult['tag']!;

        // Format: [4-byte index][16-byte GCM tag][encrypted data]
        final header = ByteData(4)..setUint32(0, i, Endian.big);
        final message = Uint8List(4 + 16 + cipherChunk.length)
          ..setRange(0, 4, header.buffer.asUint8List())
          ..setRange(4, 20, tag)
          ..setRange(20, 20 + cipherChunk.length, cipherChunk);

        // Send with back-pressure (waits if buffer is full)
        await _webRtc.sendChunk(message);

        // Yield progress for the UI
        yield (i + 1) / chunkCount;
      }
    } finally {
      await raf.close();
    }

    // Send end-of-transfer marker
    _webRtc.sendTransferDone();
  }

  // ═══════════════════════════════════════════════════════════════
  //  RECEIVE FLOW — Streaming (decrypt-on-arrival)
  // ═══════════════════════════════════════════════════════════════

  /// Called when file_metadata arrives via signaling.
  /// Unwraps the AES key and opens a temp file for streaming writes.
  /// Each chunk that arrives will be decrypted immediately and written
  /// to the temp file — never accumulated in RAM.
  @override
  Future<void> handleIncomingMetadata(Map<String, dynamic> metadata) async {
    _pendingMetadata = metadata;
    _activeTransferId = metadata['transfer_id'] as String?;
    _receivedChunkCount = 0;

    // ── Unwrap the AES key now so we're ready to decrypt chunks ─
    final encryptedAesKey =
        base64Decode(metadata['encrypted_aes_key'] as String);
    final rsaPrivateKey = await _crypto.loadRSAPrivateKey();
    if (rsaPrivateKey == null) {
      throw Exception("RSA private key not found.");
    }
    _receiverAesKey = _crypto.unwrapKeyWithRsa(encryptedAesKey, rsaPrivateKey);
    _receiverBaseNonce = base64Decode(metadata['file_nonce'] as String);

    // ── Open a temp file for streaming writes ─────────────────
    final tempDir = await getTemporaryDirectory();
    _tempFilePath =
        '${tempDir.path}/securevault_transfer_${const Uuid().v4()}.tmp';
    _tempFileSink = File(_tempFilePath!).openWrite();

    // ── Start listening for chunks → decrypt → write to disk ──
    _chunkSubscription?.cancel();
    _chunkSubscription = _webRtc.onChunkReceived.listen((chunkWithHeader) async {
      if (_activeTransferId == null) return;

      // New format: [4-byte index][16-byte GCM tag][encrypted data]
      if (chunkWithHeader.length < 20) return;

      final chunkIndex =
          ByteData.sublistView(chunkWithHeader, 0, 4).getUint32(0);
      final tag = Uint8List.sublistView(chunkWithHeader, 4, 20);
      final cipherData = Uint8List.sublistView(chunkWithHeader, 20);

      // Derive the nonce for this chunk index
      final chunkNonce =
          _crypto.deriveChunkNonce(_receiverBaseNonce!, chunkIndex);

      // Decrypt immediately — only ~16KB in RAM
      try {
        final decrypted = await _crypto.decryptChunkAesGcm(
          ciphertext: cipherData,
          key: _receiverAesKey!,
          nonce: chunkNonce,
          tag: tag,
        );

        // Write decrypted bytes to disk immediately — then forget them
        _tempFileSink!.add(decrypted);
        _receivedChunkCount++;
      } catch (e) {
        // GCM tag mismatch on this chunk — tamper detected
        // Close the temp file and clean up
        await _tempFileSink?.close();
        _tempFileSink = null;
        throw TamperDetectedException(
          "CRITICAL: GCM authentication failed on chunk $chunkIndex. "
          "The file was tampered with in transit.",
        );
      }
    });
  }

  /// Called when all chunks have arrived.
  /// Closes the temp file, verifies the Ed25519 signature by hashing
  /// the decrypted file from disk, then moves it to Downloads.
  ///
  /// Memory usage: ~64KB (for the streaming hash).
  @override
  Future<String> finalizeReceive() async {
    if (_pendingMetadata == null || _tempFilePath == null) {
      throw Exception("No pending transfer metadata.");
    }

    final meta = _pendingMetadata!;

    // ── Close the temp file ───────────────────────────────────
    await _tempFileSink?.flush();
    await _tempFileSink?.close();
    _tempFileSink = null;

    // ── Verify chunk count ────────────────────────────────────
    final expectedChunkCount = meta['chunk_count'] as int;
    if (_receivedChunkCount < expectedChunkCount) {
      // Clean up temp file on failure
      try {
        await File(_tempFilePath!).delete();
      } catch (_) {}

      throw Exception(
        "Missing file chunks. Expected $expectedChunkCount, "
        "received $_receivedChunkCount.",
      );
    }

    // ── Hash the decrypted temp file (streaming, ~64KB RAM) ───
    final decryptedHashHex =
        await _crypto.computeTempFileHashStreaming(_tempFilePath!);

    // ── Rebuild the transfer payload from the hash ────────────
    final signedSenderId = meta['sender_peer'] as String;
    final timestamp = meta['timestamp'] as String;
    final rebuiltPayload = _crypto.buildTransferPayloadFromHash(
      fileHashHex: decryptedHashHex,
      senderId: signedSenderId,
      timestamp: timestamp,
    );

    // ── Verify sender's Ed25519 signature ─────────────────────
    final signatureBytes = base64Decode(meta['sender_signature'] as String);
    final senderUserId = meta['sender_id'] as String;
    final senderKeys = await _signaling.fetchReceiverKeys(senderUserId);
    final senderPublicKeyBytes =
        base64Decode(senderKeys['ed25519_public_key'] as String);

    final isValid = await _crypto.verifySignature(
      payload: rebuiltPayload,
      signature: signatureBytes,
      publicKeyBytes: senderPublicKeyBytes,
    );

    if (!isValid) {
      // Clean up temp file on failure
      try {
        await File(_tempFilePath!).delete();
      } catch (_) {}

      throw ImpersonationDetectedException(
        "CRITICAL: Ed25519 signature verification failed. "
        "The sender's identity could not be verified. Transfer blocked.",
      );
    }

    // ── All checks passed — move temp file to Downloads ───────
    final fileName = meta['file_name'] as String;
    final savedPath =
        await _localDataSource.saveFileFromPath(_tempFilePath!, fileName);

    // Notify the server that transfer completed
    _signaling.sendSignal({
      'type': 'transfer_complete',
      'transfer_id': meta['transfer_id'],
    });

    // Clear state
    _clearReceiverState();

    return savedPath;
  }

  // ═══════════════════════════════════════════════════════════════
  //  Helper: Parse RSA public key from PEM string
  // ═══════════════════════════════════════════════════════════════

  /// Reverse of CryptographyService.encodeRSAPublicKeyToPem.
  /// Takes the PEM string from the server and reconstructs the
  /// RSAPublicKey object so we can use it for OAEP encryption.
  RSAPublicKey _parseRsaPublicKeyFromPem(String pem) {
    // Strip PEM headers and decode Base64
    final lines = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('\n', '');
    final bytes = base64Decode(lines);

    // Parse ASN.1 DER structure: SEQUENCE { INTEGER(n), INTEGER(e) }
    final asn1Parser = ASN1Parser(Uint8List.fromList(bytes));
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;
    final modulus = (topLevelSeq.elements![0] as ASN1Integer).integer!;
    final exponent = (topLevelSeq.elements![1] as ASN1Integer).integer!;

    return RSAPublicKey(modulus, exponent);
  }

  /// Resets all receiver-side state.
  void _clearReceiverState() {
    _pendingMetadata = null;
    _activeTransferId = null;
    _receiverAesKey = null;
    _receiverBaseNonce = null;
    _receivedChunkCount = 0;
    _tempFilePath = null;
    _tempFileSink = null;
    _chunkSubscription?.cancel();
    _chunkSubscription = null;
  }

  @override
  Future<void> close() async {
    // Close any open temp file
    await _tempFileSink?.close();

    // Delete temp file if it exists
    if (_tempFilePath != null) {
      try {
        await File(_tempFilePath!).delete();
      } catch (_) {}
    }

    _clearReceiverState();
    await _webRtc.dispose();
    _signaling.disconnect();
  }
}

// ═══════════════════════════════════════════════════════════════
//  Custom exceptions for security failures
// ═══════════════════════════════════════════════════════════════

/// Thrown when the GCM authentication tag doesn't match.
/// This means the encrypted file was modified after encryption —
/// either in transit or by a man-in-the-middle.
class TamperDetectedException implements Exception {
  final String message;
  TamperDetectedException(this.message);
  @override
  String toString() => message;
}

/// Thrown when the Ed25519 signature verification fails.
/// This means the file was NOT sent by the claimed sender —
/// someone is impersonating them.
class ImpersonationDetectedException implements Exception {
  final String message;
  ImpersonationDetectedException(this.message);
  @override
  String toString() => message;
}
