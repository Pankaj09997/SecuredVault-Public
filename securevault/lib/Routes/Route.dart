import 'package:flutter/material.dart';
import 'package:securevault/Presentation/Pages/AuthPages/ForgotPassword/ForgotPassword.dart';
import 'package:securevault/Presentation/Pages/AuthPages/ForgotPassword/ResetPassword.dart';
import 'package:securevault/Presentation/Pages/AuthPages/ForgotPassword/VerifyOtp.dart';
import 'package:securevault/Presentation/Pages/AuthPages/LoginPage.dart';
import 'package:securevault/Presentation/Pages/AuthPages/SignUpPage/SignUpOtpPage.dart';
import 'package:securevault/Presentation/Pages/AuthPages/SignUpPage/SignUpPage.dart';
import 'package:securevault/Presentation/Pages/DrawerPage/ChangePassword.dart';
import 'package:securevault/Presentation/Pages/DrawerPage/DashboardPage.dart';
import 'package:securevault/Presentation/Pages/DrawerPage/HelpAndSupportPage.dart';
import 'package:securevault/Presentation/Pages/DrawerPage/PrivacyPolicy.dart';
import 'package:securevault/Presentation/Pages/DrawerPage/UpdateProfile.dart';
import 'package:securevault/Presentation/Pages/DrawerPage/settings.dart';
import 'package:securevault/Presentation/Pages/MainScreen/MainScreen.dart';
import 'package:securevault/Presentation/Widget/BottomNavBar.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return _smoothRoute(LoginPage(), settings);
      case '/bottom':
        return _smoothRoute(NavigationBarItems(), settings);
      case '/signup':
        return _smoothRoute(SignUpPage(), settings);
      case '/home':
        return _smoothRoute(const MainScreen(), settings);
      case '/signupotp':
        final args = settings.arguments as Map<String, dynamic>;
        final email = args['email'] as String;
        return _smoothRoute(SignUpOtpPage(email: email), settings);
      case '/forgotpass':
        return _smoothRoute(ForgotPassword(), settings);
      case "/verify-otp":
        final args = settings.arguments as Map<String, dynamic>;
        final email = args['email'] as String;
        return _smoothRoute(VerifyOtp(email: email), settings);
      case "/reset-password":
        final args = settings.arguments as Map<String, dynamic>;
        final email = args['email'];
        final resetOtpCode = args['reset_otp_code'];
        return _smoothRoute(
          ResetPasswordPage(email: email, reset_otp_code: resetOtpCode),
          settings,
        );
      case "/settings":
        return _smoothRoute(SettingsPage(), settings);
      case "/privacypolicy":
        return _smoothRoute(PrivacyPolicyPage(), settings);
      case '/changepassword':
        return _smoothRoute(ChangePassword(), settings);
      case '/updateprofile':
        return _smoothRoute(UpdateProfile(), settings);
      case '/help':
        return _smoothRoute(HelpAndSupportPage(), settings);
      case '/dashboard':
        return _smoothRoute(const DashboardPage(), settings);
      default:
        return _smoothRoute(ErrorPage(), settings);
    }
  }

  /// Smooth fade + slide-up transition for all routes
  static Route<dynamic> _smoothRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }
}

class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
