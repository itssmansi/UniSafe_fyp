import 'package:flutter/material.dart';
import 'screens/missing_persons/missing_persons_screen.dart';
import 'screens/missing_persons/report_sighting_form.dart';
import 'theme/unisafe_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UniSafeApp());
}

class UniSafeApp extends StatelessWidget {
  const UniSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniSafe',
      debugShowCheckedModeBanner: false,
      theme: UniSafeTheme.themeData,
      home: const MissingPersonsScreen(),
      routes: {
        '/citizen-missing-persons': (context) => const MissingPersonsScreen(),
        '/report-sighting': (context) => const ReportSightingForm(),
      },
    );
  }
}
