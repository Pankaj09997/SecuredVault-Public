// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:securevault/Presentation/BlocFile/AuthBloc/bloc/auth_bloc.dart';
import 'package:securevault/Presentation/Pages/AuthPages/LoginPage.dart';
import 'package:securevault/Presentation/Widget/ColorPallete.dart';
import 'package:securevault/Presentation/Widget/CustomButton.dart';
import 'package:securevault/Presentation/Widget/CustomField.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String reset_otp_code;
  const ResetPasswordPage({
    super.key,
    required this.email,
    required this.reset_otp_code,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

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
                SnackBar(content: Text("Unabe To Reset The Password")));
          } else if (state is ResetPasswordSuccessState) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text("Password Has Been Successfully Changed")));
            Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => LoginPage()),
                (Route<dynamic> route) => false);
          }
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'Reset Password',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: ColorPalette.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                // Subtitle
                Text(
                  'Set a new password for your account',
                  style: TextStyle(
                    fontSize: 16,
                    color: ColorPalette.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 40),
                // Password Field
                CustomField(
                  controller: _passwordController,
                  labelText: 'New Password',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  validator: (value) =>
                      value!.length >= 10 ? null : 'Minimum 10 characters',
                ),
                const SizedBox(height: 20),
                // Confirm Password Field
                CustomField(
                  controller: _confirmPasswordController,
                  labelText: 'Confirm Password',
                  prefixIcon: Icons.lock_reset_outlined,
                  isPassword: true,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                // Reset Button

                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthLoading) {
                      return CircularProgressIndicator();
                    }
                    return Center(
                      child: CustomButton(
                        text: 'Reset Password',
                        onTap: () {
                          if (_passwordController.text.isEmpty ||
                              _confirmPasswordController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please fill all fields')),
                            );
                            return;
                          }
                          if (_passwordController.text !=
                              _confirmPasswordController.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Passwords do not match')),
                            );
                            return;
                          }
                          // TODO: Add password reset logic
                          print('Reset password for: ${widget.email}');
                          print('OTP: ${widget.reset_otp_code}');

                          context.read<AuthBloc>().add(ResetPassword(
                              email: widget.email,
                              reset_otp_code: widget.reset_otp_code,
                              password: _passwordController.text,
                              password2: _confirmPasswordController.text));
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
