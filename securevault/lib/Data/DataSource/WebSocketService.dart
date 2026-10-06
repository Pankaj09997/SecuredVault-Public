import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:securevault/Data/DataSource/BaseUrl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Signaling layer for WebRTC file sharing.
///
/// This service is intentionally "dumb" — it only shuttles messages between
/// the Flutter client and the Django backend. It does NOT know what an SDP
/// offer is or how to encrypt. That intelligence lives in WebRtcService and
/// FileTransferRepository.
///
/// Responsibilities:
///   1. REST calls to create / join rooms (Django Room model)
///   2. Persistent WebSocket connection for real-time signaling
///   3. Exposing incoming messages as a broadcast stream
///   4. REST calls for public-key exchange (E2EE setup)
class WebSocketService {
  // ── Configuration ─────────────────────────────────────────────
  // Same IP as AuthService.baseUrl — your Django dev server
  final String _httpBase = Baseurl.baseUrl;
  // WebSocket URL matches api/routing.py:
  //   re_path(r'^ws/signaling/(?P<room_id>[^/]+)/$', ...)
  final String _wsBase = "${Baseurl.baseUrl}/ws/signaling";

// Webcoket channel is needed to pass the data
  WebSocketChannel? _channel;
  // broadcast() allows multiple listeners (BLoC + WebRtcService)
  // to react to the same incoming messages simultaneously as i am building user can have 10 members in one room.
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Public stream — the BLoC and WebRtcService both listen to this.
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Whether the WebSocket is currently connected.
  bool get isConnected => _channel != null;

  // ── Auth helper ───────────────────────────────────────────────
  // Reads the JWT stored during login — same key your AuthService uses.
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      throw Exception("Auth token not found. Please login again.");
    }
    return token;
  }

  // ═══════════════════════════════════════════════════════════════
  //  REST: Room Management
  // ═══════════════════════════════════════════════════════════════

  /// Create a new room. Django auto-generates a 6-digit passcode.
  /// Returns the full room JSON including room_id and passcode.
  ///
  /// Maps to → POST /api/roomListCreateView/
  /// Django view → RoomListCreateView.post()
  Future<Map<String, dynamic>> createRoom(String name) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse("$_httpBase/roomListCreateView/"),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception("Failed to create room: ${response.body}");
  }

  /// Join an existing room using room_id + passcode.
  /// The passcode is shared out-of-band (e.g. the sender tells the
  /// receiver verbally or via a separate message).
  ///
  /// Maps to → POST /api/roomJoinView/
  /// Django view → RoomJoinView.post()
  /// Django validates passcode, checks room capacity, creates a Peer record.
  Future<Map<String, dynamic>> joinRoom({
    required String roomId,
    required String passcode,
    required String peerId,
    String deviceName = 'Flutter Device',
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse("$_httpBase/roomJoinView/"),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'room_id': roomId,
        'passcode': passcode,
        'peer_id': peerId,
        'device_name': deviceName,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception("Failed to join room: ${response.body}");
  }

  // ═══════════════════════════════════════════════════════════════
  //  WebSocket: Real-time signaling
  // ═══════════════════════════════════════════════════════════════

  /// Opens a persistent WebSocket for real-time signaling.
  ///
  /// Token is passed as a query parameter because WebSocket connections
  /// don't support custom HTTP headers. Your JWTAuthMiddleware
  /// (jwtmiddleware.py) reads it from `?token=...` and sets scope['user'].
  ///
  /// Every JSON message from the server is decoded and pushed into
  /// the [messages] stream for the BLoC/WebRtcService to react to.
  Future<void> connectWebSocket(String roomId) async {
    final token = await _getToken();
    final uri = Uri.parse("$_wsBase/$roomId/?token=$token");
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (raw) {
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          _messageController.add(data);
        } catch (e) {
          _messageController.addError('Failed to parse message: $e');
        }
      },
      onError: (error) {
        _messageController.addError(error);
      },
      onDone: () {
        // Notify listeners that the connection dropped
        _messageController.add({'type': 'disconnected'});
      },
    );
  }

  /// Send a JSON message over the WebSocket.
  ///
  /// Used for: SDP offers, SDP answers, ICE candidates, file metadata,
  /// chunk acknowledgments, transfer completion — everything the
  /// SignalingConsumer.receive() method handles.
  void sendSignal(Map<String, dynamic> message) {
    if (_channel == null) {
      throw Exception("WebSocket not connected. Call connectWebSocket first.");
    }
    _channel!.sink.add(jsonEncode(message));
  }

  // ═══════════════════════════════════════════════════════════════
  //  REST: E2EE Public Key Exchange
  // ═══════════════════════════════════════════════════════════════

  /// Upload YOUR public keys to the server so other users can fetch them.
  /// Private keys NEVER leave the device — only public keys are stored.
  ///
  /// Maps to → POST /api/exchange-keys/
  /// Django view → PublicKeyExchangeView.post()
  Future<void> exchangeKeys({
    required String rsaPublicKeyPem,
    required String ed25519PublicKeyBase64,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse("$_httpBase/exchange-keys/"),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'rsa_public_key': rsaPublicKeyPem,
        'ed25519_public_key': ed25519PublicKeyBase64,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception("Key exchange failed: ${response.body}");
    }
  }

  /// Fetch another user's public keys by their user ID.
  /// You need the receiver's RSA public key to wrap the AES key for them.
  ///
  /// Maps to → GET /api/exchange-keys/?user_id=...
  /// Django view → PublicKeyExchangeView.get()
  Future<Map<String, dynamic>> fetchReceiverKeys(String userId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse("$_httpBase/exchange-keys/?user_id=$userId"),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception("Failed to fetch receiver keys: ${response.body}");
  }

  // ═══════════════════════════════════════════════════════════════
  //  Cleanup
  // ═══════════════════════════════════════════════════════════════

  /// Close the WebSocket connection cleanly.
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  /// Full cleanup — close WebSocket + close the stream controller.
  /// Call this when the service is permanently disposed.
  void dispose() {
    disconnect();
    _messageController.close();
  }
}
