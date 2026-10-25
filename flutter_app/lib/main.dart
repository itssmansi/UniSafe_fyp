
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'config/supabase_config.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'screens/auth/auth_choice_screen.dart';
import 'screens/dashboard/citizen_dashboard_screen.dart';
import 'screens/interactive_map/map_screen.dart';
import 'screens/kanban_board_ui/kanban_board_screen.dart';
import 'screens/home_page.dart';

final GlobalKey<NavigatorState> appNavKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Background FCM handling specifically guarded for Android
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );
  }

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabasePublishableKey,
  );

  // Initialize Android push notifications and local channel
  await NotificationService.initialize(navKey: appNavKey);

  // Synchronize FCM token upon auth changes
  SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedIn ||
        data.event == AuthChangeEvent.tokenRefreshed) {
      NotificationService.syncTokenWithCurrentUser();
    } else if (data.event == AuthChangeEvent.signedOut) {
      NotificationService.unregisterCurrentDeviceToken();
    }
  });

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
      navigatorKey: appNavKey,
      debugShowCheckedModeBanner: false,
      title: 'UniSafe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
      routes: {
        '/auth': (context) => const AuthChoiceScreen(),
        '/dashboard': (context) => const CitizenDashboardScreen(),
        '/interactive-map': (context) => const InteractiveMapScreen(),
        '/kanban': (context) => const KanbanBoardScreen(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SupabaseConfig.client.auth.currentSession;

    if (session != null) {
      return const CitizenDashboardScreen();
    }

    return const AuthChoiceScreen();
  }
}
