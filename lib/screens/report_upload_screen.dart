import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/screen_header.dart';
import '../widgets/primary_button.dart';

class ReportUploadScreen extends StatefulWidget {
  final ValueChanged<String> go;

  const ReportUploadScreen({super.key, required this.go});

  @override
  State<ReportUploadScreen> createState() => _ReportUploadScreenState();
}

class _ReportUploadScreenState extends State<ReportUploadScreen> {
  String _title = '';
  String _category = 'General inspection';
  String _notes = '';
  bool _submitted = false;
  bool _uploading = false;
  String? _selectedFileName;

  final List<String> _categories = const [
    'General inspection',
    'Crop health',
    'Equipment fault',
    'Resource usage',
    'Safety incident',
  ];

  void _selectFile() {
    // In a real implementation, this would open a file picker
    // For now, we'll simulate file selection
    setState(() {
      _selectedFileName = 'report_document.pdf';
    });
  }

  Future<void> _uploadReport() async {
    if (_title.isEmpty || _selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _uploading = true);

    // Simulate upload delay
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _uploading = false;
        _submitted = true;
      });
    }
  }

  void _resetForm() {
    setState(() {
      _title = '';
      _category = 'General inspection';
      _notes = '';
      _selectedFileName = null;
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
                    'Report uploaded',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: FarmoraColors.ink),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your report has been successfully uploaded and attached to today\'s records.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: FarmoraColors.inkSoft),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    text: 'Upload another report',
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
              const Text('File', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: FarmoraColors.inkSoft)),
              const SizedBox(height: 6),
              FarmoraCard(
                padding: const EdgeInsets.all(14),
                onTap: _selectFile,
                child: Row(
                  children: [
                    Icon(
                      _selectedFileName != null ? Icons.check_circle : Icons.cloud_upload_outlined,
                      color: _selectedFileName != null ? FarmoraColors.good : FarmoraColors.brand,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedFileName ?? 'Tap to select file',
                        style: TextStyle(
                          fontSize: 13,
                          color: _selectedFileName != null ? FarmoraColors.ink : FarmoraColors.inkSoft,
                        ),
                      ),
                    ),
                    if (_selectedFileName != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _selectedFileName = null),
                      ),
                  ],
                ),
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
            text: _uploading ? 'Uploading...' : 'Upload Report',
            disabled: _uploading || _title.isEmpty || _selectedFileName == null,
            onClick: _uploading ? () {} : _uploadReport,
          ),
        ),
      ],
    );
  }
}
