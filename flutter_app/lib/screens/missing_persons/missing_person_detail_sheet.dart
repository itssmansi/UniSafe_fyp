import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/missing_person.dart';
import '../../theme/unisafe_theme.dart';
import 'report_sighting_form.dart';

/// Modal Bottom Sheet or Screen presenting full Missing Person Dossier to citizens
class MissingPersonDetailSheet extends StatelessWidget {
  final MissingPerson person;

  const MissingPersonDetailSheet({
    super.key,
    required this.person,
  });

  static void show(BuildContext context, MissingPerson person) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MissingPersonDetailSheet(person: person),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, d MMM yyyy • h:mm a');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: UniSafeTheme.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(UniSafeTheme.radiusXl),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: UniSafeTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: UniSafeTheme.midnightLight,
                        borderRadius: BorderRadius.circular(UniSafeTheme.radiusSm),
                        border: Border.all(color: UniSafeTheme.border),
                      ),
                      child: Text(
                        person.caseCode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: UniSafeTheme.midnightBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: UniSafeTheme.amberLight,
                        borderRadius: BorderRadius.circular(UniSafeTheme.radiusSm),
                        border: Border.all(color: UniSafeTheme.amberBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: UniSafeTheme.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            person.status.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: UniSafeTheme.amber,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20, color: UniSafeTheme.textMuted),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: UniSafeTheme.border),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo Placeholder / Hero Photo Card
                  _buildHeroPhoto(context),

                  const SizedBox(height: 16),

                  // Subject Name & Demographics
                  Text(
                    person.fullName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: UniSafeTheme.textDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildChip(Icons.cake_outlined, person.age != null ? '${person.age} yrs old' : 'Age Unrecorded'),
                      const SizedBox(width: 6),
                      _buildChip(Icons.person_outline, person.gender ?? 'Unspecified'),
                      if (person.height != null) ...[
                        const SizedBox(width: 6),
                        _buildChip(Icons.straighten, person.height!),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Detail Rows Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
                      border: Border.all(color: UniSafeTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                          icon: Icons.location_on_outlined,
                          iconColor: UniSafeTheme.crimson,
                          label: 'Last Seen Location',
                          value: person.lastSeenLocation,
                        ),
                        const Divider(height: 16, color: UniSafeTheme.borderSubtle),
                        _buildDetailRow(
                          icon: Icons.access_time,
                          iconColor: UniSafeTheme.midnightBlue,
                          label: 'Incident Date & Time',
                          value: person.lastSeenDate != null
                              ? dateFormat.format(person.lastSeenDate!)
                              : 'Date Unrecorded',
                        ),
                        if (person.clothing != null) ...[
                          const Divider(height: 16, color: UniSafeTheme.borderSubtle),
                          _buildDetailRow(
                            icon: Icons.checkroom_outlined,
                            iconColor: UniSafeTheme.amber,
                            label: 'Reported Clothing',
                            value: person.clothing!,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Distinguishing Narrative Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
                      border: Border.all(color: UniSafeTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description & Distinguishing Features',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: UniSafeTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          person.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: UniSafeTheme.textMain,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Contact Station Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: UniSafeTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
                      border: Border.all(color: UniSafeTheme.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, size: 20, color: UniSafeTheme.midnightBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Investigating Jurisdiction',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: UniSafeTheme.midnightBlue,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                person.contactAuthority,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: UniSafeTheme.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close sheet
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ReportSightingForm(linkedPerson: person),
                          ),
                        );
                      },
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text(
                        'Report Sighting of This Person',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UniSafeTheme.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: UniSafeTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(UniSafeTheme.radiusSm),
        border: Border.all(color: UniSafeTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: UniSafeTheme.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: UniSafeTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: UniSafeTheme.textLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: UniSafeTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroPhoto(BuildContext context) {
    if (person.photoUrl != null && person.photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(UniSafeTheme.radiusLg),
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: UniSafeTheme.surfaceSubtle,
            borderRadius: BorderRadius.circular(UniSafeTheme.radiusLg),
            boxShadow: UniSafeTheme.shadowSm,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                person.photoUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildHeroPlaceholder();
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildHeroPlaceholder();
                },
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const Text(
                    'Official Case Photograph',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(UniSafeTheme.radiusSm),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: UniSafeTheme.teal),
                      SizedBox(width: 4),
                      Text(
                        'Verified Reference Photo',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _buildHeroPlaceholder();
  }

  Widget _buildHeroPlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            person.placeholderColor,
            person.placeholderColor.withValues(alpha: 0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(UniSafeTheme.radiusLg),
        boxShadow: UniSafeTheme.shadowSm,
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    person.initials,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Official Case Photograph',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(UniSafeTheme.radiusSm),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: UniSafeTheme.teal),
                  SizedBox(width: 4),
                  Text(
                    'Official Reference Case',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
