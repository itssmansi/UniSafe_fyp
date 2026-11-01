import 'package:flutter/material.dart';
import 'screens/missing_persons/missing_persons_screen.dart';
import 'screens/missing_persons/report_sighting_form.dart';
import 'theme/unisafe_theme.dart';

/// Standalone Preview Runner for Citizen Missing Persons & Sightings Screen.
///
/// To run directly:
/// `flutter run -t lib/main_missing_persons_preview.dart`
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UniSafeMissingPersonsPreviewApp());
}

class UniSafeMissingPersonsPreviewApp extends StatelessWidget {
  const UniSafeMissingPersonsPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniSafe - Missing Persons & Sightings',
      debugShowCheckedModeBanner: false,
      theme: UniSafeTheme.themeData,
      home: const MissingPersonsScreen(),
      routes: {
        '/missing-persons': (context) => const MissingPersonsScreen(),
        '/report-sighting': (context) => const ReportSightingForm(),
      },
    );
  }
}
