import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/screen_header.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../services/farm_service.dart';

class FarmLogInputScreen extends StatefulWidget {
  final ValueChanged<String> go;
  final VoidCallback? onSubmitted;

  const FarmLogInputScreen({super.key, required this.go, this.onSubmitted});

  @override
  State<FarmLogInputScreen> createState() => _FarmLogInputScreenState();
}

class _FarmLogInputScreenState extends State<FarmLogInputScreen> {
  String _actionType = 'Feeding';
  String _amount = '';
  String _unit = 'kg';
  String _notes = '';
  bool _loading = false;
  bool _submitted = false;
  String? _farmId;
  String _farmName = 'Farm';
  String? _imagePath;

  final List<String> _actionTypes = const ['Feeding', 'Watering'];
  final List<String> _units = const ['kg', 'L'];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadFarmInfo();
  }

  Future<void> _loadFarmInfo() async {
    try {
      // Use telemetry farms to get UUID farm_ids for feeding_logs
      final telemetryFarms = await FarmService.fetchTelemetryFarms();
      if (telemetryFarms.isNotEmpty) {
        setState(() {
          _farmId = telemetryFarms.first['farm_id'] as String?;
          _farmName = 'Telemetry Farm'; // No farm name in telemetry data
        });
      } else {
        print('ERROR [FarmLogInput]: No telemetry farms found');
      }
    } catch (e) {
      print('ERROR [FarmLogInput]: Failed to load farm info: $e');
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
      print('ERROR [FarmLogInput]: Failed to pick image from camera: $e');
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
      print('ERROR [FarmLogInput]: Failed to pick image from gallery: $e');
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

  Future<void> _submitLog() async {
    if (_amount.isEmpty || _farmId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final amount = double.tryParse(_amount);
      if (amount == null || amount <= 0) {
        throw Exception('Please enter a valid amount greater than 0');
      }

      // Use the service method for better validation and error handling
      await FarmService.insertFeedingLog(
        farmId: _farmId!,
        actionType: _actionType,
        amount: amount,
        unit: _unit,
        triggerSource: 'manual',
        notes: _notes.isNotEmpty ? _notes : null,
        imagePath: _imagePath,
      );

      if (mounted) {
        setState(() {
          _loading = false;
          _submitted = true;
        });
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Log submitted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Trigger refresh callback
        widget.onSubmitted?.call();
      }
    } catch (e) {
      print('ERROR [FarmLogInput]: Failed to submit log: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to submit log: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetForm() {
    setState(() {
      _actionType = 'Feeding';
      _amount = '';
      _unit = 'kg';
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
            title: 'Farm Log',
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
                    decoration: BoxDecoration(
                      color: FarmoraColors.goodSoft,
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(Icons.check, size: 26, color: FarmoraColors.good),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Log submitted',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: FarmoraColors.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_actionType log for $_farmName has been recorded.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 12.5, color: FarmoraColors.inkSoft),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    text: 'Add another log',
                    onClick: _resetForm,
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    text: 'View all logs',
                    onClick: () => widget.go('farmLogs'),
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
          title: 'Farm Log',
          onBack: () => widget.go('home'),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FarmoraCard(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Farm: $_farmName',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: FarmoraColors.ink),
                ),
              ),
              const SizedBox(height: 14),
              Text('Action Type',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: FarmoraColors.inkSoft)),
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
                    value: _actionType,
                    isExpanded: true,
                    style: TextStyle(fontSize: 13.5, color: FarmoraColors.ink),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _actionType = val;
                          _unit = val == 'Feeding' ? 'kg' : 'L';
                        });
                      }
                    },
                    items: _actionTypes.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Amount',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: FarmoraColors.inkSoft)),
              const SizedBox(height: 6),
              CustomTextField(
                placeholder: 'Enter amount',
                value: _amount,
                keyboardType: TextInputType.number,
                onChanged: (val) => setState(() => _amount = val),
              ),
              const SizedBox(height: 14),
              Text('Unit',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: FarmoraColors.inkSoft)),
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
                    value: _unit,
                    isExpanded: true,
                    style: TextStyle(fontSize: 13.5, color: FarmoraColors.ink),
                    onChanged: (val) {
                      if (val != null) setState(() => _unit = val);
                    },
                    items: _units.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Notes (optional)',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: FarmoraColors.inkSoft)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: FarmoraColors.surfaceSunken,
                  border: Border.all(color: FarmoraColors.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: TextField(
                  maxLines: 3,
                  onChanged: (val) => setState(() => _notes = val),
                  style: TextStyle(fontSize: 13.5, color: FarmoraColors.ink),
                  decoration: InputDecoration(
                    hintText: 'Add any additional notes...',
                    hintStyle: TextStyle(color: FarmoraColors.inkFaint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Photo (optional)',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: FarmoraColors.inkSoft)),
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
                              const Icon(Icons.image,
                                  size: 32, color: Colors.white),
                              const SizedBox(height: 8),
                              const Text(
                                'Image selected',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                              Text(
                                _imagePath!.split('/').last,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 10),
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
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 20),
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
                        child: Column(
                          children: [
                            Icon(Icons.camera_alt,
                                size: 24, color: FarmoraColors.brand),
                            SizedBox(height: 4),
                            Text('Camera',
                                style: TextStyle(
                                    fontSize: 12, color: FarmoraColors.ink)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FarmoraCard(
                        padding: const EdgeInsets.all(12),
                        onTap: _pickImageFromGallery,
                        child: Column(
                          children: [
                            Icon(Icons.photo_library,
                                size: 24, color: FarmoraColors.brand),
                            SizedBox(height: 4),
                            Text('Gallery',
                                style: TextStyle(
                                    fontSize: 12, color: FarmoraColors.ink)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              FarmoraCard(
                padding: const EdgeInsets.all(12),
                border: Border.all(color: Colors.transparent),
                child: Text(
                  'Timestamp will be recorded automatically when you submit.',
                  style: TextStyle(fontSize: 11, color: FarmoraColors.inkSoft),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: FarmoraColors.line)),
          ),
          child: PrimaryButton(
            text: _loading ? 'Submitting...' : 'Submit Log',
            disabled: _loading || _amount.isEmpty,
            onClick: _loading ? () {} : _submitLog,
          ),
        ),
      ],
    );
  }
}
