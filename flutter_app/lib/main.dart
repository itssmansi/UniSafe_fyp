import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/heatmap_ui/map_screen.dart';
import 'screens/home_page.dart';
import 'screens/interactive_map/map_screen.dart';
import 'screens/kanban_board_ui/kanban_board_screen.dart';
import 'screens/SignupLogin_ui/splash_screen.dart';
import 'screens/SignupLogin_ui/welcome_screen.dart';
import 'screens/SignupLogin_ui/login_screen.dart';
import 'screens/SignupLogin_ui/signup_screen.dart';
import 'screens/SignupLogin_ui/forget_password_screen.dart';

export 'screens/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSize = 3000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 300 * 1024 * 1024;
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: Colors.red,
        child: Text(
          details.exceptionAsString(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  };
  runApp(
    const ProviderScope(
      child: UniSafeApp(),
    ),
  );
}

class UniSafeApp extends StatelessWidget {
  const UniSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniSafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const WelcomeSelectionScreen(),
      routes: {
        '/home': (context) => const HomePage(),
        '/interactive-map': (context) => const InteractiveMapScreen(),
        '/heatmap': (context) => const MapScreen(),
        '/kanban': (context) => const KanbanBoardScreen(),
        '/citizen-auth-splash': (context) => const WelcomeSelectionScreen(),
        '/citizen-auth-welcome': (context) => const WelcomeSelectionScreen(),
        '/citizen-auth-login': (context) => const CitizenLoginScreen(),
        '/citizen-auth-signup': (context) => const CitizenSignupScreen(),
        '/citizen-auth-forget-password': (context) => const ForgetPasswordScreen(),
      },
    );
  }
}
