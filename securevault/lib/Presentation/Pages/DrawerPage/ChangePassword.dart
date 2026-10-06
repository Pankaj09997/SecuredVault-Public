import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:securevault/Presentation/BlocFile/AuthBloc/bloc/auth_bloc.dart';
import 'package:securevault/Presentation/Pages/Base_Scaffold/baseScaffold.dart';

class _C {
  static const primary = Color(0xFF4361EE);
  static const primaryDk = Color(0xFF3A0CA3);
  static const success = Color(0xFF06D6A0);
  static const danger = Color(0xFFEF233C);
  static const warning = Color(0xFFF59E0B);
  static const bg = Color(0xFFF0F2F8);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A2E);
  static const muted = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const fieldBg = Color(0xFFF3F4F6);
  static const infoLight = Color(0xFFEEF2FF);
  static const infoBorder = Color(0xFFC7D2FE);
  static const infoText = Color(0xFF3730A3);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main widget
// ─────────────────────────────────────────────────────────────────────────────
class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword>
    with TickerProviderStateMixin {
  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  // Visibility toggles
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // Flow state
  bool _otpSent = false;
  bool _otpVerified = false;
  int _currentStep = 0; // 0 = verify, 1 = new password, 2 = success

  // Password strength
  double _strength = 0;
  String _strengthLabel = '';
  Color _strengthColor = _C.border;

  // Animation controllers
  late final AnimationController _stepCtrl;
  late final AnimationController _successCtrl;
  late final Animation<double> _successScale;
  late final Animation<double> _successFade;

  @override
  void initState() {
    super.initState();
    _stepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = CurvedAnimation(
      parent: _successCtrl,
      curve: Curves.elasticOut,
    );
    _successFade = CurvedAnimation(
      parent: _successCtrl,
      curve: Curves.easeIn,
    );
    _newPassCtrl.addListener(_evaluateStrength);
  }

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _otpCtrl.dispose();
    _stepCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  // ── Password strength evaluator ──────────────────────────────────────────
  void _evaluateStrength() {
    final v = _newPassCtrl.text;
    int score = 0;
    if (v.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(v)) score++;
    if (RegExp(r'[0-9]').hasMatch(v)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(v)) score++;

    setState(() {
      _strength = score / 4;
      switch (score) {
        case 0:
        case 1:
          _strengthLabel = 'Weak';
          _strengthColor = _C.danger;
          break;
        case 2:
          _strengthLabel = 'Fair';
          _strengthColor = _C.warning;
          break;
        case 3:
          _strengthLabel = 'Good';
          _strengthColor = _C.primary;
          break;
        case 4:
          _strengthLabel = 'Strong';
          _strengthColor = _C.success;
          break;
      }
    });
  }

  bool get _requirementMet => _strength == 1.0;

  // ── Step helpers ─────────────────────────────────────────────────────────
  void _sendOtp() {
    if (_currentPassCtrl.text.isEmpty) {
      _showSnack('Enter your current password first', isError: true);
      return;
    }
    context.read<AuthBloc>().add(RequestForPasswordChangeOtpEvent());
  }

  void _verifyAndProceed() {
    if (_otpCtrl.text.length != 6) {
      _showSnack('Enter the 6-digit OTP', isError: true);
      return;
    }
    setState(() {
      _otpVerified = true;
      _currentStep = 1;
    });
    _stepCtrl.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  void _submitPasswordChange() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
          ChangePasswordEvent(
            current_password: _currentPassCtrl.text.trim(),
            password: _newPassCtrl.text.trim(),
            password1: _confirmPassCtrl.text.trim(),
            otp_code: _otpCtrl.text.trim(),
          ),
        );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _C.danger : _C.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      showAppBar: false,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: _blocListener,
        builder: (context, state) {
          final loading = state is AuthLoading;

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Scaffold(
              backgroundColor: _C.bg,
              body: Column(
                children: [
                  _AppBarWidget(
                    step: _currentStep,
                    onBack: () {
                      if (_currentStep == 1) {
                        setState(() => _currentStep = 0);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, anim) => SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.05, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOut,
                        )),
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: _currentStep == 2
                          ? _SuccessScreen(
                              key: const ValueKey('success'),
                              scaleAnim: _successScale,
                              fadeAnim: _successFade,
                              onDone: () => Navigator.pop(context),
                            )
                          : _currentStep == 1
                              ? _NewPasswordStep(
                                  key: const ValueKey('step2'),
                                  formKey: _formKey,
                                  newPassCtrl: _newPassCtrl,
                                  confirmPassCtrl: _confirmPassCtrl,
                                  obscureNew: _obscureNew,
                                  obscureConfirm: _obscureConfirm,
                                  strength: _strength,
                                  strengthLabel: _strengthLabel,
                                  strengthColor: _strengthColor,
                                  requirementMet: _requirementMet,
                                  loading: loading,
                                  onToggleNew: () => setState(
                                      () => _obscureNew = !_obscureNew),
                                  onToggleConfirm: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm),
                                  onSubmit: _submitPasswordChange,
                                  currentPassCtrl: _currentPassCtrl,
                                )
                              : _VerifyStep(
                                  key: const ValueKey('step1'),
                                  currentPassCtrl: _currentPassCtrl,
                                  otpCtrl: _otpCtrl,
                                  obscureCurrent: _obscureCurrent,
                                  otpSent: _otpSent,
                                  otpVerified: _otpVerified,
                                  loading: loading,
                                  onToggleCurrent: () => setState(
                                      () => _obscureCurrent = !_obscureCurrent),
                                  onSendOtp: _sendOtp,
                                  onContinue: _verifyAndProceed,
                                ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _blocListener(BuildContext context, AuthState state) {
    if (state is AuthError) {
      _showSnack(state.message, isError: true);
    } else if (state is RequestForPasswordChangeOtpState) {
      setState(() => _otpSent = true);
      _showSnack('OTP sent to your registered email');
      HapticFeedback.mediumImpact();
    } else if (state is ChangePasswordSucessState) {
      setState(() => _currentStep = 2);
      _successCtrl.forward();
      HapticFeedback.heavyImpact();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom AppBar
// ─────────────────────────────────────────────────────────────────────────────
class _AppBarWidget extends StatelessWidget {
  final int step;
  final VoidCallback onBack;

  const _AppBarWidget({required this.step, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final titles = ['Verify identity', 'New password', 'All done'];
    final subtitles = ['Step 1 of 2', 'Step 2 of 2', 'Password updated'];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.primary, _C.primaryDk],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _C.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Row(
                children: [
                  if (step < 2)
                    IconButton(
                      onPressed: onBack,
                      icon: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 16),
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                  const SizedBox(width: 4),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        key: ValueKey(step),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titles[step],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitles[step],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      step == 2 ? 'Done' : '${step + 1}/2',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Progress bar
            if (step < 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: step == 0 ? 0.5 : 1.0,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 4,
                  ),
                ),
              )
            else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Verify
// ─────────────────────────────────────────────────────────────────────────────
class _VerifyStep extends StatelessWidget {
  final TextEditingController currentPassCtrl;
  final TextEditingController otpCtrl;
  final bool obscureCurrent;
  final bool otpSent;
  final bool otpVerified;
  final bool loading;
  final VoidCallback onToggleCurrent;
  final VoidCallback onSendOtp;
  final VoidCallback onContinue;

  const _VerifyStep({
    super.key,
    required this.currentPassCtrl,
    required this.otpCtrl,
    required this.obscureCurrent,
    required this.otpSent,
    required this.otpVerified,
    required this.loading,
    required this.onToggleCurrent,
    required this.onSendOtp,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),

          // Info banner
          _InfoBanner(
            text:
                'After changing your password, all devices except this one will be signed out automatically.',
          ),

          const SizedBox(height: 16),

          // Current password card
          _SectionLabel(label: 'Current password'),
          _PremiumCard(
            child: _PasswordField(
              controller: currentPassCtrl,
              label: 'Current password',
              hint: 'Enter your current password',
              obscure: obscureCurrent,
              onToggle: onToggleCurrent,
              enabled: !loading,
              prefixIcon: Icons.lock_outline_rounded,
            ),
          ),

          const SizedBox(height: 16),

          // OTP card
          _SectionLabel(label: 'Email verification'),
          _PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We\'ll send a one-time code to your registered email address to confirm it\'s really you.',
                  style: TextStyle(
                    fontSize: 13,
                    color: _C.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _OtpField(
                        controller: otpCtrl,
                        enabled: otpSent && !loading,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _OtpButton(
                      sent: otpSent,
                      loading: loading,
                      onTap: onSendOtp,
                    ),
                  ],
                ),
                if (otpSent) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 14, color: _C.success),
                      const SizedBox(width: 6),
                      Text(
                        'OTP sent — check your inbox',
                        style: TextStyle(fontSize: 12, color: _C.success),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Continue button
          _PrimaryButton(
            label: 'Continue',
            loading: loading,
            onPressed: onContinue,
            enabled: otpSent,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — New password
// ─────────────────────────────────────────────────────────────────────────────
class _NewPasswordStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController newPassCtrl;
  final TextEditingController confirmPassCtrl;
  final TextEditingController currentPassCtrl;
  final bool obscureNew;
  final bool obscureConfirm;
  final double strength;
  final String strengthLabel;
  final Color strengthColor;
  final bool requirementMet;
  final bool loading;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;

  const _NewPasswordStep({
    super.key,
    required this.formKey,
    required this.newPassCtrl,
    required this.confirmPassCtrl,
    required this.currentPassCtrl,
    required this.obscureNew,
    required this.obscureConfirm,
    required this.strength,
    required this.strengthLabel,
    required this.strengthColor,
    required this.requirementMet,
    required this.loading,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            // Identity verified badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _C.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: _C.success.withOpacity(0.3), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, size: 16, color: _C.success),
                  const SizedBox(width: 8),
                  Text(
                    'Identity verified — set your new password',
                    style: TextStyle(
                      fontSize: 12,
                      color: _C.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // New password
            _SectionLabel(label: 'New password'),
            _PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Field
                  _PasswordField(
                    controller: newPassCtrl,
                    label: 'New password',
                    hint: 'Create a strong password',
                    obscure: obscureNew,
                    onToggle: onToggleNew,
                    enabled: !loading,
                    prefixIcon: Icons.lock_rounded,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter a new password';
                      if (v.length < 8) return 'Minimum 8 characters';
                      if (v == currentPassCtrl.text.trim())
                        return 'Must differ from current password';
                      return null;
                    },
                  ),

                  // Strength bar
                  if (newPassCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: strength,
                              backgroundColor: _C.border,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(strengthColor),
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          strengthLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: strengthColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    // Requirements grid
                    const SizedBox(height: 12),
                    _RequirementsGrid(password: newPassCtrl.text),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Confirm password
            _SectionLabel(label: 'Confirm password'),
            _PremiumCard(
              child: _PasswordField(
                controller: confirmPassCtrl,
                label: 'Confirm new password',
                hint: 'Re-enter your new password',
                obscure: obscureConfirm,
                onToggle: onToggleConfirm,
                enabled: !loading,
                prefixIcon: Icons.lock_clock_rounded,
                validator: (v) {
                  if (v == null || v.isEmpty)
                    return 'Please confirm your password';
                  if (v != newPassCtrl.text.trim())
                    return 'Passwords do not match';
                  return null;
                },
              ),
            ),

            const SizedBox(height: 16),

            // What happens next
            _PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: _C.primary),
                      const SizedBox(width: 8),
                      Text(
                        'What happens next',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _C.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _WhatHappensRow(
                      icon: Icons.password_rounded,
                      text: 'Password updated securely'),
                  _WhatHappensRow(
                      icon: Icons.devices_rounded,
                      text: 'All other devices signed out'),
                  _WhatHappensRow(
                      icon: Icons.token_rounded,
                      text: 'All sessions invalidated'),
                  _WhatHappensRow(
                      icon: Icons.email_rounded,
                      text: 'Security alert sent to your email',
                      last: true),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _PrimaryButton(
              label: 'Change password',
              loading: loading,
              onPressed: onSubmit,
              icon: Icons.lock_reset_rounded,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success screen
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessScreen extends StatelessWidget {
  final Animation<double> scaleAnim;
  final Animation<double> fadeAnim;
  final VoidCallback onDone;

  const _SuccessScreen({
    super.key,
    required this.scaleAnim,
    required this.fadeAnim,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: FadeTransition(
        opacity: fadeAnim,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),

            // Success icon
            ScaleTransition(
              scale: scaleAnim,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: _C.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: _C.success.withOpacity(0.3), width: 2),
                ),
                child: Icon(Icons.check_rounded, color: _C.success, size: 48),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Password changed',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _C.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your password has been updated successfully.\nAll other sessions have been terminated.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _C.muted,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 28),

            // Details card
            _PremiumCard(
              child: Column(
                children: [
                  _DetailRow(label: 'Changed at', value: _todayTime()),
                  _DetailRow(label: 'IP address', value: 'Current device'),
                  _DetailRow(
                      label: 'Sessions ended',
                      value: 'All other devices',
                      valueColor: _C.danger),
                  _DetailRow(
                    label: 'Email alert',
                    value: 'Sent to your inbox',
                    last: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Device blacklist notice
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _C.danger.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: _C.danger.withOpacity(0.2), width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.phonelink_erase_rounded,
                      size: 20, color: _C.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All devices signed out',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _C.danger,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Other devices will need to sign in again with your new password.',
                          style: TextStyle(
                              fontSize: 12, color: _C.muted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Back to settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _todayTime() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return 'Today, $h:$m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumCard extends StatelessWidget {
  final Widget child;
  const _PremiumCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _C.muted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.infoLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.infoBorder, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 16, color: _C.infoText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: _C.infoText,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final bool enabled;
  final IconData prefixIcon;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    required this.enabled,
    required this.prefixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: _C.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: _C.muted, fontSize: 13),
        labelStyle: const TextStyle(color: _C.muted, fontSize: 13),
        prefixIcon: Icon(prefixIcon, size: 20, color: _C.muted),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: _C.muted,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: _C.fieldBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.border, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.danger, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _OtpField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;

  const _OtpField({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 6,
        color: _C.text,
      ),
      decoration: InputDecoration(
        hintText: '------',
        hintStyle: TextStyle(
          color: _C.muted.withOpacity(0.4),
          fontSize: 20,
          letterSpacing: 6,
        ),
        counterText: '',
        prefixIcon:
            const Icon(Icons.security_rounded, size: 20, color: _C.muted),
        filled: true,
        fillColor: enabled ? _C.fieldBg : _C.border.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.border, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.primary, width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _OtpButton extends StatelessWidget {
  final bool sent;
  final bool loading;
  final VoidCallback onTap;

  const _OtpButton(
      {required this.sent, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: sent ? _C.success.withOpacity(0.1) : _C.primary,
          borderRadius: BorderRadius.circular(12),
          border: sent
              ? Border.all(color: _C.success.withOpacity(0.4), width: 0.5)
              : null,
        ),
        child: Text(
          sent ? 'Resend' : 'Send OTP',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: sent ? _C.success : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _RequirementsGrid extends StatelessWidget {
  final String password;
  const _RequirementsGrid({required this.password});

  @override
  Widget build(BuildContext context) {
    final reqs = [
      ('8+ characters', password.length >= 8),
      ('Uppercase letter', RegExp(r'[A-Z]').hasMatch(password)),
      ('Number', RegExp(r'[0-9]').hasMatch(password)),
      (
        'Special character',
        RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)
      ),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: reqs.map((r) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: r.$2 ? _C.success.withOpacity(0.08) : _C.fieldBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: r.$2 ? _C.success.withOpacity(0.3) : _C.border,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                r.$2 ? Icons.check_rounded : Icons.circle_outlined,
                size: 12,
                color: r.$2 ? _C.success : _C.muted,
              ),
              const SizedBox(width: 5),
              Text(
                r.$1,
                style: TextStyle(
                  fontSize: 11,
                  color: r.$2 ? _C.success : _C.muted,
                  fontWeight: r.$2 ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _WhatHappensRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool last;

  const _WhatHappensRow(
      {required this.icon, required this.text, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _C.primary),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(fontSize: 13, color: _C.text),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;
  final IconData? icon;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
    this.enabled = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: (enabled && !loading) ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? _C.primary : _C.muted.withOpacity(0.3),
          foregroundColor: Colors.white,
          disabledBackgroundColor: _C.muted.withOpacity(0.2),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool last;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: _C.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: _C.muted)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? _C.text,
            ),
          ),
        ],
      ),
    );
  }
}
