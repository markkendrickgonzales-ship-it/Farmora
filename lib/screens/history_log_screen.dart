import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/banner_widget.dart';
import '../widgets/screen_header.dart';
import '../services/farm_service.dart';

class HistoryLogScreen extends StatefulWidget {
  final ValueChanged<String> go;

  const HistoryLogScreen({super.key, required this.go});

  @override
  State<HistoryLogScreen> createState() => _HistoryLogScreenState();
}

class _HistoryLogScreenState extends State<HistoryLogScreen> {
  // ── Live data ─────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;
  List<_LogEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final farms = await FarmService.fetchFarms();
      if (!mounted) return;
      if (farms.isEmpty) {
        setState(() { _loading = false; _error = 'No farms found.'; });
        return;
      }
      final farmId = farms.first['farm_id'] as String;

      final results = await Future.wait([
        FarmService.fetchTelemetryHistory(farmId, limit: 10),
        FarmService.fetchRecentAlerts(farmId, limit: 10),
      ]);

      if (!mounted) return;
      final telRows = results[0];
      final alertRows = results[1];

      final entries = <_LogEntry>[];

      for (final row in telRows) {
        final ts = DateTime.tryParse(row['recorded_at'] as String? ?? '');
        final temp = (row['temperature_c'] as num?)?.toStringAsFixed(1) ?? '--';
        final hum  = (row['humidity_percent'] as num?)?.toStringAsFixed(1) ?? '--';
        final status = (row['status'] as String? ?? 'ok').toLowerCase();
        entries.add(_LogEntry(
          time: ts,
          title: 'Temp $temp°C · Humidity $hum%',
          value: status == 'ok' ? 'Normal' : status.toUpperCase(),
          level: status == 'ok' ? 'good' : (status == 'warning' ? 'warn' : 'crit'),
        ));
      }

      for (final row in alertRows) {
        final ts = DateTime.tryParse(row['triggered_at'] as String? ?? '');
        final sev  = (row['severity'] as String? ?? 'warning');
        final type = (row['alert_type'] as String? ?? 'Alert');
        entries.add(_LogEntry(
          time: ts,
          title: type,
          value: sev.toUpperCase(),
          level: sev.toLowerCase() == 'critical' ? 'crit' : (sev.toLowerCase() == 'warning' ? 'warn' : 'info'),
        ));
      }

      // sort newest first
      entries.sort((a, b) {
        if (a.time == null && b.time == null) return 0;
        if (a.time == null) return 1;
        if (b.time == null) return -1;
        return b.time!.compareTo(a.time!);
      });

      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Load failed: $e'; _loading = false; });
    }
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'good': return FarmoraColors.good;
      case 'warn': return FarmoraColors.warn;
      case 'crit': return FarmoraColors.crit;
      default:     return FarmoraColors.info;
    }
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ap = local.hour < 12 ? 'AM' : 'PM';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[local.month - 1]} ${local.day}, $h:$m $ap';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScreenHeader(
          title: 'Last 7 days',
          onBack: () => widget.go('monitoringHub'),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, style: const TextStyle(color: FarmoraColors.crit)),
                    ))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_entries.isEmpty)
                          const BannerWidget(level: 'info', message: 'No history records found for this farm.'),
                        ..._entries.map((e) {
                          final c = _levelColor(e.level);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 4, right: 12),
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _fmtTime(e.time),
                                        style: const TextStyle(fontSize: 11, color: FarmoraColors.inkFaint),
                                      ),
                                      const SizedBox(height: 4),
                                      FarmoraCard(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                e.title,
                                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: FarmoraColors.ink),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              e.value,
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const BannerWidget(
                          level: 'info',
                          message: 'Showing the most recent telemetry readings and alerts from the database.',
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            onPressed: _loadData,
                            child: const Text(
                              'Refresh logs',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: FarmoraColors.brand,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

class _LogEntry {
  final DateTime? time;
  final String title;
  final String value;
  final String level;

  _LogEntry({this.time, required this.title, required this.value, required this.level});
}
