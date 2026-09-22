import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/circular_gauge.dart';
import '../widgets/banner_widget.dart';
import '../widgets/screen_header.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../services/farm_service.dart';

class ResourceMonitoringScreen extends StatefulWidget {
  final ValueChanged<String> go;

  const ResourceMonitoringScreen({super.key, required this.go});

  @override
  State<ResourceMonitoringScreen> createState() => _ResourceMonitoringScreenState();
}

class _ResourceMonitoringScreenState extends State<ResourceMonitoringScreen> {
  String _mode = 'FEED';
  String _amount = '';
  String _date = '';
  bool _saved = false;

  // ── Live data ─────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;
  String? _farmId;
  double _totalFeedKg = 0;
  double _totalWaterL = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = '${now.year}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")}';
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
      _farmId = farms.first['farm_id']?.toString() ?? '';
      final logs = await FarmService.fetchFeedingLogs(_farmId!);
      if (!mounted) return;
      final totals = FarmService.aggregateTodayUsage(logs);
      setState(() {
        _totalFeedKg = totals.feedKg;
        _totalWaterL = totals.waterL;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Load failed: $e'; _loading = false; });
    }
  }

  Future<void> _handleSave() async {
    setState(() => _saved = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() { _amount = ''; _saved = false; });
      _loadData(); // refresh totals
    }
  }

  String _feedLabel() {
    if (_totalFeedKg == 0) {
      print('ERROR [ResourceMonitoring]: _totalFeedKg is 0, no feed data available');
    }
    return _totalFeedKg > 0 ? '${_totalFeedKg.toStringAsFixed(1)} kg' : '-- kg';
  }
  String _waterLabel() {
    if (_totalWaterL == 0) {
      print('ERROR [ResourceMonitoring]: _totalWaterL is 0, no water data available');
    }
    return _totalWaterL > 0 ? '${_totalWaterL.toStringAsFixed(0)} L' : '-- L';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayLabel = 'Today, ${_monthName(now.month)} ${now.day}';

    return Column(
      children: [
        ScreenHeader(
          title: 'Resources monitoring',
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
                        const BannerWidget(
                          level: 'crit',
                          message: 'Feed silo 02 level is below 15% threshold. Refill recommended.',
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: FarmoraCard(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: const [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'MAIN FEED SILO',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: FarmoraColors.inkSoft,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    GaugeWidget(
                                      pct: 12,
                                      color: FarmoraColors.crit,
                                      label: '420 kg',
                                      sub: '12% full',
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'CRITICAL · Decreasing · 2m ago',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: FarmoraColors.crit,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                  children: const [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'WEST WATER TANK',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: FarmoraColors.inkSoft,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    GaugeWidget(
                                      pct: 78,
                                      color: FarmoraColors.good,
                                      label: '1,850 L',
                                      sub: '78% full',
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'OPTIMAL · Stable · 5m ago',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: FarmoraColors.good,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Manual refill log',
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: FarmoraColors.surfaceSunken,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: ['FEED', 'WATER'].map((m) {
                                    final active = _mode == m;
                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => _mode = m),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: active ? FarmoraColors.surface : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            m,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: active ? FarmoraColors.ink : FarmoraColors.inkFaint,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Amount (${_mode == "FEED" ? "KG" : "LITERS"})',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: FarmoraColors.inkSoft),
                              ),
                              const SizedBox(height: 6),
                              CustomTextField(
                                placeholder: 'e.g. 50',
                                value: _amount,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setState(() => _amount = val),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Log date',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: FarmoraColors.inkSoft),
                              ),
                              const SizedBox(height: 6),
                              CustomTextField(
                                icon: Icons.calendar_today_outlined,
                                placeholder: 'Select date',
                                value: _date,
                                onChanged: (val) => _date = val,
                              ),
                              const SizedBox(height: 12),
                              PrimaryButton(
                                text: _saved ? 'Entry saved!' : 'Save refill entry',
                                disabled: _amount.isEmpty,
                                onClick: _handleSave,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Usage history — $todayLabel',
                          style: const TextStyle(
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
                              _StatRow(label: 'Total feed dispatched', value: _feedLabel()),
                              const Divider(height: 16, color: FarmoraColors.line),
                              _StatRow(label: 'Water volume used', value: _waterLabel()),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => widget.go('reportCreate'),
                                child: const Text(
                                  'Generate detailed report',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: FarmoraColors.brand,
                                    fontWeight: FontWeight.bold,
                                  ),
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

  String _monthName(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m];
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: FarmoraColors.inkSoft)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: FarmoraColors.ink)),
      ],
    );
  }
}
