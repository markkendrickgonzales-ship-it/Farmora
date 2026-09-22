import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/screen_header.dart';
import '../widgets/status_badge.dart';
import '../widgets/primary_button.dart';
import '../services/farm_service.dart';

class FarmLogsScreen extends StatefulWidget {
  final ValueChanged<String> go;

  const FarmLogsScreen({super.key, required this.go});

  @override
  State<FarmLogsScreen> createState() => _FarmLogsScreenState();
}

class _FarmLogsScreenState extends State<FarmLogsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _farms = [];
  List<Map<String, dynamic>> _logs = [];
  String? _selectedFarmId;
  String _selectedFarmName = 'All Farms';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final farms = await FarmService.fetchFarms();
      if (!mounted) return;
      
      setState(() {
        _farms = farms;
        _loading = false;
      });

      if (farms.isNotEmpty) {
        _selectedFarmId = farms.first['farm_id']?.toString() ?? '';
        _selectedFarmName = farms.first['farm_name'] as String? ?? 'Farm';
        await _loadLogs(_selectedFarmId!);
      } else {
        setState(() {
          _logs = [];
        });
      }
    } catch (e) {
      print('ERROR [FarmLogs]: Failed to load farms: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load data: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadLogs(String farmId) async {
    try {
      final logs = await FarmService.fetchFeedingLogs(farmId, limit: 100);
      if (!mounted) return;
      setState(() {
        _logs = logs;
      });
    } catch (e) {
      print('ERROR [FarmLogs]: Failed to load logs: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load logs: $e';
      });
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  String _getActionIcon(String actionType) {
    final type = (actionType as String? ?? '').toLowerCase();
    if (type.contains('feed')) return '🌾';
    if (type.contains('water')) return '💧';
    return '📋';
  }

  Color _getActionColor(String actionType) {
    final type = (actionType as String? ?? '').toLowerCase();
    if (type.contains('feed')) return FarmoraColors.brand;
    if (type.contains('water')) return Colors.blue;
    return FarmoraColors.ink;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScreenHeader(
          title: 'Farm Logs',
          right: IconButton(
            icon: const Icon(Icons.camera_alt, color: FarmoraColors.brand),
            onPressed: () => widget.go('camera'),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, style: const TextStyle(color: FarmoraColors.crit)),
                      ),
                    )
                  : Column(
                      children: [
                        // Farm Filter Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            color: FarmoraColors.surface,
                            border: Border(bottom: BorderSide(color: FarmoraColors.line)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.filter_list, size: 18, color: FarmoraColors.inkSoft),
                              const SizedBox(width: 8),
                              const Text(
                                'Filter by farm:',
                                style: TextStyle(fontSize: 13, color: FarmoraColors.inkSoft),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: FarmoraColors.surfaceSunken,
                                    border: Border.all(color: FarmoraColors.line),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedFarmId,
                                      isExpanded: true,
                                      style: const TextStyle(fontSize: 13, color: FarmoraColors.ink),
                                      onChanged: (val) async {
                                        if (val != null) {
                                          final farm = _farms.firstWhere((f) => f['farm_id'] == val);
                                          setState(() {
                                            _selectedFarmId = val;
                                            _selectedFarmName = farm['farm_name'] as String? ?? 'Farm';
                                          });
                                          await _loadLogs(val);
                                        }
                                      },
                                      items: _farms.map((farm) {
                                        return DropdownMenuItem(
                                          value: farm['farm_id'] as String,
                                          child: Text(farm['farm_name'] as String? ?? 'Farm'),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Logs List
                        Expanded(
                          child: _logs.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inbox_outlined, size: 48, color: FarmoraColors.inkFaint),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No logs found',
                                        style: TextStyle(fontSize: 14, color: FarmoraColors.inkSoft),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$_selectedFarmName has no feeding/watering records yet',
                                        style: const TextStyle(fontSize: 12, color: FarmoraColors.inkFaint),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _logs.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final log = _logs[index];
                                    final actionType = log['action_type'] as String? ?? 'Unknown';
                                    final amount = (log['amount'] as num?)?.toDouble() ?? 0;
                                    final unit = log['unit'] as String? ?? '';
                                    final actionTime = log['action_time'] as String?;
                                    
                                    return FarmoraCard(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: _getActionColor(actionType).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Center(
                                              child: Text(
                                                _getActionIcon(actionType),
                                                style: const TextStyle(fontSize: 20),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  actionType,
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: FarmoraColors.ink,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${amount.toStringAsFixed(1)} $unit',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: FarmoraColors.inkSoft,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                _formatDate(actionTime),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: FarmoraColors.inkSoft,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatTime(actionTime),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: FarmoraColors.inkFaint,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}
