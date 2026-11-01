import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisafe_app/models/missing_person.dart';
import 'package:unisafe_app/screens/missing_persons/missing_persons_screen.dart';
import 'package:unisafe_app/screens/missing_persons/missing_person_detail_sheet.dart';

void main() {
  group('MissingPerson Model Tests', () {
    test('fromJson parses photo_url correctly', () {
      final json = {
        'id': 'test-uuid-1',
        'case_code': 'MP-2026-0001',
        'full_name': 'Aarav Sharma',
        'age': 15,
        'gender': 'Male',
        'last_seen_date': '2026-10-01T12:00:00Z',
        'description': 'Last Seen Address: Bandra West, Mumbai',
        'status': 'Missing',
        'photo_url': 'https://example.com/photos/aarav.jpg',
      };

      final person = MissingPerson.fromJson(json);
      expect(person.id, 'test-uuid-1');
      expect(person.caseCode, 'MP-2026-0001');
      expect(person.fullName, 'Aarav Sharma');
      expect(person.photoUrl, 'https://example.com/photos/aarav.jpg');
    });

    test('fromJson handles null or empty photo_url gracefully', () {
      final jsonNoPhoto = {
        'id': 'test-uuid-2',
        'case_code': 'MP-2026-0002',
        'full_name': 'Priya Deshmukh',
        'photo_url': null,
      };
      final person1 = MissingPerson.fromJson(jsonNoPhoto);
      expect(person1.photoUrl, isNull);

      final jsonEmptyPhoto = {
        'id': 'test-uuid-3',
        'case_code': 'MP-2026-0003',
        'full_name': 'Rohan Kulkarni',
        'photo_url': '   ',
      };
      final person2 = MissingPerson.fromJson(jsonEmptyPhoto);
      expect(person2.photoUrl, isNull);
    });
  });

  group('MissingPersonsScreen UI Tests', () {
    testWidgets('Extra Report buttons are removed from MissingPersonsScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MissingPersonsScreen(),
        ),
      );

      // Verify that the top prompt banner is removed
      expect(find.text('Spotted Someone Missing?'), findsNothing);
      expect(find.text('Upload a photo to run automated facial recognition matching.'), findsNothing);

      // Verify that FloatingActionButton is removed
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('MissingPersonDetailSheet Tests', () {
    testWidgets('Detail sheet renders person with fallback placeholder when photoUrl is null', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const personWithoutPhoto = MissingPerson(
        id: 'test-1',
        caseCode: 'MP001',
        fullName: 'John Doe',
        lastSeenLocation: 'Bandra',
        description: 'Wearing black jacket',
        photoUrl: null,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MissingPersonDetailSheet(person: personWithoutPhoto),
          ),
        ),
      );

      // Initials placeholder should be visible
      expect(find.text('JD'), findsOneWidget);
      expect(find.text('Official Case Photograph'), findsOneWidget);
      expect(find.text('Official Reference Case'), findsOneWidget);

      // Report Sighting of this Person button must be present
      expect(find.text('Report Sighting of This Person'), findsOneWidget);
    });

    testWidgets('Detail sheet renders photo widget when photoUrl is provided', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const personWithPhoto = MissingPerson(
        id: 'test-2',
        caseCode: 'MP002',
        fullName: 'Jane Smith',
        lastSeenLocation: 'Dadar',
        description: 'Wearing red sweater',
        photoUrl: 'https://example.com/photo.jpg',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MissingPersonDetailSheet(person: personWithPhoto),
          ),
        ),
      );

      // Image.network widget should be used
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Verified Reference Photo'), findsOneWidget);
      expect(find.text('Report Sighting of This Person'), findsOneWidget);
    });
  });
}
