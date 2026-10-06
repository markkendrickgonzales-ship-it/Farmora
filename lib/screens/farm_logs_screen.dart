import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/screen_header.dart';
import '../services/farm_service.dart';
import '../models/farm.dart';
import '../models/feeding_log.dart';

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
  List<Farm> _farms = [];
  List<FeedingLog> _logs = [];
  Map<String, List<FeedingLog>> _monthGroups = {};
  final Set<String> _expandedMonths = {};
  int? _selectedFarmId;
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
      final farms = await FarmService.fetchFarms();
      if (!mounted) return;

      setState(() {
        _farms = farms;
        _loading = false;
      });

      if (farms.isNotEmpty) {
        _selectedFarmId = farms.first.id;
        _selectedFarmName = farms.first.name;
        await _loadLogs(farms.first.id);
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

  Future<void> _loadLogs(int farmId) async {
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

  Map<String, List<FeedingLog>> _groupLogsByMonth(List<FeedingLog> logs) {
    final grouped = <String, List<FeedingLog>>{};

    for (final log in logs) {
      final dateTime = log.actionTime;

      // Create a month key (YYYY-MM format for sorting)
      final monthKey =
          '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}';

      grouped.putIfAbsent(monthKey, () => []).add(log);
    }

    // Sort months in descending order (newest first)
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final sortedGrouped = <String, List<FeedingLog>>{};

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

  String _formatDate(DateTime dt) => '${dt.month}/${dt.day}/${dt.year}';

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  String _getActionIcon(String actionType) {
    final type = actionType.toLowerCase();
    if (type.contains('feed')) return '🌾';
    if (type.contains('water')) return '💧';
    return '📋';
  }

  Color _getActionColor(String actionType) {
    final type = actionType.toLowerCase();
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
                                    child: DropdownButton<int>(
                                      value: _selectedFarmId,
                                      isExpanded: true,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: FarmoraColors.ink),
                                      onChanged: (val) async {
                                        if (val != null) {
                                          final farm = _farms
                                              .firstWhere((f) => f.id == val);
                                          setState(() {
                                            _selectedFarmId = val;
                                            _selectedFarmName = farm.name;
                                          });
                                          await _loadLogs(val);
                                        }
                                      },
                                      items: _farms.map((farm) {
                                        return DropdownMenuItem(
                                          value: farm.id,
                                          child: Text(farm.name),
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
                                                                    log
                                                                        .actionType)
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
                                                                  log
                                                                      .actionType),
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
                                                                log.actionType,
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
                                                                '${log.amount.toStringAsFixed(1)} ${log.unit}',
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
                                                              _formatDate(log
                                                                  .actionTime),
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
                                                              _formatTime(log
                                                                  .actionTime),
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
                                                    if (log.imageUrl != null)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(top: 8),
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                                Icons
                                                                    .attach_file,
                                                                size: 13,
                                                                color: FarmoraColors
                                                                    .inkSoft,
                                                            ),
                                                            const SizedBox(
                                                                width: 4),
                                                            Expanded(
                                                              child: Text(
                                                                log.imageUrl!,
                                                                style: TextStyle(
                                                                  fontSize:
                                                                      10.5,
                                                                  color: FarmoraColors
                                                                      .inkSoft,
                                                                ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    if (log.notes != null &&
                                                        log.notes!.isNotEmpty) ...
                                                      [
                                                        const SizedBox(
                                                            height: 8),
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
                                                                    .circular(
                                                                        6),
                                                          ),
                                                          child: Text(
                                                            log.notes!,
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
