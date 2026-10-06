import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:securevault/Business/Repositories/AuthRepoBusiness.dart';
import 'package:securevault/Business/Repositories/FileRepository.dart';
import 'package:securevault/Business/Repositories/ImageRepositoryBusiness.dart';
import 'package:securevault/Business/Usecase/AuthUseCase.dart';
import 'package:securevault/Business/Usecase/FileUseCase.dart';
import 'package:securevault/Business/Usecase/ImageUseCase.dart';
import 'package:securevault/Data/DataSource/FilesService.dart';
import 'package:securevault/Data/DataSource/ImageService.dart';
import 'package:securevault/Presentation/BlocFile/AuthBloc/bloc/auth_bloc.dart';
import 'package:securevault/Presentation/BlocFile/FileBloc/file_bloc_bloc.dart';
import 'package:securevault/Presentation/BlocFile/ImageBloc/image_bloc.dart';
import 'package:securevault/Routes/Route.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Data/DataSource/authservice.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait for consistent UX
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for a polished status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  final authService = AuthApiService();
  final imageService = ImageService();
  final fileServices = FilesService();
  final authRepo = AuthRepositoriesBusinessImpl(authApiService: authService);
  final imageRepo = ImageRepositoryBusinessImpl(imageService: imageService);
  final fileRepo = FileRepositoryImpl(filesService: fileServices);
  final signInUseCase = SignInUseCase(authRepositoriesBusiness: authRepo);
  final signUpUseCase = SignUpUseCase(authRepositoriesBusiness: authRepo);
  final verifyOtpUseCase = VerifyOtpUseCase(authRepositoriesBusiness: authRepo);
  final forgotresendOtp = ResendOtpUseCase(authRepositoriesBusiness: authRepo);
  final uploadImage = UploadImageUseCase(imageRepositoryBusiness: imageRepo);
  final uploadFile = FileUploadUseCase(fileRepositoryBusiness: fileRepo);
  final deleteFile = DeleteFileUseCase(fileRepositoryBusiness: fileRepo);
  final shareableLink =
      FileShareableLinkUseCase(fileRepositoryBusiness: fileRepo);
  final deleteImage = DeleteImageUseCase(imageRepositoryBusiness: imageRepo);
  final shareImageLink =
      ImageShareableLinkUseCase(imageRepositoryBusiness: imageRepo);
  final downloadImage =
      DownloadImageUseCase(imageRepositoryBusiness: imageRepo);
  final listImages = ListImagesUseCase(imageRepositoryBusiness: imageRepo);
  final viewImage = ImageViewUseCase(imageRepositoryBusiness: imageRepo);
  final listImageAccessLog =
      ImageAccessLogUseCase(imageRepositoryBusiness: imageRepo);
  final downloadFile = DownloadFilesUseCase(fileRepositoryBusiness: fileRepo);
  final listFile = ListFilesUseCase(fileRepositoryBusiness: fileRepo);
  final fileAccessLog = FileAccessLogUseCase(fileRepositoryBusiness: fileRepo);
  final viewFile = FileViewUseCase(fileRepositoryBusiness: fileRepo);

  final registerResendOtp =
      ForgotResendOtpUseCase(authRepositoriesBusiness: authRepo);
  final verifyResetOtp =
      VerifyResetOtpUseCase(authRepositoriesBusiness: authRepo);
  final resetPassword =
      ResetPasswordUseCase(authRepositoriesBusiness: authRepo);
  final forgotPassword =
      ForgotPasswordUseCase(authRepositoriesBusiness: authRepo);
  final logout = LogoutUseCase(
      authRepositoriesBusiness:
          AuthRepositoriesBusinessImpl(authApiService: AuthApiService()));
  final changePassword =
      ChangePasswordUseCase(authRepositoriesBusiness: authRepo);
  final updateProfile = UpdateProfileuseCase(
      authRepositoriesBusiness:
          AuthRepositoriesBusinessImpl(authApiService: AuthApiService()));
  final getUserProfile = GetUserProfileUseCase(
      authRepositoriesBusiness:
          AuthRepositoriesBusinessImpl(authApiService: AuthApiService()));
  final requestForOtp = RequestForPasswordChange(
      authRepositoriesBusiness:
          AuthRepositoriesBusinessImpl(authApiService: AuthApiService()));

  runApp(MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>(
        create: (_) => AuthBloc(
            signInUseCase,
            signUpUseCase,
            verifyOtpUseCase,
            forgotresendOtp,
            registerResendOtp,
            verifyResetOtp,
            resetPassword,
            forgotPassword,
            logoutUseCase: logout,
            changePasswordUseCase: changePassword,
            updateProfileuseCase: updateProfile,
            getUserProfileUseCase: getUserProfile,
            requestForPasswordChange: requestForOtp),
      ),
      BlocProvider<ImageBloc>(
          create: (_) => ImageBloc(uploadImage, listImages, downloadImage,
              listImageAccessLog, viewImage, shareImageLink, deleteImage)),
      BlocProvider<FileBlocBloc>(
          create: (_) => FileBlocBloc(uploadFile, fileAccessLog, listFile,
              downloadFile, viewFile, shareableLink, deleteFile)),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// `null` → still checking, `true` → logged in, `false` → not logged in
  bool? _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Minimum duration for the splash screen animation to play
    final minSplashDuration =
        Future.delayed(const Duration(milliseconds: 2500));
    final secureStorage = FlutterSecureStorage();
    final authCheck = await secureStorage.read(key: 'refresh');

    bool isValid = false;
    if (authCheck != null) {
      try {
        final authService = AuthApiService();
        await authService.getuserProfile();
        isValid = true;
      } catch (e) {
        // Token invalid, expired, or user is blocked/locked (403/401)
        isValid = false;
        await secureStorage.delete(key: 'refresh');
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear(); // Clear all user data
      }
    }

    await minSplashDuration;

    if (mounted) {
      setState(() => _isLoggedIn = isValid);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a smooth splash while we check auth — prevents login page flash
    if (_isLoggedIn == null) {
      return MaterialApp(
        key: const ValueKey('auth-checking'),
        debugShowCheckedModeBanner: false,
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const _SplashScreen(),
          );
        },
      );
    }

    return MaterialApp(
      key: ValueKey(_isLoggedIn),
      debugShowCheckedModeBanner: false,
      // ── App-wide smooth scroll physics ──
      scrollBehavior: const _SmoothScrollBehavior(),
      // ── Themed progress indicators & ripple effects ──
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.black,
        brightness: Brightness.light,
        // Smooth ink splash everywhere
        splashFactory: InkSparkle.splashFactory,
        // Themed progress indicators
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Colors.black,
          linearTrackColor: Color(0xFFE0E0E0),
        ),
        // Smooth page transitions
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      initialRoute: _isLoggedIn! ? '/home' : '/',
      onGenerateRoute: RouteGenerator.generateRoute,
    );
  }
}

class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoSlideAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _textMoveAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    // Logo slides in from left (0ms – 700ms)
    _logoSlideAnimation = Tween<double>(begin: -320, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.27, curve: Curves.easeInOut),
      ),
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.14, curve: Curves.easeOut),
      ),
    );

    // Logo bounces at center (700ms – 1200ms)
    _logoScaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.27, 0.46, curve: Curves.bounceOut),
      ),
    );

    // Name fades + rises in (900ms – 1500ms)
    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.58, curve: Curves.easeOut),
      ),
    );

    _textMoveAnimation = Tween<double>(begin: 8, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.58, curve: Curves.easeOut),
      ),
    );

    // Progress bar fills (1100ms – 2600ms)
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.42, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050914),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF07122E),
              Color(0xFF050914),
              Color(0xFF02040A),
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo: slide + bounce
                  Transform.translate(
                    offset: Offset(_logoSlideAnimation.value, 0),
                    child: Opacity(
                      opacity: _logoFadeAnimation.value,
                      child: Transform.scale(
                        scale: _logoScaleAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x663EE4F2),
                                blurRadius: 34,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: Color(0x99000000),
                                blurRadius: 28,
                                offset: Offset(0, 18),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: Image.asset(
                              'assets/SecuredVault.jpg',
                              width: 118,
                              height: 118,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Name fades + rises in
                  Opacity(
                    opacity: _textFadeAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, _textMoveAnimation.value),
                      child: const Text(
                        'Secured Vault',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Progress bar fades in and fills
                  Opacity(
                    opacity: _textFadeAnimation.value,
                    child: SizedBox(
                      width: 116,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          value: _progressAnimation.value,
                          color: const Color(0xFF66EAF2),
                          backgroundColor: Colors.white.withOpacity(0.14),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
