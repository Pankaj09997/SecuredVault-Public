import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:securevault/Presentation/BlocFile/AuthBloc/bloc/auth_bloc.dart';
import 'package:securevault/Presentation/Widget/ColorPallete.dart';
import 'package:securevault/Presentation/Widget/CustomButton.dart';
import 'package:securevault/Presentation/Widget/CustomField.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  final bool _deviceSecure = true;

  File? _selectedImage;

  Future<void> _pickImage() async {
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedImage != null) {
      setState(() {
        _selectedImage = File(pickedImage.path);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No Image Selected"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _signUp() {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a profile image'),
        ),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full name'),
        ),
      );
      return;
    }

    if (!_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid email address'),
        ),
      );
      return;
    }

    if (_passwordController.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 10 characters'),
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
        ),
      );
      return;
    }

    context.read<AuthBloc>().add(
          SignUpEvent(
            image: _selectedImage!,
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            password2: _confirmPasswordController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: ColorPalette.backgroundColor,
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }

            if (state is UserRegistrationSuccessState) {
              Navigator.pushNamed(
                context,
                '/signupotp',
                arguments: {
                  'email': state.userRegistrationEntities.email,
                },
              );
            }

            if (state is NavigateToLoginPage) {
              Navigator.pushNamed(context, "/");
            }
          },
          builder: (context, state) {
            return Stack(
              children: [
                SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      /// PROFILE IMAGE
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _selectedImage != null
                                  ? ClipOval(
                                      child: Image.file(
                                        _selectedImage!,
                                        width: 210,
                                        height: 210,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : SvgPicture.asset(
                                      'assets/images/person.svg',
                                      height: 210,
                                      width: 210,
                                      colorFilter: const ColorFilter.mode(ColorPalette.primaryColor, BlendMode.srcIn),
                                    ),

                              /// CAMERA ICON
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: ColorPalette.primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      /// TITLE
                      Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: ColorPalette.primaryColor,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Secure storage for your sensitive data',
                        style: TextStyle(
                          fontSize: 16,
                          color: ColorPalette.secondaryTextColor,
                        ),
                      ),

                      const SizedBox(height: 40),

                      /// NAME FIELD
                      CustomField(
                        controller: _nameController,
                        labelText: 'Full Name',
                        prefixIcon: Icons.person_outline,
                        keyboardType: TextInputType.name,
                      ),

                      const SizedBox(height: 20),

                      /// EMAIL FIELD
                      CustomField(
                        controller: _emailController,
                        labelText: 'Email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 20),

                      /// PASSWORD FIELD
                      CustomField(
                        controller: _passwordController,
                        labelText: 'Password',
                        prefixIcon: Icons.lock_outline,
                        isPassword: true,
                      ),

                      const SizedBox(height: 20),

                      /// CONFIRM PASSWORD FIELD
                      CustomField(
                        controller: _confirmPasswordController,
                        labelText: 'Confirm Password',
                        prefixIcon: Icons.lock_outline,
                        isPassword: true,
                      ),

                      const SizedBox(height: 24),

                      /// DEVICE SECURITY WARNING
                      if (!_deviceSecure)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.security,
                                color: Colors.amber[700],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Device security compromised',
                                  style: TextStyle(
                                    color: Colors.amber[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 27),

                      /// SIGN UP BUTTON
                      Center(
                        child: CustomButton(
                          text: 'Sign Up',
                          onTap: _signUp,
                        ),
                      ),

                      const SizedBox(height: 24),

                      /// FINGERPRINT BUTTON
                      Center(
                        child: IconButton(
                          icon: const Icon(
                            Icons.fingerprint,
                            size: 40,
                          ),
                          onPressed: () {
                            // biometric registration
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// SIGN IN
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: TextStyle(
                              color: ColorPalette.secondaryTextColor,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              context
                                  .read<AuthBloc>()
                                  .add(NavigateToLoginEvent());
                            },
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                color: ColorPalette.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),

                /// LOADING OVERLAY
                if (state is AuthLoading)
                  Container(
                    color: Colors.black.withOpacity(0.2),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
