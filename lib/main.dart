import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/cart_provider.dart';
import 'providers/language_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'services/push_notification_service.dart';

import 'screens/splash_screen.dart';
import 'widgets/coffee_overlays.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushNotificationService.instance.initialize();
  await ApiService.init();
  await initializeDateFormatting('id_ID');
  await initializeDateFormatting('en_US');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final StreamSubscription<void> _sessionSubscription;
  bool _navigationPending = false;

  @override
  void initState() {
    super.initState();
    _sessionSubscription = ApiService.sessionEnded.listen((_) {
      if (!mounted || _navigationPending) return;
      final version = ApiService.sessionVersion;
      _navigationPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigationPending = false;
        if (!mounted || version != ApiService.sessionVersion) return;
        unawaited(PushNotificationService.instance.onLoggedOut());
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      });
    });
  }

  @override
  void dispose() {
    _sessionSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Ciks Coffee',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4A3022), // Espresso
            primary: const Color(0xFF4A3022),
            secondary: const Color(0xFFD2B48C), // Tan
            surface: const Color(0xFFF5E6D3), // Latte
          ),
          textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
          dialogTheme: DialogThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(color: CoffeeColors.border),
            ),
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Colors.white,
            modalBarrierColor: Color(0x594A3022),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 52),
              foregroundColor: Colors.white,
              backgroundColor: CoffeeColors.ink,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final ApiService _apiService = ApiService();
  bool _isInitializing = true;
  bool _isAuthenticated = false;
  bool _connectionUnavailable = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _connectionUnavailable = false;
      });
    }
    final startedAt = DateTime.now();
    var isAuthenticated = false;

    // Jangan lepaskan splash sebelum validasi token benar-benar selesai.
    final token = await _apiService.getToken();

    if (token != null) {
      final status = await _apiService.validateSession();
      isAuthenticated = status == SessionStatus.valid;
      _connectionUnavailable = status == SessionStatus.unavailable;
      if (isAuthenticated) {
        unawaited(
          PushNotificationService.instance.initializeForAuthenticatedUser(),
        );
      }
      if (status == SessionStatus.unauthenticated) {
        await PushNotificationService.instance.onLoggedOut();
        await _apiService.clearToken();
      }
    }

    const minimumSplashDuration = Duration(seconds: 3);
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < minimumSplashDuration) {
      await Future<void>.delayed(minimumSplashDuration - elapsed);
    }

    if (!mounted) return;
    setState(() {
      _isAuthenticated = isAuthenticated;
      _isInitializing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const SplashScreen();
    }

    if (_connectionUnavailable) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 42,
                    color: CoffeeColors.muted,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Koneksi ke server belum tersedia. Sesi akunmu tetap tersimpan.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  CoffeeButton(label: 'Coba lagi', onPressed: _initializeApp),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final openStatus = PushNotificationService.instance
        .consumePendingStatusNavigation();
    return _isAuthenticated
        ? HomeScreen(initialIndex: openStatus ? 2 : 0)
        : const LoginScreen();
  }
}
