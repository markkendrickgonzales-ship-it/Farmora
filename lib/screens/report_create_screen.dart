import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/screen_header.dart';
import '../widgets/status_badge.dart';
import '../services/farm_service.dart';

class ReportCreateScreen extends StatefulWidget {
  final ValueChanged<String> go;

  const ReportCreateScreen({super.key, required this.go});

  @override
  State<ReportCreateScreen> createState() => _ReportCreateScreenState();
}

class _ReportCreateScreenState extends State<ReportCreateScreen> {
  bool _loading = true;
  String? _error;
  String? _farmId;
  String _farmName = 'Farm';
  
  // Analytics data
  List<Map<String, dynamic>> _telemetryHistory = [];
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _feedingLogs = [];
  
  // Aggregated stats
  double _totalFeedKg = 0;
  double _totalWaterL = 0;
  double _avgTemp = 0;
  double _avgHumidity = 0;
  int _alertCount = 0;

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
        setState(() {
          _loading = false;
          _error = 'No farms found.';
        });
        return;
      }
      
      _farmId = farms.first['farm_id']?.toString() ?? '';
      _farmName = farms.first['farm_name'] as String? ?? 'Farm';
      
      final results = await Future.wait([
        FarmService.fetchTelemetryHistory(_farmId!, limit: 50),
        FarmService.fetchRecentAlerts(_farmId!, limit: 20),
        FarmService.fetchFeedingLogs(_farmId!, limit: 100),
      ]);
      
      if (!mounted) return;
      
      setState(() {
        _telemetryHistory = results[0] as List<Map<String, dynamic>>;
        _alerts = results[1] as List<Map<String, dynamic>>;
        _feedingLogs = results[2] as List<Map<String, dynamic>>;
        _loading = false;
      });
      
      _calculateStats();
    } catch (e) {
      print('ERROR [Reports]: Failed to load data: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load data: $e';
        _loading = false;
      });
    }
  }

  void _calculateStats() {
    // Calculate feed/water totals
    final usage = FarmService.aggregateTodayUsage(_feedingLogs);
    _totalFeedKg = usage.feedKg;
    _totalWaterL = usage.waterL;
    
    // Calculate average temperature and humidity
    if (_telemetryHistory.isNotEmpty) {
      double tempSum = 0;
      double humSum = 0;
      for (final t in _telemetryHistory) {
        tempSum += (t['temperature_c'] as num?)?.toDouble() ?? 0;
        humSum += (t['humidity_percent'] as num?)?.toDouble() ?? 0;
      }
      _avgTemp = tempSum / _telemetryHistory.length;
      _avgHumidity = humSum / _telemetryHistory.length;
    }
    
    _alertCount = _alerts.length;
    
    setState(() {});
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScreenHeader(
          title: 'Reports & Analytics',
          onBack: () => widget.go('home'),
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
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Summary Cards
                        const Text(
                          'Today\'s Summary',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: FarmoraColors.ink,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Expanded(
                              child: FarmoraCard(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    const Icon(Icons.grain, size: 20, color: FarmoraColors.brand),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${_totalFeedKg.toStringAsFixed(1)} kg',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: FarmoraColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Feed Used',
                                      style: TextStyle(fontSize: 11, color: FarmoraColors.inkSoft),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FarmoraCard(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    const Icon(Icons.water_drop, size: 20, color: Colors.blue),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${_totalWaterL.toStringAsFixed(0)} L',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: FarmoraColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Water Used',
                                      style: TextStyle(fontSize: 11, color: FarmoraColors.inkSoft),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FarmoraCard(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    const Icon(Icons.thermostat, size: 20, color: Colors.orange),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${_avgTemp.toStringAsFixed(1)}°C',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: FarmoraColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Avg Temp',
                                      style: TextStyle(fontSize: 11, color: FarmoraColors.inkSoft),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FarmoraCard(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    const Icon(Icons.warning, size: 20, color: FarmoraColors.crit),
                                    const SizedBox(height: 6),
                                    Text(
                                      '$_alertCount',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: FarmoraColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Active Alerts',
                                      style: TextStyle(fontSize: 11, color: FarmoraColors.inkSoft),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        
                        // Recent Alerts
                        const Text(
                          'Recent Alerts',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: FarmoraColors.ink,
                          ),
                        ),
                        const SizedBox(height: 9),
                        if (_alerts.isEmpty)
                          const FarmoraCard(
                            padding: EdgeInsets.all(14),
                            child: Text(
                              'No recent alerts',
                              style: TextStyle(fontSize: 12, color: FarmoraColors.inkSoft),
                            ),
                          )
                        else
                          ..._alerts.take(5).map((alert) {
                            final severity = alert['severity'] as String? ?? 'warning';
                            final alertType = alert['alert_type'] as String? ?? 'Alert';
                            final createdAt = alert['created_at'] as String?;
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: FarmoraCard(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                children: [
                                  StatusBadge(
                                    level: severity.toLowerCase(),
                                    child: Text(severity.toUpperCase()),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          alertType,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: FarmoraColors.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDate(createdAt),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: FarmoraColors.inkFaint,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            );
                          }),
                        const SizedBox(height: 18),
                        
                        // Environment Trends
                        const Text(
                          'Environment Trends',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: FarmoraColors.ink,
                          ),
                        ),
                        const SizedBox(height: 9),
                        FarmoraCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              _TrendRow(
                                label: 'Average Temperature',
                                value: '${_avgTemp.toStringAsFixed(1)}°C',
                                trend: _avgTemp > 28 ? 'High' : 'Normal',
                                color: _avgTemp > 28 ? FarmoraColors.warn : FarmoraColors.good,
                              ),
                              const Divider(height: 16, color: FarmoraColors.line),
                              _TrendRow(
                                label: 'Average Humidity',
                                value: '${_avgHumidity.toStringAsFixed(1)}%',
                                trend: _avgHumidity > 70 ? 'High' : 'Normal',
                                color: _avgHumidity > 70 ? FarmoraColors.warn : FarmoraColors.good,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        
                        // Data Source Info
                        FarmoraCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: FarmoraColors.inkSoft),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Data from $_farmName • Last 50 telemetry readings, 20 alerts, 100 feeding logs',
                                  style: const TextStyle(fontSize: 11, color: FarmoraColors.inkSoft),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

class _TrendRow extends StatelessWidget {
  final String label;
  final String value;
  final String trend;
  final Color color;

  const _TrendRow({
    required this.label,
    required this.value,
    required this.trend,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: FarmoraColors.inkSoft)),
        Row(
          children: [
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: FarmoraColors.ink)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                trend,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
