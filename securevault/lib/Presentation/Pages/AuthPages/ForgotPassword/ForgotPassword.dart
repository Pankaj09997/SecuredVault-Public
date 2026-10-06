import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:securevault/Presentation/BlocFile/AuthBloc/bloc/auth_bloc.dart';
import 'package:securevault/Presentation/Widget/ColorPallete.dart';
import 'package:securevault/Presentation/Widget/CustomButton.dart';
import 'package:securevault/Presentation/Widget/CustomField.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendResetOtp() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(ForgotPasswordSendOtp(email: _emailController.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorPalette.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: ColorPalette.primaryColor,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is ForgotPasswordSendOtpSuccess) {
            Navigator.pushNamed(
              context,
              '/verify-otp',
              arguments: {'email': _emailController.text},
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("OTP sent to ${_emailController.text}")),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: ColorPalette.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your email to reset your password',
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Center(
                      child: CustomButton(
                        text: 'Send OTP',
                        onTap: _sendResetOtp,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Back to Sign In',
                      style: TextStyle(
                        color: ColorPalette.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
