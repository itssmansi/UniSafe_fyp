import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/missing_person.dart';
import '../../theme/unisafe_theme.dart';

/// Screen or Modal Sheet for submitting a citizen sighting
class ReportSightingForm extends StatefulWidget {
  final MissingPerson? linkedPerson;
  final String apiBaseUrl;
  final http.Client? httpClient;
  final Uint8List? initialImageBytes;

  const ReportSightingForm({
    super.key,
    this.linkedPerson,
    this.apiBaseUrl = const String.fromEnvironment(
      'FLASK_API_BASE_URL',
      defaultValue: 'http://10.0.2.2:5000',
    ),
    this.httpClient,
    this.initialImageBytes,
  });

  @override
  State<ReportSightingForm> createState() => _ReportSightingFormState();
}

class _ReportSightingFormState extends State<ReportSightingForm> {
  final _formKey = GlobalKey<FormState>();

  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactEmailController = TextEditingController();

  DateTime _selectedDateTime = DateTime.now();
  XFile? _pickedImage;
  Uint8List? _imageBytes;
  bool _isAnonymous = false;
  bool _isSubmitting = false;
  String? _imageError;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.initialImageBytes != null) {
      _imageBytes = widget.initialImageBytes;
    }
    if (widget.linkedPerson != null) {
      _descriptionController.text =
          'Potential sighting of ${widget.linkedPerson!.fullName} (${widget.linkedPerson!.caseCode}). ';
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    _contactEmailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _pickedImage = file;
          _imageBytes = bytes;
          _imageError = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: UniSafeTheme.crimson,
        ),
      );
    }
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: UniSafeTheme.midnightBlue,
              onPrimary: Colors.white,
              onSurface: UniSafeTheme.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: UniSafeTheme.midnightBlue,
                onPrimary: Colors.white,
                onSurface: UniSafeTheme.textDark,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  void _fillMockGpsLocation() {
    setState(() {
      _locationController.text = 'Bandra Station West Concourse, Platform 1 (19.0544° N, 72.8402° E)';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Simulated GPS location filled'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    setState(() {
      _imageError = null;
    });

    if (_imageBytes == null) {
      setState(() {
        _imageError = 'A sighting photograph is required for facial matching.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Format citizen suggestion note if a specific case was linked
    final String? citizenSuggestion = widget.linkedPerson != null
        ? 'Citizen thinks this sighting may be ${widget.linkedPerson!.fullName} (${widget.linkedPerson!.caseCode}).'
        : null;

    // Parse coordinates from location text if available
    double? latitude;
    double? longitude;
    final coordMatch = RegExp(
      r'([0-9.]+)\s*°?\s*([NSns])?,\s*([0-9.]+)\s*°?\s*([EWew])?',
    ).firstMatch(_locationController.text);
    if (coordMatch != null) {
      final latVal = double.tryParse(coordMatch.group(1) ?? '');
      final latDir = coordMatch.group(2)?.toUpperCase();
      final lonVal = double.tryParse(coordMatch.group(3) ?? '');
      final lonDir = coordMatch.group(4)?.toUpperCase();
      if (latVal != null) {
        latitude = (latDir == 'S') ? -latVal : latVal;
      }
      if (lonVal != null) {
        longitude = (lonDir == 'W') ? -lonVal : lonVal;
      }
    }

    try {
      final cleanBase = widget.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$cleanBase/api/sightings');

      final request = http.MultipartRequest('POST', uri);

      // Add citizen_note if available (suggestion or observations)
      if (citizenSuggestion != null && citizenSuggestion.isNotEmpty) {
        request.fields['citizen_note'] = citizenSuggestion;
      } else if (_descriptionController.text.trim().isNotEmpty) {
        request.fields['citizen_note'] = _descriptionController.text.trim();
      }

      // Add optional address
      final enteredAddress = _locationController.text.trim();
      if (enteredAddress.isNotEmpty) {
        request.fields['address'] = enteredAddress;
      }

      // Add optional contact email if not anonymous
      if (!_isAnonymous) {
        final enteredEmail = _contactEmailController.text.trim();
        if (enteredEmail.isNotEmpty) {
          request.fields['contact_email'] = enteredEmail;
        }
      }

      // Add optional coordinates
      if (latitude != null) {
        request.fields['latitude'] = latitude.toString();
      }
      if (longitude != null) {
        request.fields['longitude'] = longitude.toString();
      }

      // Determine clean filename and extension
      String filename = _pickedImage?.name ?? 'sighting.jpg';
      if (!filename.contains('.')) {
        filename = '$filename.jpg';
      }
      final ext = filename.split('.').last.toLowerCase();
      final validExt =
          ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
      if (ext != validExt) {
        filename = '${filename.split('.').first}.$validExt';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'sighting_image',
          _imageBytes!,
          filename: filename,
        ),
      );

      // Send request with timeout
      final http.StreamedResponse streamedResponse = widget.httpClient != null
          ? await widget.httpClient!.send(request).timeout(const Duration(seconds: 30))
          : await request.send().timeout(const Duration(seconds: 30));

      final response = await http.Response.fromStream(streamedResponse);

      Map<String, dynamic>? responseData;
      try {
        responseData = jsonDecode(response.body) as Map<String, dynamic>?;
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      if (response.statusCode == 201 && responseData != null) {
        final String sightingId =
            responseData['sighting_id']?.toString() ?? 'Recorded';

        await _showSuccessDialog(sightingId, citizenSuggestion);
      } else {
        final serverError = responseData?['error']?.toString();
        String errorMessage;
        if (response.statusCode == 422) {
          errorMessage = serverError ??
              'No faces detected in the sighting photo. Please select a clear photograph showing the person\'s face.';
        } else if (response.statusCode == 400) {
          errorMessage = serverError ??
              'The sighting submission contains invalid data. Please verify your photo and input fields.';
        } else {
          errorMessage = serverError ??
              'Server returned error (${response.statusCode}). Please try again later.';
        }
        _showErrorDialog(errorMessage);
      }
    } on SocketException catch (_) {
      if (!mounted) return;
      _showErrorDialog(
        'Unable to connect to UniSafe server at ${widget.apiBaseUrl}. Please ensure the Flask backend is running and your device is connected.',
      );
    } on http.ClientException catch (e) {
      if (!mounted) return;
      _showErrorDialog('Network connection error: ${e.message}');
    } on TimeoutException catch (_) {
      if (!mounted) return;
      _showErrorDialog(
        'Request timed out. The server took too long to process facial recognition. Please check your connection and retry.',
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('An unexpected error occurred during submission: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showSuccessDialog(
    String sightingId,
    String? citizenSuggestion,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UniSafeTheme.radiusLg),
        ),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: UniSafeTheme.tealLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: UniSafeTheme.teal,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Sighting Logged',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: UniSafeTheme.textDark,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: UniSafeTheme.midnightLight,
                borderRadius: BorderRadius.circular(UniSafeTheme.radiusSm),
                border: Border.all(color: UniSafeTheme.border),
              ),
              child: Text(
                'Tracking ID: $sightingId',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: UniSafeTheme.midnightBlue,
                ),
              ),
            ),
            if (citizenSuggestion != null && widget.linkedPerson != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(UniSafeTheme.radiusSm),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: Color(0xFF475569)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Linked Suggestion: ${widget.linkedPerson!.fullName} (${widget.linkedPerson!.caseCode})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Thank you for assisting law enforcement! Your sighting report and photograph have been securely transmitted to the police authority queue.',
              style: TextStyle(
                fontSize: 13.5,
                color: UniSafeTheme.textMain,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: UniSafeTheme.tealLight,
                borderRadius: BorderRadius.circular(UniSafeTheme.radiusSm),
                border: Border.all(color: UniSafeTheme.tealBorder),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_outlined, size: 16, color: UniSafeTheme.teal),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Successfully submitted to UniSafe police authority backend for review and AI facial match confirmation.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF065F46),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close sighting form
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: UniSafeTheme.midnightBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
              ),
            ),
            child: const Text('Return to Registry'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UniSafeTheme.radiusLg),
        ),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: UniSafeTheme.crimsonLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: UniSafeTheme.crimson,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Submission Failed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: UniSafeTheme.textDark,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                fontSize: 13.5,
                color: UniSafeTheme.textMain,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your form entries and selected photo remain saved so you can retry.',
              style: TextStyle(
                fontSize: 12,
                color: UniSafeTheme.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: UniSafeTheme.midnightBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, d MMM yyyy, h:mm a');

    return Scaffold(
      backgroundColor: UniSafeTheme.background,
      appBar: AppBar(
        title: const Text('Report a Sighting'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linked Case Banner (if pre-selected)
              if (widget.linkedPerson != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: UniSafeTheme.midnightLight,
                    borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: UniSafeTheme.midnightBlue,
                          borderRadius: BorderRadius.circular(UniSafeTheme.radiusSm),
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Linked Case: ${widget.linkedPerson!.caseCode}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: UniSafeTheme.midnightBlue,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              widget.linkedPerson!.fullName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: UniSafeTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Section 1: Photograph Capture
              const Text(
                '1. Sighting Photograph *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: UniSafeTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Capture or select a clear image. Facial recognition vectors will be extracted to match against active cases.',
                style: TextStyle(
                  fontSize: 12,
                  color: UniSafeTheme.textMuted,
                ),
              ),
              const SizedBox(height: 10),

              // Image Preview / Upload Box
              if (_imageBytes != null)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
                    border: Border.all(color: UniSafeTheme.tealBorder, width: 1.5),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(UniSafeTheme.radiusSm),
                        child: Image.memory(
                          _imageBytes!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.check_circle, size: 16, color: UniSafeTheme.teal),
                              SizedBox(width: 4),
                              Text(
                                'Photo attached',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: UniSafeTheme.teal,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt, size: 16),
                                label: const Text('Retake'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _pickedImage = null;
                                    _imageBytes = null;
                                  });
                                },
                                icon: const Icon(Icons.delete_outline, size: 16, color: UniSafeTheme.crimson),
                                label: const Text('Remove', style: TextStyle(color: UniSafeTheme.crimson)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
                    border: Border.all(
                      color: _imageError != null ? UniSafeTheme.crimson : UniSafeTheme.border,
                      width: _imageError != null ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: UniSafeTheme.surfaceSubtle,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          size: 32,
                          color: UniSafeTheme.midnightBlue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Attach a Photo of the Sighted Person',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: UniSafeTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera, size: 16),
                            label: const Text('Take Photo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: UniSafeTheme.midnightBlue,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library, size: 16),
                            label: const Text('Gallery'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: UniSafeTheme.midnightBlue,
                              side: const BorderSide(color: UniSafeTheme.border),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              if (_imageError != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    _imageError!,
                    style: const TextStyle(
                      color: UniSafeTheme.crimson,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Section 2: Location
              const Text(
                '2. Sighting Location *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: UniSafeTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: 'e.g. Near Bandra Station West bus depot...',
                  prefixIcon: const Icon(Icons.location_on_outlined, color: UniSafeTheme.textMuted, size: 20),
                  suffixIcon: TextButton(
                    onPressed: _fillMockGpsLocation,
                    child: const Text('Use GPS', style: TextStyle(fontSize: 12, color: UniSafeTheme.teal)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Location is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              // Section 3: Date & Approximate Time
              const Text(
                '3. Approximate Date & Time *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: UniSafeTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _selectDateTime,
                borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
                    border: Border.all(color: UniSafeTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 20, color: UniSafeTheme.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          dateFormat.format(_selectedDateTime),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: UniSafeTheme.textDark,
                          ),
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined, size: 16, color: UniSafeTheme.midnightBlue),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Section 4: Observations & Description
              const Text(
                '4. Context & Observations (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: UniSafeTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Describe physical condition, clothing, companions, direction of travel...',
                ),
              ),

              const SizedBox(height: 18),

              // Section 5: Citizen Contact (Optional)
              const Text(
                '5. Citizen Follow-up (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: UniSafeTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _contactEmailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isAnonymous,
                decoration: InputDecoration(
                  hintText: _isAnonymous ? 'Anonymous mode enabled' : 'Contact email (for officer follow-up)',
                  prefixIcon: const Icon(Icons.email_outlined, color: UniSafeTheme.textMuted, size: 20),
                ),
                validator: (val) {
                  if (_isAnonymous) return null;
                  final trimmed = val?.trim() ?? '';
                  if (trimmed.isEmpty) return null;
                  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!emailRegex.hasMatch(trimmed)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Checkbox(
                    value: _isAnonymous,
                    activeColor: UniSafeTheme.midnightBlue,
                    onChanged: (val) {
                      setState(() {
                        _isAnonymous = val ?? false;
                        if (_isAnonymous) {
                          _contactEmailController.clear();
                        }
                      });
                    },
                  ),
                  const Text(
                    'Submit anonymously (hide my contact info)',
                    style: TextStyle(fontSize: 12.5, color: UniSafeTheme.textMain),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Legal / Safeguard Notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: UniSafeTheme.tealLight,
                  borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
                  border: Border.all(color: UniSafeTheme.tealBorder),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: UniSafeTheme.teal, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Official Protocol: Sighting reports are evaluated by law enforcement AI and verified by field officers. Match scores alone never change case status.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF065F46),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UniSafeTheme.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(UniSafeTheme.radiusMd),
                    ),
                  ),
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('Encoding Biometrics & Sending...'),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Submit Sighting Report',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
