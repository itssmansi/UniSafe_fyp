import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unisafe_app/models/missing_person.dart';
import 'package:unisafe_app/screens/missing_persons/report_sighting_form.dart';

void main() {
  final samplePerson = MissingPerson(
    id: 'mp-test-001',
    caseCode: 'MP-2026-0099',
    fullName: 'Rahul Verma',
    age: 25,
    gender: 'Male',
    lastSeenLocation: 'Andheri West, Mumbai',
    description: 'Wearing grey hoodie',
  );

  // Valid 1x1 PNG bytes so Image.memory decodes without error
  final validPngBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  testWidgets('ReportSightingForm renders all essential form fields and banners',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: ReportSightingForm(linkedPerson: samplePerson),
      ),
    );

    // Header and linked case banner
    expect(find.text('Report a Sighting'), findsOneWidget);
    expect(find.text('Rahul Verma'), findsOneWidget);
    expect(find.textContaining('MP-2026-0099'), findsWidgets);

    // Section titles
    expect(find.text('1. Sighting Photograph *'), findsOneWidget);
    expect(find.text('2. Sighting Location *'), findsOneWidget);
    expect(find.text('3. Approximate Date & Time *'), findsOneWidget);
    expect(find.text('4. Context & Observations (Optional)'), findsOneWidget);
    expect(find.text('5. Citizen Follow-up (Optional)'), findsOneWidget);

    // Submit button
    expect(find.text('Submit Sighting Report'), findsOneWidget);
  });

  testWidgets('Submitting without an image triggers image error message',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: ReportSightingForm(),
      ),
    );

    await tester.ensureVisible(find.text('Submit Sighting Report'));
    await tester.tap(find.text('Submit Sighting Report'));
    await tester.pumpAndSettle();

    expect(
      find.text('A sighting photograph is required for facial matching.'),
      findsOneWidget,
    );
  });

  testWidgets('Successful submission sends multipart request and shows returned tracking ID',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    bool requestReceived = false;
    String? capturedCitizenNote;
    String? capturedAddress;
    String? capturedFilename;
    String? capturedLatitude;
    String? capturedLongitude;

    final mockClient = MockClient.streaming((request, bodyStream) async {
      requestReceived = true;
      if (request is http.MultipartRequest) {
        capturedCitizenNote = request.fields['citizen_note'];
        capturedAddress = request.fields['address'];
        capturedLatitude = request.fields['latitude'];
        capturedLongitude = request.fields['longitude'];
        if (request.files.isNotEmpty) {
          capturedFilename = request.files.first.filename;
        }
      }

      final responseBody = jsonEncode({
        'message': 'Sighting submitted successfully',
        'sighting_id': 'sght-live-uuid-9988',
        'detected_faces': 1,
        'matched_person_id': 'mp-test-001',
      });

      return http.StreamedResponse(
        Stream.value(utf8.encode(responseBody)),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ReportSightingForm(
          linkedPerson: samplePerson,
          initialImageBytes: validPngBytes,
          httpClient: mockClient,
        ),
      ),
    );

    // Enter location with coordinates
    final locationFinder = find.byType(TextFormField).first;
    await tester.enterText(
      locationFinder,
      'Bandra West Bus Depot (19.0544° N, 72.8402° E)',
    );
    await tester.pumpAndSettle();

    // Ensure submit button visible and tap
    await tester.ensureVisible(find.text('Submit Sighting Report'));
    await tester.tap(find.text('Submit Sighting Report'));
    await tester.pumpAndSettle();

    expect(requestReceived, isTrue);
    expect(capturedCitizenNote, contains('Rahul Verma (MP-2026-0099)'));
    expect(capturedAddress, 'Bandra West Bus Depot (19.0544° N, 72.8402° E)');
    expect(capturedFilename, isNotNull);
    expect(capturedLatitude, '19.0544');
    expect(capturedLongitude, '72.8402');

    // Confirmation dialog appears with the actual returned tracking ID
    expect(find.text('Sighting Logged'), findsOneWidget);
    expect(find.text('Tracking ID: sght-live-uuid-9988'), findsOneWidget);
    expect(
      find.textContaining('Linked Suggestion: Rahul Verma (MP-2026-0099)'),
      findsOneWidget,
    );

    // Close dialog
    await tester.tap(find.text('Return to Registry'));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'Submission with address only (no GPS coordinates) sends address and omits coordinates',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    String? capturedAddress;
    String? capturedLatitude;
    String? capturedLongitude;

    final mockClient = MockClient.streaming((request, bodyStream) async {
      if (request is http.MultipartRequest) {
        capturedAddress = request.fields['address'];
        capturedLatitude = request.fields['latitude'];
        capturedLongitude = request.fields['longitude'];
      }

      final responseBody = jsonEncode({
        'message': 'Sighting submitted successfully',
        'sighting_id': 'sght-addr-only-1234',
        'detected_faces': 1,
      });

      return http.StreamedResponse(
        Stream.value(utf8.encode(responseBody)),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ReportSightingForm(
          initialImageBytes: validPngBytes,
          httpClient: mockClient,
        ),
      ),
    );

    // Enter address text without any coordinates
    final locationFinder = find.byType(TextFormField).first;
    await tester.enterText(
      locationFinder,
      'Near Dadar West Flower Market, Senapati Bapat Marg',
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Submit Sighting Report'));
    await tester.tap(find.text('Submit Sighting Report'));
    await tester.pumpAndSettle();

    expect(capturedAddress, 'Near Dadar West Flower Market, Senapati Bapat Marg');
    expect(capturedLatitude, isNull);
    expect(capturedLongitude, isNull);
    expect(find.text('Tracking ID: sght-addr-only-1234'), findsOneWidget);
  });

  testWidgets('Unsuccessful HTTP 422 displays meaningful error and preserves form data',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockClient = MockClient.streaming((request, bodyStream) async {
      final responseBody = jsonEncode({
        'error': 'No faces detected in the sighting photo',
        'detected_faces': 0,
      });

      return http.StreamedResponse(
        Stream.value(utf8.encode(responseBody)),
        422,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ReportSightingForm(
          initialImageBytes: validPngBytes,
          httpClient: mockClient,
        ),
      ),
    );

    // Enter location
    final locationFinder = find.byType(TextFormField).first;
    await tester.enterText(locationFinder, 'Dadar Central Station');
    await tester.pumpAndSettle();

    // Submit
    await tester.ensureVisible(find.text('Submit Sighting Report'));
    await tester.tap(find.text('Submit Sighting Report'));
    await tester.pumpAndSettle();

    // Error dialog displayed
    expect(find.text('Submission Failed'), findsOneWidget);
    expect(
      find.text('No faces detected in the sighting photo'),
      findsOneWidget,
    );

    // Dismiss error dialog
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Form data is preserved!
    expect(find.text('Dadar Central Station'), findsOneWidget);
    expect(find.text('Photo attached'), findsOneWidget);
  });

  testWidgets('Network failure displays server connection error and does not clear form',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockClient = MockClient.streaming((request, bodyStream) async {
      throw const SocketException('Connection refused');
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ReportSightingForm(
          apiBaseUrl: 'http://10.0.2.2:5000',
          initialImageBytes: validPngBytes,
          httpClient: mockClient,
        ),
      ),
    );

    final locationFinder = find.byType(TextFormField).first;
    await tester.enterText(locationFinder, 'Thane Station Platform 2');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Submit Sighting Report'));
    await tester.tap(find.text('Submit Sighting Report'));
    await tester.pumpAndSettle();

    expect(find.text('Submission Failed'), findsOneWidget);
    expect(
      find.textContaining('Unable to connect to UniSafe server at http://10.0.2.2:5000'),
      findsOneWidget,
    );

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Form data preserved
    expect(find.text('Thane Station Platform 2'), findsOneWidget);
    expect(find.text('Photo attached'), findsOneWidget);
  });
}
