import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pointycastle/export.dart' show RSAPublicKey;
import 'package:securevault/Data/DataSource/CryptographyService.dart';
import 'package:securevault/Data/DataSource/KeyGeneration.dart';
import 'package:securevault/Data/DataSource/WebRtcService.dart';
import 'package:securevault/Data/DataSource/WebSocketService.dart';
import 'package:securevault/Data/DataSource/file_transfer_local_data_source.dart';
import 'package:securevault/Data/Repositories/FileTransferRepository.dart';
import 'package:securevault/Presentation/BlocFile/RoomBloc/bloc/room_bloc.dart';
import 'package:securevault/Presentation/BlocFile/RoomBloc/bloc/room_event.dart';
import 'package:securevault/Presentation/BlocFile/RoomBloc/bloc/room_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────────────────────────────────────

class _T {
  // Core palette
  static const black = Color(0xFF0A0A0A);
  static const white = Color(0xFFFFFFFF);

  // Grays
  static const gray50 = Color(0xFFF9F9F9);
  static const gray100 = Color(0xFFF2F2F2);
  static const gray200 = Color(0xFFE5E5E5);
  static const gray400 = Color(0xFFA3A3A3);
  static const gray600 = Color(0xFF737373);
  static const gray800 = Color(0xFF262626);

  // Greens (success / connected)
  static const green50 = Color(0xFFF0FDF4);
  static const green100 = Color(0xFFDCFCE7);
  static const green200 = Color(0xFFBBF7D0);
  static const green500 = Color(0xFF22C55E);
  static const green600 = Color(0xFF16A34A);
  static const green700 = Color(0xFF15803D);

  // Blues (info)
  static const blue50 = Color(0xFFEFF6FF);
  static const blue100 = Color(0xFFDBEAFE);
  static const blue600 = Color(0xFF2563EB);

  // Reds / Oranges (alerts)
  static const red50 = Color(0xFFFFF1F2);
  static const red100 = Color(0xFFFFE4E6);
  static const red600 = Color(0xFFDC2626);
  static const orange50 = Color(0xFFFFF7ED);
  static const orange100 = Color(0xFFFFEDD5);
  static const orange600 = Color(0xFFEA580C);

  // Purples (receiving)
  static const purple50 = Color(0xFFFAF5FF);
  static const purple600 = Color(0xFF9333EA);

  // Typography scale
  static const h1 = TextStyle(
      fontSize: 28, fontWeight: FontWeight.w700, color: black, height: 1.2);
  static const h2 = TextStyle(
      fontSize: 20, fontWeight: FontWeight.w600, color: black, height: 1.3);
  static const h3 = TextStyle(
      fontSize: 16, fontWeight: FontWeight.w600, color: black, height: 1.4);
  static const bodyLg =
      TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: black);
  static const bodySm = TextStyle(
      fontSize: 13, fontWeight: FontWeight.w400, color: gray600, height: 1.5);
  static const label = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: gray400,
      letterSpacing: 0.5);

  // Radius
  static const r8 = BorderRadius.all(Radius.circular(8));
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r16 = BorderRadius.all(Radius.circular(16));
  static const r24 = BorderRadius.all(Radius.circular(24));

  // Spacing
  static const p16 = EdgeInsets.all(16);
  static const p20 = EdgeInsets.all(20);
  static const p24 = EdgeInsets.all(24);
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsets? padding;

  const _SectionCard({
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: padding ?? _T.p20,
      decoration: BoxDecoration(
        color: backgroundColor ?? _T.white,
        borderRadius: _T.r16,
        border: Border.all(
          color: borderColor ?? _T.gray200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const _PrimaryButton({
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _T.black,
          foregroundColor: _T.white,
          disabledBackgroundColor: _T.gray200,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: _T.r12),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _T.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}

class _OutlinedBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const _OutlinedBtn({required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _T.black,
          side: const BorderSide(color: _T.gray200, width: 1.5),
          shape: const RoundedRectangleBorder(borderRadius: _T.r12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? suffix;

  const _InputField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: _T.bodyLg,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _T.bodyLg.copyWith(color: _T.gray400),
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: _T.gray50,
        enabledBorder: OutlineInputBorder(
          borderRadius: _T.r12,
          borderSide: const BorderSide(color: _T.gray200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _T.r12,
          borderSide: const BorderSide(color: _T.black, width: 1.5),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  final bool pulse;

  const _StatusDot({required this.color, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: pulse
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 6,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Page
// ─────────────────────────────────────────────────────────────────────────────

class SharePageFirst extends StatefulWidget {
  const SharePageFirst({super.key});

  @override
  State<SharePageFirst> createState() => SharePageFirstState();
}

class SharePageFirstState extends State<SharePageFirst> {
  final _roomNameController = TextEditingController();
  final _roomIdController = TextEditingController();
  final _passcodeController = TextEditingController();
  bool _passcodeVisible = false;
  bool _isInitializing = true;

  // ── NEW: tracks the gap between "file picked" and "transfer started" ──
  bool _isSending = false;

  late final WebSocketService _wsService;
  late final WebRtcService _webRtcService;
  late final CryptographyService _crypto;
  late final FileTransferRepositoryImpl _transferRepo;
  late final RoomBloc _roomBloc;

  @override
  void initState() {
    super.initState();
    _wsService = WebSocketService();
    _webRtcService = WebRtcService(_wsService);
    _crypto = CryptographyService();
    _transferRepo = FileTransferRepositoryImpl(
      crypto: _crypto,
      signaling: _wsService,
      webRtc: _webRtcService,
      localDataSource: FileTransferLocalDataSource(),
    );
    _roomBloc = RoomBloc(
      webSocketService: _wsService,
      webRtcService: _webRtcService,
      transferRepo: _transferRepo,
    );
    _initializeKeys();
  }

  Future<void> _initializeKeys() async {
    final edPriv = await _crypto.loadEd25519PrivKey();
    final rsaPriv = await _crypto.loadRSAPrivateKey();

    String rsaPublicKeyPem;
    String ed25519PublicKeyBase64;

    if (edPriv == null || rsaPriv == null) {
      try {
        final rsaPair = await generateRSAKeyPair();
        final edPair = await generateEd25519KeyPair();
        final edPrivBytes = await edPair.extractPrivateKeyBytes();
        final edPubBytes = (await edPair.extractPublicKey()).bytes;

        rsaPublicKeyPem = _crypto.encodeRSAPublicKeyToPem(rsaPair.publicKey);
        ed25519PublicKeyBase64 = base64Encode(edPubBytes);

        await _crypto.savePrivateKeys(
          rsaPriv: rsaPair.privateKey,
          ed25591priv: edPrivBytes,
        );
        await _crypto.savePublicKeys(
          rsaPublicKeyPem: rsaPublicKeyPem,
          ed25519PublicKeyBase64: ed25519PublicKeyBase64,
        );
      } catch (e) {
        debugPrint('Error generating keys: $e');
        return;
      }
    } else {
      final storedRsaPem = await _crypto.loadRSAPublicKeyPem();
      final storedEdPub = await _crypto.loadEd25519PublicKeyBase64();

      if (storedRsaPem != null && storedEdPub != null) {
        rsaPublicKeyPem = storedRsaPem;
        ed25519PublicKeyBase64 = storedEdPub;
      } else {
        final edAlgorithm = crypto.Ed25519();
        final edKeyPair = await edAlgorithm.newKeyPairFromSeed(edPriv);
        final edPubBytes = (await edKeyPair.extractPublicKey()).bytes;

        final rsaPubKey = RSAPublicKey(rsaPriv.n!, BigInt.from(65537));
        rsaPublicKeyPem = _crypto.encodeRSAPublicKeyToPem(rsaPubKey);
        ed25519PublicKeyBase64 = base64Encode(edPubBytes);

        await _crypto.savePublicKeys(
          rsaPublicKeyPem: rsaPublicKeyPem,
          ed25519PublicKeyBase64: ed25519PublicKeyBase64,
        );
      }
    }

    try {
      await _wsService.exchangeKeys(
        rsaPublicKeyPem: rsaPublicKeyPem,
        ed25519PublicKeyBase64: ed25519PublicKeyBase64,
      );
      debugPrint('Public keys uploaded to server successfully');
    } catch (e) {
      debugPrint('Error uploading keys to server: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _roomIdController.dispose();
    _passcodeController.dispose();
    _roomBloc.close();
    super.dispose();
  }

  /// Whether we're inside an active room session.
  bool _isInSession(RoomState state) {
    return state is RoomCreated ||
        state is RoomJoined ||
        state is PeerConnected ||
        state is ReadyToTransfer ||
        state is TransferInProgress ||
        state is TransferMetadataReceived ||
        state is TransferSuccess ||
        state is TransferTampered ||
        state is TransferImpersonation;
  }

  /// Whether a peer is connected and we can send files.
  bool get _hasPeer => _roomBloc.connectedPeerId != null;

  /// Whether the current state allows picking a new file to send.
  bool _canSendFile(RoomState state) {
    return _hasPeer &&
        state is! TransferInProgress &&
        state is! TransferMetadataReceived &&
        state is! RoomLoading;
  }

  // ───────────────────────────────────────────────────────────────
  // Build
  // ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _roomBloc,
      child: BlocConsumer<RoomBloc, RoomState>(
        listener: _handleStateChanges,
        builder: (context, state) {
          final inSession = _isInSession(state);
          // Also count RoomError as in-session if we still have a peer
          final showSessionUI = inSession || (state is RoomError && _hasPeer);

          return Stack(
            children: [
              // ── Main scrollable content ──
              Container(
                color: _T.gray50,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 20),
                            _buildEncryptionBadge(),
                            const SizedBox(height: 28),

                            // ── Lobby: Create / Join (hidden once in a session) ──
                            if (!showSessionUI) ...[
                              _buildCreateRoomCard(state),
                              const SizedBox(height: 14),
                              _buildJoinRoomCard(state),
                            ],

                            // ── Active session UI ──
                            if (showSessionUI) ...[
                              // Session header with peer info + disconnect
                              _buildSessionHeader(state),

                              // Waiting for peer
                              _AnimatedSlide(
                                visible: state is RoomCreated,
                                child: state is RoomCreated
                                    ? _buildRoomCreatedCard(state)
                                    : const SizedBox.shrink(),
                              ),
                              _AnimatedSlide(
                                visible: state is RoomJoined,
                                child: state is RoomJoined
                                    ? _buildRoomJoinedCard(state)
                                    : const SizedBox.shrink(),
                              ),

                              // Peer connected notification
                              _AnimatedSlide(
                                visible: state is PeerConnected,
                                child: state is PeerConnected
                                    ? _buildPeerConnectedCard(state)
                                    : const SizedBox.shrink(),
                              ),

                              // Send file card — visible whenever peer is connected
                              _AnimatedSlide(
                                visible: _canSendFile(state),
                                child: _buildSendFileCard(state),
                              ),

                              // Transfer progress
                              _AnimatedSlide(
                                visible: state is TransferInProgress,
                                child: state is TransferInProgress
                                    ? _buildProgressCard(state)
                                    : const SizedBox.shrink(),
                              ),
                              _AnimatedSlide(
                                visible: state is TransferMetadataReceived,
                                child: state is TransferMetadataReceived
                                    ? _buildReceivingCard(state)
                                    : const SizedBox.shrink(),
                              ),

                              // Transfer result cards
                              _AnimatedSlide(
                                visible: state is TransferSuccess,
                                child: state is TransferSuccess
                                    ? _buildSuccessCard(state)
                                    : const SizedBox.shrink(),
                              ),
                              _AnimatedSlide(
                                visible: state is TransferTampered,
                                child: state is TransferTampered
                                    ? _buildAlertCard(
                                        icon: Icons.warning_rounded,
                                        title: 'File tampered in transit',
                                        message:
                                            'AES-GCM authentication tag mismatch. The file was modified and the transfer has been blocked.',
                                        bg: _T.red50,
                                        border: _T.red100,
                                        iconColor: _T.red600,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              _AnimatedSlide(
                                visible: state is TransferImpersonation,
                                child: state is TransferImpersonation
                                    ? _buildAlertCard(
                                        icon: Icons.person_off_rounded,
                                        title: 'Sender identity not verified',
                                        message:
                                            'Ed25519 signature verification failed. The sender could not be authenticated.',
                                        bg: _T.orange50,
                                        border: _T.orange100,
                                        iconColor: _T.orange600,
                                      )
                                    : const SizedBox.shrink(),
                              ),

                              // Error card
                              _AnimatedSlide(
                                visible: state is RoomError,
                                child: state is RoomError
                                    ? _buildErrorCard(state)
                                    : const SizedBox.shrink(),
                              ),

                              // "Send another" / "Continue" after terminal states
                              _AnimatedSlide(
                                visible: state is TransferSuccess ||
                                    state is TransferTampered ||
                                    state is TransferImpersonation ||
                                    (state is RoomError && _hasPeer),
                                child: _buildContinueCard(),
                              ),

                              // Transfer history
                              if (_roomBloc.transferHistory.isNotEmpty)
                                _buildTransferHistory(),
                            ],

                            // Error when NOT in session (e.g. failed to create room)
                            if (!showSessionUI) ...[
                              _AnimatedSlide(
                                visible: state is RoomError,
                                child: state is RoomError
                                    ? _buildErrorCard(state)
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Overlay 1: Key initialisation ──
              if (_isInitializing)
                Container(
                  color: Colors.black.withOpacity(0.4),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: _T.white),
                        SizedBox(height: 20),
                        Text(
                          'Initializing Secure Session...',
                          style: TextStyle(
                            color: _T.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Generating E2EE encryption keys',
                          style: TextStyle(
                            color: _T.gray400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Overlay 2: File picked → transfer starting ──
              if (_isSending)
                Container(
                  color: Colors.black.withOpacity(0.4),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: _T.white),
                        SizedBox(height: 20),
                        Text(
                          'Preparing Secure Transfer…',
                          style: TextStyle(
                            color: _T.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Encrypting file before sending',
                          style: TextStyle(
                            color: _T.gray400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Header
  // ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: _T.black,
                borderRadius: _T.r8,
              ),
              child: const Icon(Icons.lock_rounded, color: _T.white, size: 18),
            ),
            const SizedBox(width: 12),
            const Text('SecureShare', style: _T.h2),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'End-to-end encrypted peer-to-peer file sharing',
          style: _T.bodySm,
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Encryption Badge
  // ───────────────────────────────────────────────────────────────

  Widget _buildEncryptionBadge() {
    return _SectionCard(
      backgroundColor: _T.green50,
      borderColor: _T.green200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _T.green600,
              borderRadius: _T.r8,
            ),
            child: const Icon(Icons.shield_rounded, color: _T.white, size: 16),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Military-grade encryption active',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _T.green700)),
                SizedBox(height: 2),
                Text(
                  'AES-256-GCM · RSA-4096 key exchange · Ed25519 signatures',
                  style: TextStyle(fontSize: 11, color: _T.green600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Create Room
  // ───────────────────────────────────────────────────────────────

  Widget _buildCreateRoomCard(RoomState state) {
    final isLoading = state is RoomLoading;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: Icons.add_circle_rounded,
            title: 'Create a room',
            subtitle: 'Share the passcode with your peer',
          ),
          const SizedBox(height: 16),
          _InputField(
            controller: _roomNameController,
            hint: 'Room name (e.g. "Project Files")',
          ),
          const SizedBox(height: 12),
          _PrimaryButton(
            label: 'Create secure room',
            icon: Icons.lock_outline_rounded,
            loading: isLoading,
            onPressed: () {
              final name = _roomNameController.text.trim();
              if (name.isEmpty) return;
              _roomBloc.add(CreateRoom(name));
            },
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Join Room
  // ───────────────────────────────────────────────────────────────

  Widget _buildJoinRoomCard(RoomState state) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: Icons.login_rounded,
            title: 'Join a room',
            subtitle: 'Enter the room ID and passcode',
          ),
          const SizedBox(height: 16),
          _InputField(
            controller: _roomIdController,
            hint: 'Room ID',
          ),
          const SizedBox(height: 10),
          StatefulBuilder(
            builder: (ctx, setLocal) => _InputField(
              controller: _passcodeController,
              hint: 'Passcode',
              obscure: !_passcodeVisible,
              suffix: IconButton(
                icon: Icon(
                  _passcodeVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: _T.gray400,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _passcodeVisible = !_passcodeVisible);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          _OutlinedBtn(
            label: 'Join secure room',
            icon: Icons.key_rounded,
            onPressed: () {
              final id = _roomIdController.text.trim();
              final pass = _passcodeController.text.trim();
              if (id.isEmpty || pass.isEmpty) return;
              _roomBloc.add(JoinRoom(roomId: id, passcode: pass));
            },
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Room Created Info
  // ───────────────────────────────────────────────────────────────

  Widget _buildRoomCreatedCard(RoomCreated state) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _SectionCard(
        backgroundColor: _T.green50,
        borderColor: _T.green200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusDot(color: _T.green500, pulse: true),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.roomName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _T.green700),
                  ),
                ),
                _Pill(label: 'Waiting for peer', color: _T.green600),
              ],
            ),
            const SizedBox(height: 16),
            const Text('PASSCODE', style: _T.label),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _T.white,
                borderRadius: _T.r12,
                border: Border.all(color: _T.green200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.passcode,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: _T.green700,
                        letterSpacing: 8,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  _IconBtn(
                    icon: Icons.copy_rounded,
                    tooltip: 'Copy room info',
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(
                            text:
                                'Room ID: ${state.roomId}\nPasscode: ${state.passcode}'),
                      );
                      _toast('Room ID & passcode copied');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: _T.green600),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Share this passcode with the recipient to establish a secure connection.',
                    style: TextStyle(fontSize: 12, color: _T.green700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Room Joined
  // ───────────────────────────────────────────────────────────────

  Widget _buildRoomJoinedCard(RoomJoined state) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _SectionCard(
        backgroundColor: _T.blue50,
        borderColor: _T.blue100,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            _StatusDot(color: _T.blue600, pulse: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connected to "${state.roomName}"',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _T.blue600),
                  ),
                  const SizedBox(height: 2),
                  const Text('Establishing encrypted channel…',
                      style: TextStyle(fontSize: 12, color: _T.blue600)),
                ],
              ),
            ),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _T.blue600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Peer Connected
  // ───────────────────────────────────────────────────────────────

  Widget _buildPeerConnectedCard(PeerConnected state) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _SectionCard(
        backgroundColor: _T.green50,
        borderColor: _T.green200,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            _Avatar(name: state.username),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.username,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _T.green700),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _StatusDot(color: _T.green500, pulse: true),
                      const SizedBox(width: 5),
                      const Expanded(
                        child: Text('Peer connected · ready to transfer',
                            style: TextStyle(fontSize: 12, color: _T.green600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.wifi_rounded, color: _T.green500, size: 22),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Send File
  // ───────────────────────────────────────────────────────────────

  Widget _buildSendFileCard(RoomState state) {
    final busy = state is TransferInProgress;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(
              icon: Icons.upload_file_rounded,
              title: 'Send a file',
              subtitle: 'Files are encrypted before leaving your device',
            ),
            const SizedBox(height: 16),
            _PrimaryButton(
              label: busy ? 'Transfer in progress…' : 'Choose file to send',
              icon: Icons.attach_file_rounded,
              loading: false,
              onPressed: busy ? null : _pickAndSendFile,
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Transfer in Progress
  // ───────────────────────────────────────────────────────────────

  Widget _buildProgressCard(TransferInProgress state) {
    final pct = (state.progress * 100).toInt();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _T.black)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.fileName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _T.black),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$pct%',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _T.black),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: _T.r24,
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 6,
                backgroundColor: _T.gray100,
                valueColor: const AlwaysStoppedAnimation(_T.black),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Encrypting and sending securely…',
              style: _T.bodySm,
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Receiving Metadata
  // ───────────────────────────────────────────────────────────────

  Widget _buildReceivingCard(TransferMetadataReceived state) {
    final kb = (state.fileSize / 1024).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _SectionCard(
        backgroundColor: _T.purple50,
        borderColor: const Color(0xFFE9D5FF),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _T.purple600.withOpacity(0.1),
                borderRadius: _T.r8,
              ),
              child:
                  Icon(Icons.download_rounded, color: _T.purple600, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.fileName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _T.black),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('$kb KB · ${state.chunkCount} chunks incoming',
                      style:
                          const TextStyle(fontSize: 12, color: _T.purple600)),
                ],
              ),
            ),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _T.purple600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Success
  // ───────────────────────────────────────────────────────────────

  Widget _buildSuccessCard(TransferSuccess state) {
    final isSender = state.savedPath.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _SectionCard(
        backgroundColor: _T.green50,
        borderColor: _T.green200,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: _T.green600,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: _T.white, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              isSender ? 'File sent successfully' : 'File received',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _T.green700),
            ),
            const SizedBox(height: 4),
            Text(
              state.fileName,
              style: const TextStyle(fontSize: 13, color: _T.green600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _VerifiedChip(label: 'GCM tag verified'),
                SizedBox(width: 8),
                _VerifiedChip(label: 'Signature verified'),
              ],
            ),
            if (!isSender) ...[
              const SizedBox(height: 16),
              _PrimaryButton(
                label: 'Open file',
                icon: Icons.open_in_new_rounded,
                onPressed: () => OpenFilex.open(state.savedPath),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Alert Card (Tamper / Impersonation)
  // ───────────────────────────────────────────────────────────────

  Widget _buildAlertCard({
    required IconData icon,
    required String title,
    required String message,
    required Color bg,
    required Color border,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _SectionCard(
        backgroundColor: bg,
        borderColor: border,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: _T.r8,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: iconColor)),
                  const SizedBox(height: 4),
                  Text(message,
                      style: TextStyle(
                          fontSize: 13, color: iconColor.withOpacity(0.8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Error
  // ───────────────────────────────────────────────────────────────

  Widget _buildErrorCard(RoomError state) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _SectionCard(
        backgroundColor: _T.red50,
        borderColor: _T.red100,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.error_rounded, color: _T.red600, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(state.message,
                  style: const TextStyle(fontSize: 13, color: _T.red600)),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Session Header (shown when in active room)
  // ───────────────────────────────────────────────────────────────

  Widget _buildSessionHeader(RoomState state) {
    final peerName = _roomBloc.connectedUsername;
    final roomName = _roomBloc.currentRoomName;
    final hasPeerNow = _hasPeer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _SectionCard(
        backgroundColor: hasPeerNow ? _T.green50 : _T.blue50,
        borderColor: hasPeerNow ? _T.green200 : _T.blue100,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasPeerNow ? _T.green600 : _T.blue600,
                borderRadius: _T.r8,
              ),
              child: Icon(
                hasPeerNow ? Icons.link_rounded : Icons.meeting_room_rounded,
                color: _T.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roomName.isNotEmpty ? roomName : 'Secure Room',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasPeerNow ? _T.green700 : _T.blue600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasPeerNow ? 'Connected to $peerName' : 'Waiting for peer…',
                    style: TextStyle(
                        fontSize: 12,
                        color: hasPeerNow ? _T.green600 : _T.blue600),
                  ),
                ],
              ),
            ),
            if (hasPeerNow) _StatusDot(color: _T.green500, pulse: true),
            const SizedBox(width: 8),
            _IconBtn(
              icon: Icons.logout_rounded,
              tooltip: 'Leave room',
              onTap: () => _roomBloc.add(const LeaveRoom()),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Continue / Send Another Card
  // ───────────────────────────────────────────────────────────────

  Widget _buildContinueCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _PrimaryButton(
        label: 'Send another file',
        icon: Icons.add_rounded,
        onPressed: () {
          _roomBloc.add(const ResetForNextTransfer());
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Transfer History
  // ───────────────────────────────────────────────────────────────

  Widget _buildTransferHistory() {
    final history = _roomBloc.transferHistory;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 16, color: _T.gray400),
              const SizedBox(width: 6),
              Text(
                'SESSION HISTORY',
                style: _T.label.copyWith(letterSpacing: 1),
              ),
              const Spacer(),
              Text(
                '${history.length} transfer${history.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 11, color: _T.gray400),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...history.reversed.map((record) => _buildHistoryItem(record)),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(TransferRecord record) {
    final IconData icon;
    final Color color;
    final String subtitle;

    switch (record.result) {
      case TransferResult.success:
        icon = Icons.check_circle_rounded;
        color = _T.green600;
        subtitle = record.isSender ? 'Sent' : 'Received';
        break;
      case TransferResult.tampered:
        icon = Icons.warning_rounded;
        color = _T.red600;
        subtitle = 'Tamper detected';
        break;
      case TransferResult.impersonation:
        icon = Icons.person_off_rounded;
        color = _T.orange600;
        subtitle = 'Signature failed';
        break;
      case TransferResult.error:
        icon = Icons.error_rounded;
        color = _T.red600;
        subtitle = 'Failed';
        break;
    }

    final time =
        '${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _T.white,
          borderRadius: _T.r12,
          border: Border.all(color: _T.gray200),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.fileName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _T.black),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: color)),
                ],
              ),
            ),
            Text(time, style: const TextStyle(fontSize: 11, color: _T.gray400)),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // State Listener
  // ───────────────────────────────────────────────────────────────

  void _handleStateChanges(BuildContext context, RoomState state) {
    // ── Dismiss the sending overlay as soon as the bloc reacts ──
    if (state is TransferInProgress ||
        state is TransferSuccess ||
        state is TransferTampered ||
        state is TransferImpersonation ||
        state is RoomError) {
      if (_isSending) setState(() => _isSending = false);
    }

    if (state is TransferTampered) {
      _showSecurityDialog(
        context,
        icon: Icons.warning_rounded,
        title: 'Transfer blocked',
        message: state.message,
        color: _T.red600,
      );
    } else if (state is TransferImpersonation) {
      _showSecurityDialog(
        context,
        icon: Icons.person_off_rounded,
        title: 'Identity not verified',
        message: state.message,
        color: _T.orange600,
      );
    } else if (state is TransferSuccess) {
      _showSuccessDialog(context, state);
    } else if (state is RoomDisconnected) {
      _toast('Disconnected from room');
    }
  }

  // ───────────────────────────────────────────────────────────────
  // Dialogs
  // ───────────────────────────────────────────────────────────────

  void _showSuccessDialog(BuildContext context, TransferSuccess state) {
    final isSender = state.savedPath.isEmpty;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: _T.green600,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.check_rounded, color: _T.white, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                isSender ? 'File sent!' : 'File received!',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                state.fileName,
                style: _T.bodySm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (!isSender) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          OpenFilex.open(state.savedPath);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _T.gray200),
                          shape: const RoundedRectangleBorder(
                              borderRadius: _T.r12),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Open file'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _roomBloc.add(const ResetForNextTransfer());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _T.black,
                          foregroundColor: _T.white,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                              borderRadius: _T.r12),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Send another'),
                      ),
                    ),
                  ],
                ),
              ],
              if (isSender) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _roomBloc.add(const ResetForNextTransfer());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _T.black,
                      foregroundColor: _T.white,
                      elevation: 0,
                      shape: const RoundedRectangleBorder(borderRadius: _T.r12),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Send another file'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSecurityDialog(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 8),
              Text(message, style: _T.bodySm, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _roomBloc.add(const ResetForNextTransfer());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _T.black,
                    foregroundColor: _T.white,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(borderRadius: _T.r12),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Understood'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Actions
  // ───────────────────────────────────────────────────────────────

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final peerId = _roomBloc.connectedPeerId;
    final userId = _roomBloc.connectedUserId;

    if (peerId == null || userId == null) {
      if (mounted) _toast('Connection lost. Please reconnect.');
      return;
    }

    // Show blocking overlay while encryption + handoff happens
    setState(() => _isSending = true);

    _roomBloc.add(InitiateTransfer(
      file: File(result.files.single.path!),
      receiverPeerId: peerId,
      receiverUserId: userId,
    ));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _T.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small Reusable Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CardHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: _T.gray100,
            borderRadius: _T.r8,
          ),
          child: Icon(icon, color: _T.black, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: _T.h3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: _T.bodySm,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;

  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        color: _T.green200,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(initials,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: _T.green700)),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: _T.r24,
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _VerifiedChip extends StatelessWidget {
  final String label;

  const _VerifiedChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _T.green100,
        borderRadius: _T.r24,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 12, color: _T.green700),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _T.green700)),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: _T.r8,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: _T.gray100,
            borderRadius: _T.r8,
          ),
          child: Icon(icon, size: 18, color: _T.gray600),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Slide-in Widget
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedSlide extends StatelessWidget {
  final bool visible;
  final Widget child;

  const _AnimatedSlide({required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: visible ? child : const SizedBox.shrink(),
      ),
    );
  }
}
