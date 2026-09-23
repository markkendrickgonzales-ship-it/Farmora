import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/screen_header.dart';
import '../widgets/primary_button.dart';
import '../services/farm_service.dart';
import '../services/supabase_client.dart';

class ReportUploadScreen extends StatefulWidget {
  final ValueChanged<String> go;
  final VoidCallback? onSubmitted;

  const ReportUploadScreen({super.key, required this.go, this.onSubmitted});

  @override
  State<ReportUploadScreen> createState() => _ReportUploadScreenState();
}

class _ReportUploadScreenState extends State<ReportUploadScreen> {
  String _title = '';
  String _category = 'General inspection';
  String _notes = '';
  bool _submitted = false;
  bool _uploading = false;
  String? _farmId;
  String _farmName = 'Farm';
  String? _imagePath;

  final List<String> _categories = const [
    'General inspection',
    'Crop health',
    'Equipment fault',
    'Resource usage',
    'Safety incident',
  ];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadFarmInfo();
  }

  Future<void> _loadFarmInfo() async {
    try {
      // Use telemetry farms to get UUID farm_ids for reports
      final telemetryFarms = await FarmService.fetchTelemetryFarms();
      if (telemetryFarms.isNotEmpty) {
        setState(() {
          _farmId = telemetryFarms.first['farm_id'] as String?;
          _farmName = 'Telemetry Farm'; // No farm name in telemetry data
        });
      } else {
        print('ERROR [ReportUpload]: No telemetry farms found');
      }
    } catch (e) {
      print('ERROR [ReportUpload]: Failed to load farm info: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _imagePath = image.path;
        });
      }
    } catch (e) {
      print('ERROR [ReportUpload]: Failed to pick image from camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture image')),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _imagePath = image.path;
        });
      }
    } catch (e) {
      print('ERROR [ReportUpload]: Failed to pick image from gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to select image')),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _imagePath = null;
    });
  }

  void _selectFile() {
    // File upload functionality temporarily disabled due to schema uncertainty
    // TODO: Re-enable once database schema for file storage is confirmed
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File upload temporarily disabled')),
    );
  }

  Future<void> _uploadReport() async {
    if (_title.isEmpty || _farmId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      // Include image path in notes for now (will be properly stored when file storage is implemented)
      String enhancedNotes = _notes;
      if (_imagePath != null) {
        enhancedNotes = _notes.isEmpty
            ? 'Image attached: ${_imagePath!.split('/').last}'
            : '$_notes\n\nImage attached: ${_imagePath!.split('/').last}';
      }

      // Use the service method for database insert
      await FarmService.insertReport(
        farmId: _farmId!,
        title: _title,
        category: _category,
        notes: enhancedNotes,
      );

      if (mounted) {
        setState(() {
          _uploading = false;
          _submitted = true;
        });
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Trigger refresh callback
        widget.onSubmitted?.call();
      }
    } catch (e) {
      print('ERROR [ReportUpload]: Failed to upload report: $e');
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetForm() {
    setState(() {
      _title = '';
      _category = 'General inspection';
      _notes = '';
      _imagePath = null;
      _submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Column(
        children: [
          ScreenHeader(
            title: 'Upload Report',
            onBack: () {
              _resetForm();
              widget.go('home');
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: FarmoraColors.goodSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 26, color: FarmoraColors.good),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Report submitted',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: FarmoraColors.ink),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your report has been successfully submitted and attached to today\'s records.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: FarmoraColors.inkSoft),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    text: 'Submit another report',
                    onClick: _resetForm,
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    text: 'View analytics',
                    onClick: () => widget.go('reportCreate'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        ScreenHeader(
          title: 'Upload Report',
          onBack: () => widget.go('home'),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Report title', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: FarmoraColors.inkSoft)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: FarmoraColors.surfaceSunken,
                  border: Border.all(color: FarmoraColors.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: TextField(
                  onChanged: (val) => setState(() => _title = val),
                  style: const TextStyle(fontSize: 13.5, color: FarmoraColors.ink),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Sector B Morning Audit',
                    hintStyle: TextStyle(color: FarmoraColors.inkFaint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Category', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: FarmoraColors.inkSoft)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: FarmoraColors.surfaceSunken,
                  border: Border.all(color: FarmoraColors.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _category,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 13.5, color: FarmoraColors.ink),
                    onChanged: (val) {
                      if (val != null) setState(() => _category = val);
                    },
                    items: _categories.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Photo (optional)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: FarmoraColors.inkSoft)),
              const SizedBox(height: 6),
              if (_imagePath != null)
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: FarmoraColors.surfaceSunken,
                    border: Border.all(color: FarmoraColors.line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            color: FarmoraColors.inkSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.image, size: 32, color: Colors.white),
                              const SizedBox(height: 8),
                              const Text(
                                'Image selected',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              Text(
                                _imagePath!.split('/').last,
                                style: const TextStyle(color: Colors.white70, fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: _removeImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FarmoraCard(
                        padding: const EdgeInsets.all(12),
                        onTap: _pickImageFromCamera,
                        child: const Column(
                          children: [
                            Icon(Icons.camera_alt, size: 24, color: FarmoraColors.brand),
                            SizedBox(height: 4),
                            Text('Camera', style: TextStyle(fontSize: 12, color: FarmoraColors.ink)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FarmoraCard(
                        padding: const EdgeInsets.all(12),
                        onTap: _pickImageFromGallery,
                        child: const Column(
                          children: [
                            Icon(Icons.photo_library, size: 24, color: FarmoraColors.brand),
                            SizedBox(height: 4),
                            Text('Gallery', style: TextStyle(fontSize: 12, color: FarmoraColors.ink)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              const Text('Observations / notes', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: FarmoraColors.inkSoft)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: FarmoraColors.surfaceSunken,
                  border: Border.all(color: FarmoraColors.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: TextField(
                  maxLines: 5,
                  onChanged: (val) => setState(() => _notes = val),
                  style: const TextStyle(fontSize: 13.5, color: FarmoraColors.ink),
                  decoration: const InputDecoration(
                    hintText: 'Describe findings or actions taken in the field...',
                    hintStyle: TextStyle(color: FarmoraColors.inkFaint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FarmoraCard(
                padding: const EdgeInsets.all(12),
                border: Border.all(color: Colors.transparent),
                child: const Text(
                  'Automatic metadata\nTimestamp and farm ID will be attached automatically upon upload.',
                  style: TextStyle(fontSize: 11, color: FarmoraColors.inkSoft, height: 1.6),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: FarmoraColors.line)),
          ),
          child: PrimaryButton(
            text: _uploading ? 'Submitting...' : 'Submit Report',
            disabled: _uploading || _title.isEmpty,
            onClick: _uploading ? () {} : _uploadReport,
          ),
        ),
      ],
    );
  }
}
