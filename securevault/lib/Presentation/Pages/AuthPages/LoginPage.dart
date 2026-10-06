import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:local_auth/local_auth.dart';
import 'package:securevault/Presentation/BlocFile/AuthBloc/bloc/auth_bloc.dart';
import 'package:securevault/Presentation/Widget/ColorPallete.dart';
import 'package:securevault/Presentation/Widget/CustomButton.dart';
import 'package:securevault/Presentation/Widget/CustomField.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final bool _deviceSecure = true;
  bool _fingerPrintAccess = false;

  Future<bool> _checkUserFingerPrint() async {
    final LocalAuthentication auth = LocalAuthentication();
    final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
    final bool canAuthenticate =
        canAuthenticateWithBiometrics || await auth.isDeviceSupported();
    if (canAuthenticate) {
      setState(() {
        _fingerPrintAccess = true;
      });
    } else {
      _fingerPrintAccess = false;
    }
    return _fingerPrintAccess;
  }

  @override
  void initState() {
    _checkUserFingerPrint();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorPalette.backgroundColor,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.red,
                  ),
                );
              } else if (state is AccountLockedState) {
                _showSecurityViolationDialog(
                    context, state.reason, state.details);
              } else if (state is AuthSuccess) {
                Navigator.pushNamedAndRemoveUntil(
                    context, "/home", (route) => false);
              } else if (state is NavigateToSignUpPage) {
                Navigator.pushNamed(context, "/signup");
              } else if (state is NavigateToForgotPasswordState) {
                Navigator.pushNamed(context, "/forgotpass");
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80),
                Center(
                  child: SvgPicture.asset(
                    'assets/images/LoginScreen.svg',
                    height: 120,
                    width: 120,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: ColorPalette.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Secure access to your encrypted storage',
                  style: TextStyle(
                    fontSize: 16,
                    color: ColorPalette.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 40),
                CustomField(
                  controller: _emailController,
                  labelText: 'Email',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      value!.contains('@') ? null : 'Invalid email',
                ),
                const SizedBox(height: 20),
                CustomField(
                  controller: _passwordController,
                  labelText: 'Password',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  validator: (value) =>
                      value!.length >= 8 ? null : 'Minimum 8 characters',
                ),
                const SizedBox(height: 24),
                if (!_deviceSecure)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.security, color: Colors.amber[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Device security compromised',
                            style: TextStyle(color: Colors.amber[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthLoading) {
                      return Center(child: CircularProgressIndicator());
                    }
                    return Center(
                      child: CustomButton(
                        text: 'Sign In',
                        onTap: () {
                          context.read<AuthBloc>().add(SignInEvent(
                              email: _emailController.text,
                              password: _passwordController.text));
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () {
                      context
                          .read<AuthBloc>()
                          .add(NavigateToForgotPasswordEvent());
                    },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: ColorPalette.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'New to SecureVault? ',
                      style: TextStyle(
                        color: ColorPalette.secondaryTextColor,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<AuthBloc>().add(NavigateToSignUpEvent());
                      },
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          color: ColorPalette.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showSecurityViolationDialog(
    BuildContext context, String reason, String details) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.security_update_warning_rounded,
              color: Colors.redAccent, size: 28),
          const SizedBox(width: 12),
          const Text("Security Alert",
              style: TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("VIOLATION",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                        letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(reason,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text("DETAILS",
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(details,
              style: const TextStyle(
                  fontSize: 14, color: Colors.black54, height: 1.5)),
          const SizedBox(height: 20),
          const Text(
              "For your protection, we've restricted account access. Please check your email for verification instructions.",
              style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Understand",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            context.read<AuthBloc>().add(NavigateToForgotPasswordEvent());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Reset Password"),
        ),
      ],
    ),
  );
}
