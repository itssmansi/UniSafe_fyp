import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/auth/auth_choice_screen.dart';
import 'screens/auth/authority_login_screen.dart';
import 'screens/heatmap_ui/map_screen.dart';
import 'screens/home_page.dart';
import 'screens/interactive_map/map_screen.dart';
import 'screens/kanban_board_ui/kanban_board_screen.dart';
import 'screens/women_safety/women_safety_screen.dart';
import 'screens/SignupLogin_ui/welcome_screen.dart';
import 'screens/SignupLogin_ui/login_screen.dart';
import 'screens/SignupLogin_ui/signup_screen.dart';
import 'screens/SignupLogin_ui/forget_password_screen.dart';
import 'screens/missing_persons/missing_persons_screen.dart';
import 'theme/unisafe_theme.dart';

export 'screens/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabasePublishableKey,
  );

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
    final bool hasActiveSession = SupabaseConfig.client.auth.currentSession != null;

    return MaterialApp(
      title: 'UniSafe',
      debugShowCheckedModeBanner: false,
      theme: UniSafeTheme.light(),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.0,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      onGenerateRoute: (settings) {
        final routes = <String, WidgetBuilder>{
          '/home': (_) => const HomePage(),
          '/interactive-map': (_) => const InteractiveMapScreen(),
          '/heatmap': (_) => const MapScreen(),
          '/kanban': (_) => const KanbanBoardScreen(),
          '/women-safety': (_) => const WomenSafetyScreen(),
          '/missing-persons': (_) => const MissingPersonsScreen(),
        };
        final builder = routes[settings.name];
        return builder == null ? null : UniSafePageRoute(builder: builder, settings: settings);
      },
      home: hasActiveSession ? const HomePage() : const WelcomeSelectionScreen(),
      routes: {
        '/citizen-auth-splash': (context) => const WelcomeSelectionScreen(),
        '/citizen-auth-welcome': (context) => const WelcomeSelectionScreen(),
        '/citizen-auth-login': (context) => const CitizenLoginScreen(),
        '/citizen-auth-signup': (context) => const CitizenSignupScreen(),
        '/citizen-auth-forget-password': (context) => const ForgetPasswordScreen(),
        '/auth-choice': (context) => const AuthChoiceScreen(),
        '/authority-login': (context) => const AuthorityLoginScreen(),
        '/women-safety': (context) => const WomenSafetyScreen(),
      },
    );
  }
}
