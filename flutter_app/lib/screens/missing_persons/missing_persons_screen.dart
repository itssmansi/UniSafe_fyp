// import 'package:flutter/material.dart';
// import '../../models/missing_person.dart';
// import '../../theme/unisafe_theme.dart';
// import 'missing_person_detail_sheet.dart';
// import 'report_sighting_form.dart';
// import 'dart:convert';
// import 'package:http/http.dart' as http;

// /// Standalone Citizen Missing Persons Registry & Sightings Screen
// class MissingPersonsScreen extends StatefulWidget {
//   const MissingPersonsScreen({super.key});

//   @override
//   State<MissingPersonsScreen> createState() => _MissingPersonsScreenState();
// }

// class _MissingPersonsScreenState extends State<MissingPersonsScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   List<MissingPerson> _allCases = [];
//   bool _isLoading = true;
//   String? _errorMessage;

//   String _searchQuery = '';
//   String _selectedFilter = 'All'; // 'All', 'Recent', 'Minors', 'Seniors'

//   @override
// void initState() {
//   super.initState();
//   _loadCases();
// }

// Future<void> _loadCases() async {
//   if (mounted) {
//     setState(() {
//       _isLoading = _allCases.isEmpty;
//       _errorMessage = null;
//     });
//   }

//   try {
//     final response = await http
//         .get(Uri.parse('http://10.0.2.2:5000/api/missing-persons'))
//         .timeout(const Duration(seconds: 15));

//     if (response.statusCode != 200) {
//       throw Exception('Server returned ${response.statusCode}');
//     }

//     final data = jsonDecode(response.body) as Map<String, dynamic>;
//     final records = data['missing_persons'] as List<dynamic>;

//     final cases = records
//         .map((record) => MissingPerson.fromJson(
//               record as Map<String, dynamic>,
//             ))
//         .toList();

//     if (!mounted) return;

//     setState(() {
//       _allCases = cases;
//       _isLoading = false;
//       _errorMessage = null;
//     });
//   } catch (e) {
//     if (!mounted) return;

//     setState(() {
//       _isLoading = false;
//       _errorMessage = 'Could not load missing-person cases. Check your connection and try again.';
//     });

//     debugPrint('Missing persons API error: $e');
//   }
// }
//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }

//   List<MissingPerson> get _filteredCases {
//   return _allCases
//       .where((person) => person.status.toLowerCase() == 'missing')
//       .toList()
//       .filterCases(
//         query: _searchQuery,
//         filter: _selectedFilter,
//       );
//   }

//   Future<void> _handleRefresh() async {
//   await _loadCases();
//   }

//   void _showInfoDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(UniSafeTheme.radiusLg),
//         ),
//         backgroundColor: Colors.white,
//         title: const Row(
//           children: [
//             Icon(Icons.shield_outlined, color: UniSafeTheme.midnightBlue),
//             SizedBox(width: 8),
//             Text(
//               'UniSafe Citizen Portal',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w700,
//                 color: UniSafeTheme.textDark,
//               ),
//             ),
//           ],
//         ),
//         content: const Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'This module allows citizens to stay informed about active missing persons and submit sighting photographs with approximate locations.',
//               style: TextStyle(fontSize: 13, height: 1.45, color: UniSafeTheme.textMain),
//             ),
//             SizedBox(height: 10),
//             Text(
//               'How It Works:\n'
//               '1. Law enforcement indexes reference photos into 512-D vectors.\n'
//               '2. Citizen sighting photos are cross-referenced using InsightFace AI.\n'
//               '3. High similarity matches alert field officers for immediate physical verification.',
//               style: TextStyle(fontSize: 12, height: 1.5, color: UniSafeTheme.textMuted),
//             ),
//             SizedBox(height: 10),
//             Text(
//               'Safety Notice: Automated AI match scores alone never alter case status. Official field verification by authorized police officers is strictly mandatory.',
//               style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: UniSafeTheme.amber),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('Understood'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final filtered = _filteredCases;

//     return Scaffold(
//       backgroundColor: UniSafeTheme.background,
//       appBar: AppBar(
//         titleSpacing: 16,
//         title: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(6),
//               decoration: BoxDecoration(
//                 color: UniSafeTheme.midnightBlue,
//                 borderRadius: BorderRadius.circular(UniSafeTheme.radiusSm),
//               ),
//               child: const Icon(
//                 Icons.shield,
//                 color: Colors.white,
//                 size: 18,
//               ),
//             ),
//             const SizedBox(width: 10),
//             const Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'UniSafe Missing Persons',
//                   style: TextStyle(
//                     fontSize: 15.5,
//                     fontWeight: FontWeight.w800,
//                     color: UniSafeTheme.textDark,
//                     letterSpacing: -0.2,
//                   ),
//                 ),
//                 Text(
//                   'Citizen Registry & Sighting Network',
//                   style: TextStyle(
//                     fontSize: 11,
//                     fontWeight: FontWeight.w500,
//                     color: UniSafeTheme.textMuted,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.info_outline, size: 21, color: UniSafeTheme.textMuted),
//             onPressed: _showInfoDialog,
//             tooltip: 'Portal Information',
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: () {
//           Navigator.of(context).push(
//             MaterialPageRoute(
//               builder: (context) => const ReportSightingForm(),
//             ),
//           );
//         },
//         backgroundColor: UniSafeTheme.teal,
//         foregroundColor: Colors.white,
//         elevation: 3,
//         icon: const Icon(Icons.add_a_photo_outlined, size: 19),
//         label: const Text(
//           'Report Sighting',
//           style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
//         ),
//       ),
//       body: RefreshIndicator(
//         onRefresh: _handleRefresh,
//         color: UniSafeTheme.midnightBlue,
//         backgroundColor: Colors.white,
//         child: SingleChildScrollView(
//           physics: const AlwaysScrollableScrollPhysics(),
//           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Hero Action Card: Report Sighting Prompt
//               _buildReportPromptCard(context),

//               const SizedBox(height: 14),

//               // KPI Metrics Ribbon
//               _buildKpiRibbon(),

//               const SizedBox(height: 14),

//               // Search Bar
//               _buildSearchBar(),

//               const SizedBox(height: 10),

//               // Filter Chips
//               _buildFilterChips(),

//               const SizedBox(height: 16),

//               // Section Header
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     'Active Missing Cases',
//                     style: TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.w700,
//                       color: UniSafeTheme.textDark,
//                     ),
//                   ),
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                     decoration: BoxDecoration(
//                       color: UniSafeTheme.surfaceSubtle,
//                       borderRadius: BorderRadius.circular(UniSafeTheme.radiusSm),
//                       border: Border.all(color: UniSafeTheme.border),
//                     ),
//                     child: Text(
//                       '${filtered.length} Case${filtered.length == 1 ? '' : 's'}',
//                       style: const TextStyle(
//                         fontSize: 11,
//                         fontWeight: FontWeight.w700,
//                         color: UniSafeTheme.textMuted,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),

//               const SizedBox(height: 10),

//             // Loading, Error, Empty State or Cases
//             if (_isLoading && _allCases.isEmpty)
//               const Center(
//                 child: Padding(
//                   padding: EdgeInsets.all(32),
//                   child: CircularProgressIndicator(),
//                 ),
//               )
//             else if (_errorMessage != null && _allCases.isEmpty)
//               Center(
//                 child: Padding(
//                   padding: const EdgeInsets.all(24),
//                   child: Column(
//                     children: [
//                       const Icon(Icons.wifi_off, size: 36),
//                       const SizedBox(height: 8),
//                       Text(
//                         _errorMessage!,
//                         textAlign: TextAlign.center,
//                       ),
//                       const SizedBox(height: 12),
//                       ElevatedButton(
//                         onPressed: _loadCases,
//                         child: const Text('Retry'),
//                       ),
//                     ],
//                   ),
//                 ),
//               )
//             else if (filtered.isEmpty)
//               _buildEmptyState()
//             else
//               ListView.separated(
//                 shrinkWrap: true,
//                 physics: const NeverScrollableScrollPhysics(),
//                 itemCount: filtered.length,
//                 separatorBuilder: (context, index) => const SizedBox(height: 10),
//                 itemBuilder: (context, index) {
//                   final person = filtered[index];
//                   return _buildMissingPersonCard(context, person);
//                 },
//               ),
//               const SizedBox(height: 72), // Clearance for Floating Action Button
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // Hero Card for Reporting Sightings
//   Widget _buildReportPromptCard(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(UniSafeTheme.radiusLg),
//         border: Border.all(color: UniSafeTheme.border),
//         boxShadow: UniSafeTheme.shadowSm,
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(10),
//             decoration: BoxDecoration(
//               color: UniSafeTheme.tealLight,
//               borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
//             ),
//             child: const Icon(
//               Icons.camera_alt_rounded,
//               color: UniSafeTheme.teal,
//               size: 24,
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'Spotted Someone Missing?',
//                   style: TextStyle(
//                     fontSize: 13.5,
//                     fontWeight: FontWeight.w700,
//                     color: UniSafeTheme.textDark,
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 const Text(
//                   'Upload a photo to run automated facial recognition matching.',
//                   style: TextStyle(
//                     fontSize: 11.5,
//                     color: UniSafeTheme.textMuted,
//                     height: 1.3,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 6),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.of(context).push(
//                 MaterialPageRoute(
//                   builder: (context) => const ReportSightingForm(),
//                 ),
//               );
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: UniSafeTheme.teal,
//               foregroundColor: Colors.white,
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//               minimumSize: const Size(60, 34),
//             ),
//             child: const Text('Report', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
//           ),
//         ],
//       ),
//     );
//   }

//   // Quick KPI Stats Ribbon
//   Widget _buildKpiRibbon() {
//     return Row(
//       children: [
//         Expanded(
//           child: _buildKpiCard(
//             title: 'Active Alerts',
//             value: '${_allCases.length}',
//             icon: Icons.notifications_active_outlined,
//             iconColor: UniSafeTheme.amber,
//             bgColor: UniSafeTheme.amberLight,
//           ),
//         ),
//         const SizedBox(width: 8),
//         Expanded(
//           child: _buildKpiCard(
//             title: 'Sightings',
//             value: '18',
//             icon: Icons.remove_red_eye_outlined,
//             iconColor: UniSafeTheme.midnightBlue,
//             bgColor: UniSafeTheme.midnightLight,
//           ),
//         ),
//         const SizedBox(width: 8),
//         Expanded(
//           child: _buildKpiCard(
//             title: 'Located',
//             value: '12',
//             icon: Icons.check_circle_outline,
//             iconColor: UniSafeTheme.teal,
//             bgColor: UniSafeTheme.tealLight,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildKpiCard({
//     required String title,
//     required String value,
//     required IconData icon,
//     required Color iconColor,
//     required Color bgColor,
//   }) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
//         border: Border.all(color: UniSafeTheme.border),
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(5),
//             decoration: BoxDecoration(
//               color: bgColor,
//               borderRadius: BorderRadius.circular(UniSafeTheme.radiusSm),
//             ),
//             child: Icon(icon, color: iconColor, size: 14),
//           ),
//           const SizedBox(width: 6),
//           Flexible(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   value,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     fontSize: 13,
//                     fontWeight: FontWeight.w800,
//                     color: UniSafeTheme.textDark,
//                     height: 1.1,
//                   ),
//                 ),
//                 Text(
//                   title,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     fontSize: 9.5,
//                     fontWeight: FontWeight.w500,
//                     color: UniSafeTheme.textLight,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Search Bar
//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       onChanged: (val) {
//         setState(() {
//           _searchQuery = val;
//         });
//       },
//       decoration: InputDecoration(
//         hintText: 'Search by name, location, or case code...',
//         prefixIcon: const Icon(Icons.search, size: 20, color: UniSafeTheme.textMuted),
//         suffixIcon: _searchQuery.isNotEmpty
//             ? IconButton(
//                 icon: const Icon(Icons.clear, size: 18, color: UniSafeTheme.textMuted),
//                 onPressed: () {
//                   _searchController.clear();
//                   setState(() {
//                     _searchQuery = '';
//                   });
//                 },
//               )
//             : null,
//       ),
//     );
//   }

//   // Filter Chips
//   Widget _buildFilterChips() {
//     final filters = ['All', 'Recent', 'Minors', 'Seniors'];
//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       child: Row(
//         children: filters.map((f) {
//           final isSelected = _selectedFilter == f;
//           return Padding(
//             padding: const EdgeInsets.only(right: 6),
//             child: ChoiceChip(
//               label: Text(f),
//               selected: isSelected,
//               onSelected: (selected) {
//                 if (selected) {
//                   setState(() {
//                     _selectedFilter = f;
//                   });
//                 }
//               },
//               labelStyle: TextStyle(
//                 fontSize: 12,
//                 fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
//                 color: isSelected ? Colors.white : UniSafeTheme.textMuted,
//               ),
//               selectedColor: UniSafeTheme.midnightBlue,
//               backgroundColor: Colors.white,
//               side: BorderSide(
//                 color: isSelected ? UniSafeTheme.midnightBlue : UniSafeTheme.border,
//               ),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(UniSafeTheme.radiusSm),
//               ),
//               showCheckmark: false,
//               visualDensity: VisualDensity.compact,
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }

//   // Missing Person Card
//   Widget _buildMissingPersonCard(BuildContext context, MissingPerson person) {
//     return InkWell(
//       onTap: () => MissingPersonDetailSheet.show(context, person),
//       borderRadius: BorderRadius.circular(UniSafeTheme.radiusLg),
//       child: Container(
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(UniSafeTheme.radiusLg),
//           border: Border.all(color: UniSafeTheme.border),
//           boxShadow: UniSafeTheme.shadowXs,
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Top Row: Case Code + Status Badge
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
//                   decoration: BoxDecoration(
//                     color: UniSafeTheme.midnightLight,
//                     borderRadius: BorderRadius.circular(UniSafeTheme.radiusSm),
//                     border: Border.all(color: const Color(0xFFE2E8F0)),
//                   ),
//                   child: Text(
//                     person.caseCode,
//                     style: const TextStyle(
//                       fontFamily: 'monospace',
//                       fontSize: 11,
//                       fontWeight: FontWeight.w700,
//                       color: UniSafeTheme.midnightBlue,
//                     ),
//                   ),
//                 ),
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
//                   decoration: BoxDecoration(
//                     color: UniSafeTheme.amberLight,
//                     borderRadius: BorderRadius.circular(UniSafeTheme.radiusSm),
//                     border: Border.all(color: UniSafeTheme.amberBorder),
//                   ),
//                   child: Row(
//                     children: [
//                       Container(
//                         width: 5,
//                         height: 5,
//                         decoration: const BoxDecoration(
//                           color: UniSafeTheme.amber,
//                           shape: BoxShape.circle,
//                         ),
//                       ),
//                       const SizedBox(width: 4),
//                       Text(
//                         person.status.toUpperCase(),
//                         style: const TextStyle(
//                           fontSize: 9.5,
//                           fontWeight: FontWeight.w700,
//                           color: UniSafeTheme.amber,
//                           letterSpacing: 0.4,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 10),

//             // Middle Row: Photo Placeholder + Details
//             Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Photo Placeholder Avatar
//                 Container(
//                   width: 68,
//                   height: 68,
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                       colors: [
//                         person.placeholderColor,
//                         person.placeholderColor.withValues(alpha: 0.75),
//                       ],
//                     ),
//                     borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
//                     boxShadow: UniSafeTheme.shadowXs,
//                   ),
//                   child: Center(
//                     child: Text(
//                       person.initials,
//                       style: const TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.w800,
//                         color: Colors.white,
//                         letterSpacing: 1.0,
//                       ),
//                     ),
//                   ),
//                 ),

//                 const SizedBox(width: 12),

//                 // Details Column
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         person.fullName,
//                         style: const TextStyle(
//                           fontSize: 14.5,
//                           fontWeight: FontWeight.w700,
//                           color: UniSafeTheme.textDark,
//                           letterSpacing: -0.2,
//                         ),
//                       ),
//                       const SizedBox(height: 2),
//                       Text(
//                         '${person.age != null ? '${person.age} yrs' : 'Age N/A'} • ${person.gender ?? 'Unspecified'}',
//                         style: const TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.w500,
//                           color: UniSafeTheme.textMuted,
//                         ),
//                       ),
//                       const SizedBox(height: 6),
//                       Row(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Icon(
//                             Icons.location_on_outlined,
//                             size: 13,
//                             color: UniSafeTheme.crimson,
//                           ),
//                           const SizedBox(width: 3),
//                           Expanded(
//                             child: Text(
//                               person.lastSeenLocation,
//                               style: const TextStyle(
//                                 fontSize: 11.5,
//                                 color: UniSafeTheme.textMuted,
//                               ),
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 10),

//             // Description snippet
//             Text(
//               person.description,
//               maxLines: 2,
//               overflow: TextOverflow.ellipsis,
//               style: const TextStyle(
//                 fontSize: 11.5,
//                 color: UniSafeTheme.textMain,
//                 height: 1.35,
//               ),
//             ),

//             const SizedBox(height: 10),
//             const Divider(height: 1, color: UniSafeTheme.borderSubtle),
//             const SizedBox(height: 8),

//             // Card Bottom Actions
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 TextButton.icon(
//                   onPressed: () => MissingPersonDetailSheet.show(context, person),
//                   icon: const Icon(Icons.menu_book_outlined, size: 14),
//                   label: const Text('View Dossier'),
//                   style: TextButton.styleFrom(
//                     foregroundColor: UniSafeTheme.midnightBlue,
//                     padding: const EdgeInsets.symmetric(horizontal: 6),
//                     visualDensity: VisualDensity.compact,
//                     textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
//                   ),
//                 ),
//                 ElevatedButton.icon(
//                   onPressed: () {
//                     Navigator.of(context).push(
//                       MaterialPageRoute(
//                         builder: (context) => ReportSightingForm(linkedPerson: person),
//                       ),
//                     );
//                   },
//                   icon: const Icon(Icons.camera_alt_outlined, size: 13),
//                   label: const Text('Report Sighting'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: UniSafeTheme.tealLight,
//                     foregroundColor: UniSafeTheme.tealHover,
//                     elevation: 0,
//                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                     visualDensity: VisualDensity.compact,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(UniSafeTheme.radiusSm),
//                       side: const BorderSide(color: UniSafeTheme.tealBorder),
//                     ),
//                     textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Empty State Widget
//   Widget _buildEmptyState() {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(UniSafeTheme.radiusLg),
//         border: Border.all(color: UniSafeTheme.border),
//       ),
//       child: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(14),
//             decoration: BoxDecoration(
//               color: UniSafeTheme.surfaceSubtle,
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(
//               Icons.search_off_rounded,
//               size: 32,
//               color: UniSafeTheme.textLight,
//             ),
//           ),
//           const SizedBox(height: 12),
//           const Text(
//             'No Cases Match Your Query',
//             style: TextStyle(
//               fontSize: 14.5,
//               fontWeight: FontWeight.w700,
//               color: UniSafeTheme.textDark,
//             ),
//           ),
//           const SizedBox(height: 4),
//           const Text(
//             'Try searching by a different name, area landmark, or adjust your filter.',
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontSize: 12,
//               color: UniSafeTheme.textMuted,
//             ),
//           ),
//           const SizedBox(height: 12),
//           OutlinedButton(
//             onPressed: () {
//               _searchController.clear();
//               setState(() {
//                 _searchQuery = '';
//                 _selectedFilter = 'All';
//               });
//             },
//             style: OutlinedButton.styleFrom(
//               foregroundColor: UniSafeTheme.midnightBlue,
//               side: const BorderSide(color: UniSafeTheme.border),
//             ),
//             child: const Text('Reset Search & Filters', style: TextStyle(fontSize: 12)),
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// Helper extension on List<MissingPerson>
// extension on List<MissingPerson> {
//   List<MissingPerson> filterCases({
//     required String query,
//     required String filter,
//   }) {
//     final cleanQuery = query.toLowerCase().trim();

//     return where((c) {
//       // 1. Text filter
//       if (cleanQuery.isNotEmpty) {
//         final matchesName = c.fullName.toLowerCase().contains(cleanQuery);
//         final matchesCode = c.caseCode.toLowerCase().contains(cleanQuery);
//         final matchesLoc = c.lastSeenLocation.toLowerCase().contains(cleanQuery);
//         final matchesDesc = c.description.toLowerCase().contains(cleanQuery);
//         if (!matchesName && !matchesCode && !matchesLoc && !matchesDesc) {
//           return false;
//         }
//       }

//       // 2. Category filter
//       if (filter == 'Minors') {
//         return (c.age != null && c.age! < 18);
//       } else if (filter == 'Seniors') {
//         return (c.age != null && c.age! >= 60);
//       } else if (filter == 'Recent') {
//         if (c.lastSeenDate == null) return false;
//         final difference = DateTime.now().difference(c.lastSeenDate!);
//         return difference.inHours <= 24;
//       }

//       return true;
//     }).toList();
//   }
// }


import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/missing_person.dart';
import '../../theme/unisafe_theme.dart';
import 'missing_person_detail_sheet.dart';

/// Standalone Citizen Missing Persons Registry & Sightings Screen
class MissingPersonsScreen extends StatefulWidget {
  const MissingPersonsScreen({super.key});

  @override
  State<MissingPersonsScreen> createState() =>
      _MissingPersonsScreenState();
}

class _MissingPersonsScreenState extends State<MissingPersonsScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  List<MissingPerson> _allCases = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  // Fetch missing-person cases from the Flask API.
  Future<void> _loadCases() async {
    if (!mounted) return;

    setState(() {
      _isLoading = _allCases.isEmpty;
      _errorMessage = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse(
              'http://10.0.2.2:5000/api/missing-persons',
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'Server returned ${response.statusCode}',
        );
      }

      final data =
          jsonDecode(response.body) as Map<String, dynamic>;

      final records = data['missing_persons'] as List<dynamic>;

      final cases = records
          .map(
            (record) => MissingPerson.fromJson(
              record as Map<String, dynamic>,
            ),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _allCases = cases;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not load missing-person cases. '
            'Check your connection and try again.';
      });

      debugPrint('Missing persons API error: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Show only active missing cases, then apply search and filters.
  List<MissingPerson> get _filteredCases {
    return _allCases
        .where(
          (person) =>
              person.status.toLowerCase() == 'missing',
        )
        .toList()
        .filterCases(
          query: _searchQuery,
          filter: _selectedFilter,
        );
  }

  Future<void> _handleRefresh() async {
    await _loadCases();
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            UniSafeTheme.radiusLg,
          ),
        ),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(
              Icons.shield_outlined,
              color: UniSafeTheme.midnightBlue,
            ),
            SizedBox(width: 8),
            Text(
              'UniSafe Citizen Portal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: UniSafeTheme.textDark,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This module allows citizens to stay informed about active missing persons and submit sighting photographs with approximate locations.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: UniSafeTheme.textMain,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'How It Works:\n'
              '1. Law enforcement indexes reference photos into 512-D vectors.\n'
              '2. Citizen sighting photos are cross-referenced using InsightFace AI.\n'
              '3. High similarity matches alert field officers for immediate physical verification.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: UniSafeTheme.textMuted,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Safety Notice: Automated AI match scores alone never alter case status. Official field verification by authorized police officers is strictly mandatory.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: UniSafeTheme.amber,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCases;

    return Scaffold(
      backgroundColor: UniSafeTheme.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: UniSafeTheme.midnightBlue,
                borderRadius: BorderRadius.circular(
                  UniSafeTheme.radiusSm,
                ),
              ),
              child: const Icon(
                Icons.shield,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UniSafe Missing Persons',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: UniSafeTheme.textDark,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Citizen Registry & Sighting Network',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: UniSafeTheme.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.info_outline,
              size: 21,
              color: UniSafeTheme.textMuted,
            ),
            onPressed: _showInfoDialog,
            tooltip: 'Portal Information',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: UniSafeTheme.midnightBlue,
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Metrics Ribbon
              _buildKpiRibbon(),

              const SizedBox(height: 14),

              // Search Bar
              _buildSearchBar(),

              const SizedBox(height: 10),

              // Filter Chips
              _buildFilterChips(),

              const SizedBox(height: 16),

              // Section Header
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Active Missing Cases',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: UniSafeTheme.textDark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: UniSafeTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(
                        UniSafeTheme.radiusSm,
                      ),
                      border: Border.all(
                        color: UniSafeTheme.border,
                      ),
                    ),
                    child: Text(
                      '${filtered.length} Case${filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: UniSafeTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Loading, Error, Empty State or Cases
              if (_isLoading && _allCases.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null &&
                  _allCases.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.wifi_off,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadCases,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final person = filtered[index];
                    return _buildMissingPersonCard(
                      context,
                      person,
                    );
                  },
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Quick KPI Stats Ribbon
  Widget _buildKpiRibbon() {
    final activeCount = _allCases
        .where(
          (person) =>
              person.status.toLowerCase() == 'missing',
        )
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            title: 'Active Alerts',
            value: '$activeCount',
            icon: Icons.notifications_active_outlined,
            iconColor: UniSafeTheme.amber,
            bgColor: UniSafeTheme.amberLight,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKpiCard(
            title: 'Sightings',
            value: '18',
            icon: Icons.remove_red_eye_outlined,
            iconColor: UniSafeTheme.midnightBlue,
            bgColor: UniSafeTheme.midnightLight,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKpiCard(
            title: 'Located',
            value: '12',
            icon: Icons.check_circle_outline,
            iconColor: UniSafeTheme.teal,
            bgColor: UniSafeTheme.tealLight,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          UniSafeTheme.radiusMd,
        ),
        border: Border.all(color: UniSafeTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(
                UniSafeTheme.radiusSm,
              ),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 14,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: UniSafeTheme.textDark,
                    height: 1.1,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: UniSafeTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Search Bar
  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (val) {
        setState(() {
          _searchQuery = val;
        });
      },
      decoration: InputDecoration(
        hintText:
            'Search by name, location, or case code...',
        prefixIcon: const Icon(
          Icons.search,
          size: 20,
          color: UniSafeTheme.textMuted,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.clear,
                  size: 18,
                  color: UniSafeTheme.textMuted,
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
      ),
    );
  }

  // Filter Chips
  Widget _buildFilterChips() {
    final filters = [
      'All',
      'Recent',
      'Minors',
      'Seniors',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedFilter = f;
                  });
                }
              },
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : UniSafeTheme.textMuted,
              ),
              selectedColor: UniSafeTheme.midnightBlue,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? UniSafeTheme.midnightBlue
                    : UniSafeTheme.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  UniSafeTheme.radiusSm,
                ),
              ),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  // Missing Person Card
  Widget _buildMissingPersonCard(
    BuildContext context,
    MissingPerson person,
  ) {
    return InkWell(
      onTap: () =>
          MissingPersonDetailSheet.show(context, person),
      borderRadius: BorderRadius.circular(
        UniSafeTheme.radiusLg,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            UniSafeTheme.radiusLg,
          ),
          border: Border.all(color: UniSafeTheme.border),
          boxShadow: UniSafeTheme.shadowXs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Case Code + Status Badge
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: UniSafeTheme.midnightLight,
                    borderRadius: BorderRadius.circular(
                      UniSafeTheme.radiusSm,
                    ),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    person.caseCode,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: UniSafeTheme.midnightBlue,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: UniSafeTheme.amberLight,
                    borderRadius: BorderRadius.circular(
                      UniSafeTheme.radiusSm,
                    ),
                    border: Border.all(
                      color: UniSafeTheme.amberBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: UniSafeTheme.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        person.status.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: UniSafeTheme.amber,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Middle Row: Photo / Thumbnail + Details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPersonPhotoThumbnail(person),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.fullName,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: UniSafeTheme.textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${person.age != null ? '${person.age} yrs' : 'Age N/A'} • ${person.gender ?? 'Unspecified'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: UniSafeTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: UniSafeTheme.crimson,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              person.lastSeenLocation,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: UniSafeTheme.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Description snippet
            Text(
              person.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: UniSafeTheme.textMain,
                height: 1.35,
              ),
            ),

            const SizedBox(height: 10),
            const Divider(
              height: 1,
              color: UniSafeTheme.borderSubtle,
            ),
            const SizedBox(height: 8),

            // Card Bottom Actions
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      MissingPersonDetailSheet.show(
                    context,
                    person,
                  ),
                  icon: const Icon(
                    Icons.menu_book_outlined,
                    size: 14,
                  ),
                  label: const Text('View Dossier'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        UniSafeTheme.midnightBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                    ),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      MissingPersonDetailSheet.show(
                    context,
                    person,
                  ),
                  icon: const Icon(
                    Icons.camera_alt_outlined,
                    size: 13,
                  ),
                  label: const Text('Report Sighting'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UniSafeTheme.tealLight,
                    foregroundColor: UniSafeTheme.tealHover,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        UniSafeTheme.radiusSm,
                      ),
                      side: const BorderSide(
                        color: UniSafeTheme.tealBorder,
                      ),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Empty State Widget
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 36,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          UniSafeTheme.radiusLg,
        ),
        border: Border.all(color: UniSafeTheme.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: UniSafeTheme.surfaceSubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 32,
              color: UniSafeTheme.textLight,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No Cases Match Your Query',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: UniSafeTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try searching by a different name, area landmark, or adjust your filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: UniSafeTheme.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedFilter = 'All';
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: UniSafeTheme.midnightBlue,
              side: const BorderSide(
                color: UniSafeTheme.border,
              ),
            ),
            child: const Text(
              'Reset Search & Filters',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonPhotoThumbnail(MissingPerson person) {
    if (person.photoUrl != null && person.photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
        child: SizedBox(
          width: 68,
          height: 68,
          child: Image.network(
            person.photoUrl!,
            width: 68,
            height: 68,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildPhotoPlaceholder(person);
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildPhotoPlaceholder(person);
            },
          ),
        ),
      );
    }
    return _buildPhotoPlaceholder(person);
  }

  Widget _buildPhotoPlaceholder(MissingPerson person) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            person.placeholderColor,
            person.placeholderColor.withValues(
              alpha: 0.75,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(
          UniSafeTheme.radiusMd,
        ),
        boxShadow: UniSafeTheme.shadowXs,
      ),
      child: Center(
        child: Text(
          person.initials,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

/// Helper extension on List<MissingPerson>
extension on List<MissingPerson> {
  List<MissingPerson> filterCases({
    required String query,
    required String filter,
  }) {
    final cleanQuery = query.toLowerCase().trim();

    return where((c) {
      // 1. Text filter
      if (cleanQuery.isNotEmpty) {
        final matchesName =
            c.fullName.toLowerCase().contains(cleanQuery);

        final matchesCode =
            c.caseCode.toLowerCase().contains(cleanQuery);

        final matchesLoc =
            c.lastSeenLocation.toLowerCase().contains(
                  cleanQuery,
                );

        final matchesDesc =
            c.description.toLowerCase().contains(
                  cleanQuery,
                );

        if (!matchesName &&
            !matchesCode &&
            !matchesLoc &&
            !matchesDesc) {
          return false;
        }
      }

      // 2. Category filter
      if (filter == 'Minors') {
        return c.age != null && c.age! < 18;
      }

      if (filter == 'Seniors') {
        return c.age != null && c.age! >= 60;
      }

      if (filter == 'Recent') {
        if (c.lastSeenDate == null) return false;

        final difference =
            DateTime.now().difference(c.lastSeenDate!);

        return difference.inHours >= 0 &&
            difference.inHours <= 24;
      }

      return true;
    }).toList();
  }
}
