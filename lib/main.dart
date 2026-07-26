import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/cart_provider.dart';
import 'providers/language_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';

import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await initializeDateFormatting('en_US');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: MaterialApp(
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

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final startedAt = DateTime.now();
    var isAuthenticated = false;

    // Jangan lepaskan splash sebelum validasi token benar-benar selesai.
    final token = await _apiService.getToken();

    if (token != null) {
      final isValid = await _apiService.validateToken();
      isAuthenticated = isValid;
      if (!isValid) {
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

    return _isAuthenticated ? const HomeScreen() : const LoginScreen();
  }
}
