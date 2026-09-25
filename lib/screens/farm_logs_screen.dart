import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/screen_header.dart';
import '../services/farm_service.dart';

class FarmLogsScreen extends StatefulWidget {
  final ValueChanged<String> go;
  final bool needsRefresh;
  final VoidCallback? onRefreshComplete;

  const FarmLogsScreen({
    super.key,
    required this.go,
    this.needsRefresh = false,
    this.onRefreshComplete,
  });

  @override
  State<FarmLogsScreen> createState() => _FarmLogsScreenState();
}

class _FarmLogsScreenState extends State<FarmLogsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _farms = [];
  List<Map<String, dynamic>> _logs = [];
  final Map<String, List<Map<String, dynamic>>> _groupedLogs = {};
  Map<String, List<Map<String, dynamic>>> _monthGroups = {};
  final Set<String> _expandedMonths = {};
  String? _selectedFarmId;
  String _selectedFarmName = 'All Farms';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(FarmLogsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.needsRefresh && !oldWidget.needsRefresh) {
      _loadData();
      widget.onRefreshComplete?.call();
    }
  }

  void refreshData() {
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Use telemetry farms to get UUID farm_ids for feeding_logs
      final farms = await FarmService.fetchTelemetryFarms();
      if (!mounted) return;

      setState(() {
        _farms = farms;
        _loading = false;
      });

      if (farms.isNotEmpty) {
        _selectedFarmId = farms.first['farm_id'] as String?;
        _selectedFarmName = 'Telemetry Farm'; // No farm name in telemetry data
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
        _monthGroups = _groupLogsByMonth(logs);
        // Auto-expand the most recent month
        if (_monthGroups.isNotEmpty) {
          _expandedMonths.add(_monthGroups.keys.first);
        }
      });
    } catch (e) {
      print('ERROR [FarmLogs]: Failed to load logs: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load logs: $e';
      });
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupLogsByMonth(
      List<Map<String, dynamic>> logs) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final log in logs) {
      final actionTime = log['action_time'] as String?;
      if (actionTime == null) continue;

      final dateTime = DateTime.tryParse(actionTime);
      if (dateTime == null) continue;

      // Create a month key (YYYY-MM format for sorting)
      final monthKey =
          '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}';

      if (!grouped.containsKey(monthKey)) {
        grouped[monthKey] = [];
      }
      grouped[monthKey]!.add(log);
    }

    // Sort months in descending order (newest first)
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final sortedGrouped = <String, List<Map<String, dynamic>>>{};

    for (final key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }

    return sortedGrouped;
  }

  String _formatMonthHeader(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;

    final year = int.tryParse(parts[0]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 0;

    if (year == 0 || month == 0) return monthKey;

    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[month - 1]} $year';
  }

  void _toggleMonthExpansion(String monthKey) {
    setState(() {
      if (_expandedMonths.contains(monthKey)) {
        _expandedMonths.remove(monthKey);
      } else {
        _expandedMonths.add(monthKey);
      }
    });
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
        const ScreenHeader(
          title: 'Farm Logs',
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!,
                            style: TextStyle(color: FarmoraColors.crit)),
                      ),
                    )
                  : Column(
                      children: [
                        // Farm Filter Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: FarmoraColors.surface,
                            border: Border(
                                bottom: BorderSide(color: FarmoraColors.line)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.filter_list,
                                  size: 18, color: FarmoraColors.inkSoft),
                              const SizedBox(width: 8),
                              Text(
                                'Filter by farm:',
                                style: TextStyle(
                                    fontSize: 13, color: FarmoraColors.inkSoft),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: FarmoraColors.surfaceSunken,
                                    border:
                                        Border.all(color: FarmoraColors.line),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedFarmId,
                                      isExpanded: true,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: FarmoraColors.ink),
                                      onChanged: (val) async {
                                        if (val != null) {
                                          final farm = _farms.firstWhere(
                                              (f) => f['farm_id'] == val);
                                          setState(() {
                                            _selectedFarmId = val;
                                            _selectedFarmName =
                                                'Farm ${val.substring(0, 8)}';
                                          });
                                          await _loadLogs(val);
                                        }
                                      },
                                      items: _farms.map((farm) {
                                        final farmId =
                                            farm['farm_id'] as String?;
                                        return DropdownMenuItem(
                                          value: farmId,
                                          child: Text(
                                              'Farm ${farmId?.substring(0, 8) ?? 'Unknown'}'),
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
                                      Icon(Icons.inbox_outlined,
                                          size: 48,
                                          color: FarmoraColors.inkFaint),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No logs found',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: FarmoraColors.inkSoft),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$_selectedFarmName has no feeding/watering records yet',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: FarmoraColors.inkFaint),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _monthGroups.length,
                                  itemBuilder: (context, index) {
                                    final monthKeys =
                                        _monthGroups.keys.toList();
                                    final monthKey = monthKeys[index];
                                    final logsForMonth =
                                        _monthGroups[monthKey]!;
                                    final isExpanded =
                                        _expandedMonths.contains(monthKey);

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Month Folder Header
                                        GestureDetector(
                                          onTap: () =>
                                              _toggleMonthExpansion(monthKey),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12, horizontal: 16),
                                            decoration: BoxDecoration(
                                              color: FarmoraColors.brand
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: FarmoraColors.brand
                                                      .withOpacity(0.2)),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  isExpanded
                                                      ? Icons.folder_open
                                                      : Icons.folder,
                                                  color: FarmoraColors.brand,
                                                  size: 24,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    _formatMonthHeader(
                                                        monthKey),
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          FarmoraColors.brand,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: FarmoraColors.brand
                                                        .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    '${logsForMonth.length} logs',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          FarmoraColors.brand,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  isExpanded
                                                      ? Icons.expand_less
                                                      : Icons.expand_more,
                                                  color: FarmoraColors.brand,
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Expanded logs for this month
                                        if (isExpanded) ...[
                                          const SizedBox(height: 12),
                                          ...logsForMonth.map((log) {
                                            final actionType =
                                                log['action_type'] as String? ??
                                                    'Unknown';
                                            final amount =
                                                (log['amount'] as num?)
                                                        ?.toDouble() ??
                                                    0;
                                            final unit =
                                                log['unit'] as String? ?? '';
                                            final actionTime =
                                                log['action_time'] as String?;
                                            final notes =
                                                log['notes'] as String?;

                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 10),
                                              child: FarmoraCard(
                                                padding:
                                                    const EdgeInsets.all(14),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          width: 40,
                                                          height: 40,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: _getActionColor(
                                                                    actionType)
                                                                .withOpacity(
                                                                    0.1),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              _getActionIcon(
                                                                  actionType),
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          20),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 12),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                actionType,
                                                                style:
                                                                    TextStyle(
                                                                  fontSize:
                                                                      13.5,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color:
                                                                      FarmoraColors
                                                                          .ink,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 2),
                                                              Text(
                                                                '${amount.toStringAsFixed(1)} $unit',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                  color: FarmoraColors
                                                                      .inkSoft,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .end,
                                                          children: [
                                                            Text(
                                                              _formatDate(
                                                                  actionTime),
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color:
                                                                    FarmoraColors
                                                                        .inkSoft,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 2),
                                                            Text(
                                                              _formatTime(
                                                                  actionTime),
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color:
                                                                    FarmoraColors
                                                                        .inkFaint,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                    if (notes != null &&
                                                        notes.isNotEmpty) ...[
                                                      const SizedBox(height: 8),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FarmoraColors
                                                              .surfaceSunken,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                        ),
                                                        child: Text(
                                                          notes,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: FarmoraColors
                                                                .inkSoft,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                        const SizedBox(height: 16),
                                      ],
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
