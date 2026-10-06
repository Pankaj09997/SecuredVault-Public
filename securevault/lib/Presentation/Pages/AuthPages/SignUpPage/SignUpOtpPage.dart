import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:securevault/Presentation/BlocFile/AuthBloc/bloc/auth_bloc.dart';
import 'package:securevault/Presentation/Widget/ColorPallete.dart';
import 'package:securevault/Presentation/Widget/CustomButton.dart';

class SignUpOtpPage extends StatefulWidget {
  final String email;
  const SignUpOtpPage({
    super.key,
    required this.email,
  });

  @override
  State<SignUpOtpPage> createState() => _SignUpOtpPageState();
}

class _SignUpOtpPageState extends State<SignUpOtpPage> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (index) => FocusNode());
  bool clickedOnResetButton = false;

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _verifyOtp() {
    print(widget.email);

    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter complete OTP')),
      );
      print(otp);
      return;
    }

    context.read<AuthBloc>().add(VerifyOtpEvent(
          email: widget.email,
          otp_code: otp,
        ));
  }

  void _handleOtpInput(String value, int index) {
    if (value.length == 1 && index < 5) {
      FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_otpFocusNodes[index - 1]);
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is NavigateToHomeScreenState) {
            Navigator.pushNamed(context, "/");
          }
          if (state is VerifyOtpFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is AuthSuccess) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (route) => false,
            );
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text("OTP has been verified")));
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Verify OTP',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: ColorPalette.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  text: 'Enter the 6-digit code sent to ',
                  style: TextStyle(
                    fontSize: 16,
                    color: ColorPalette.secondaryTextColor,
                  ),
                  children: [
                    TextSpan(
                      text: widget.email,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ColorPalette.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 45,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: ColorPalette.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: ColorPalette.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) => _handleOtpInput(value, index),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      bool isDisabled = false;
                      String text = "Resend OTP";

                      if (state is ResendOtpCoolDownState) {
                        isDisabled = true;
                        text = "Wait ${state.countdown}s";
                      }

                      return RichText(
                        text: TextSpan(
                          text: "Didn't receive OTP? ",
                          style: TextStyle(color: Colors.black),
                          children: [
                            TextSpan(
                              text: text,
                              style: TextStyle(
                                color: isDisabled ? Colors.grey : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = isDisabled
                                    ? null
                                    : () {
                                        context.read<AuthBloc>().add(
                                              RegisterResendOtpCode(
                                                  email: widget.email,
                                                  60,
                                                  true),
                                            );
                                      },
                            ),
                          ],
                        ),
                      );
                    },
                  )
                ],
              ),
              const SizedBox(height: 40),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  if (state is AuthLoading) {
                    return Center(child: CircularProgressIndicator());
                  }
                  return Center(
                    child: CustomButton(
                      text: 'Verify',
                      onTap: _verifyOtp,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
