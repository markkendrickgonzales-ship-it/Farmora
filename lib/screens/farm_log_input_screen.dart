import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/screen_header.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../services/farm_service.dart';
import '../services/supabase_client.dart';

class FarmLogInputScreen extends StatefulWidget {
  final ValueChanged<String> go;

  const FarmLogInputScreen({super.key, required this.go});

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

  final List<String> _actionTypes = const ['Feeding', 'Watering'];
  final List<String> _units = const ['kg', 'L'];

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

  Future<void> _submitLog() async {
    if (_amount.isEmpty || _farmId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    // Check if farm_id is a valid UUID (feeding_logs requires UUID)
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    );
    if (!uuidRegex.hasMatch(_farmId!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid farm ID. Please try again.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final amount = double.tryParse(_amount);
      if (amount == null) {
        throw Exception('Invalid amount');
      }

      await supabase.from('feeding_logs').insert({
        'farm_id': _farmId,
        'action_type': _actionType,
        'amount': amount,
        'unit': _unit,
        'trigger_source': 'manual',
        'notes': _notes.isNotEmpty ? _notes : null,
      });

      if (mounted) {
        setState(() {
          _loading = false;
          _submitted = true;
        });
      }
    } catch (e) {
      print('ERROR [FarmLogInput]: Failed to submit log: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit log: $e')),
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
                    decoration: const BoxDecoration(
                      color: FarmoraColors.goodSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 26, color: FarmoraColors.good),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Log submitted',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: FarmoraColors.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_actionType log for $_farmName has been recorded.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, color: FarmoraColors.inkSoft),
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
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FarmoraColors.ink),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Action Type', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: FarmoraColors.inkSoft)),
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
                    style: const TextStyle(fontSize: 13.5, color: FarmoraColors.ink),
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
              const Text('Amount', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: FarmoraColors.inkSoft)),
              const SizedBox(height: 6),
              CustomTextField(
                placeholder: 'Enter amount',
                value: _amount,
                keyboardType: TextInputType.number,
                onChanged: (val) => setState(() => _amount = val),
              ),
              const SizedBox(height: 14),
              const Text('Unit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: FarmoraColors.inkSoft)),
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
                    style: const TextStyle(fontSize: 13.5, color: FarmoraColors.ink),
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
              const Text('Notes (optional)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: FarmoraColors.inkSoft)),
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
                  style: const TextStyle(fontSize: 13.5, color: FarmoraColors.ink),
                  decoration: const InputDecoration(
                    hintText: 'Add any additional notes...',
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
                child: Text(
                  'Timestamp will be recorded automatically when you submit.',
                  style: const TextStyle(fontSize: 11, color: FarmoraColors.inkSoft),
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
            text: _loading ? 'Submitting...' : 'Submit Log',
            disabled: _loading || _amount.isEmpty,
            onClick: _loading ? () {} : _submitLog,
          ),
        ),
      ],
    );
  }
}
