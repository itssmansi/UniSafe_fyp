import 'package:flutter/material.dart';

/// Missing Person Model for Citizen App
class MissingPerson {
  final String id;
  final String caseCode;
  final String fullName;
  final int? age;
  final String? gender;
  final DateTime? lastSeenDate;
  final String lastSeenLocation;
  final String description;
  final String status;
  final String? height;
  final String? clothing;
  final String contactAuthority;
  final Color placeholderColor;
  final String? photoUrl;

  const MissingPerson({
    required this.id,
    required this.caseCode,
    required this.fullName,
    this.age,
    this.gender,
    this.lastSeenDate,
    required this.lastSeenLocation,
    required this.description,
    this.status = 'Missing',
    this.height,
    this.clothing,
    this.contactAuthority = 'Mumbai Police Cyber & Forensic Cell (Helpline: 112 / 1090)',
    this.placeholderColor = const Color(0xFF1E3A5F),
    this.photoUrl,
  });

  factory MissingPerson.fromJson(Map<String, dynamic> json) {
    final description = json['description']?.toString() ?? '';

    final addressMatch = RegExp(
      r'Last Seen Address:\s*(.+)',
      caseSensitive: false,
    ).firstMatch(description);

    final rawPhotoUrl = json['photo_url']?.toString();
    final photoUrl = (rawPhotoUrl != null && rawPhotoUrl.trim().isNotEmpty)
        ? rawPhotoUrl.trim()
        : null;

    return MissingPerson(
      id: json['id']?.toString() ?? '',
      caseCode: json['case_code']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Unknown',
      age: json['age'] is num ? (json['age'] as num).toInt() : null,
      gender: json['gender']?.toString(),
      lastSeenDate: DateTime.tryParse(
        json['last_seen_date']?.toString() ?? '',
      ),
      lastSeenLocation: addressMatch?.group(1)?.trim() ?? 'Location not available',
      description: description,
      status: json['status']?.toString() ?? 'Missing',
      photoUrl: photoUrl,
    );
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'MP';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  /// Sample mock cases for citizen UI preview and testing.
  /// Clearly labeled simulated profiles for demonstration.
  static List<MissingPerson> get sampleCases => [
        MissingPerson(
          id: 'mp-mock-001',
          caseCode: 'MP-2026-0081',
          fullName: 'Aarav Sharma [Sample]',
          age: 14,
          gender: 'Male',
          lastSeenDate: DateTime.now().subtract(const Duration(hours: 18)),
          lastSeenLocation: 'Near Bandra Terminus, Platform 4, Mumbai',
          description:
              'Wearing blue school uniform with navy backpack. Height approx 5 ft 2 in. Has a small visible birthmark near right ear.',
          status: 'Missing',
          height: '5 ft 2 in',
          clothing: 'Navy school shirt, grey trousers, black sneakers',
          contactAuthority: 'Bandra Police Station (+91 22 2642 1234)',
          placeholderColor: const Color(0xFF1E3A5F),
        ),
        MissingPerson(
          id: 'mp-mock-002',
          caseCode: 'MP-2026-0082',
          fullName: 'Priya Deshmukh [Sample]',
          age: 22,
          gender: 'Female',
          lastSeenDate: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
          lastSeenLocation: 'Dadar West Flower Market, Senapati Bapat Marg',
          description:
              'College student, last seen heading towards Dadar local train station. Carrying beige shoulder tote bag. Wearing silver framed glasses.',
          status: 'Missing',
          height: '5 ft 5 in',
          clothing: 'Yellow cotton kurta, blue jeans, white sandals',
          contactAuthority: 'Dadar Police Station (+91 22 2422 5555)',
          placeholderColor: const Color(0xFF0F766E),
        ),
        MissingPerson(
          id: 'mp-mock-003',
          caseCode: 'MP-2026-0083',
          fullName: 'Rohan Kulkarni [Sample]',
          age: 68,
          gender: 'Male',
          lastSeenDate: DateTime.now().subtract(const Duration(days: 3, hours: 10)),
          lastSeenLocation: 'Thane West, Near Gaodevi Market bus stop',
          description:
              'Senior citizen with mild memory loss. Speaks Marathi and Hindi. Walks with a slight limp, wearing silver wristwatch.',
          status: 'Missing',
          height: '5 ft 7 in',
          clothing: 'White khadi shirt, brown trousers, slip-on shoes',
          contactAuthority: 'Thane Central Police Station (+91 22 2533 1111)',
          placeholderColor: const Color(0xFF92400E),
        ),
        MissingPerson(
          id: 'mp-mock-004',
          caseCode: 'MP-2026-0084',
          fullName: 'Ananya Patel [Sample]',
          age: 9,
          gender: 'Female',
          lastSeenDate: DateTime.now().subtract(const Duration(hours: 8)),
          lastSeenLocation: 'Juhu Beach Promenade, Near Shivaji Statue',
          description:
              'Child separated from family during evening carnival. Hair tied in double ponytails with red hair clips. Responds to name "Anu".',
          status: 'Missing',
          height: '4 ft 1 in',
          clothing: 'Red floral frock, pink velcro shoes',
          contactAuthority: 'Santacruz Police Station (+91 22 2618 3333)',
          placeholderColor: const Color(0xFF4338CA),
        ),
        MissingPerson(
          id: 'mp-mock-005',
          caseCode: 'MP-2026-0085',
          fullName: 'Vikram Singh [Sample]',
          age: 31,
          gender: 'Male',
          lastSeenDate: DateTime.now().subtract(const Duration(days: 4, hours: 2)),
          lastSeenLocation: 'Andheri East Metro Concourse / Western Express Hwy',
          description:
              'Software professional, last reported commuting after work shift. Medium build, short black hair, sporting a light beard.',
          status: 'Missing',
          height: '5 ft 10 in',
          clothing: 'Black polo shirt, dark denim trousers, grey laptop bag',
          contactAuthority: 'Andheri Police Station (+91 22 2683 4444)',
          placeholderColor: const Color(0xFF334155),
        ),
      ];
}
