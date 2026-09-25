import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/banner_widget.dart';
import '../widgets/primary_button.dart';
import '../widgets/top_bar.dart';
import '../services/farm_service.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<String> go;

  const HomeScreen({super.key, required this.go});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _acknowledged = false;
  bool _vent = true;
  bool _irrigation = false;
  bool _light = true;

  // ── Data ──────────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _telemetry;
  List<Map<String, dynamic>> _alerts = [];
  String _farmId = '';
  String _farmName = 'Farm';

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
        print('ERROR [HomeScreen]: fetchFarms returned an empty array []');
        setState(() {
          _loading = false;
          _error = 'No farms found in database.';
        });
        return;
      }

      final firstFarm = farms.first;
      _farmId = farms.first['farm_id']?.toString() ?? '';
      _farmName = firstFarm['farm_name'] as String? ?? 'Farm';

      final results = await Future.wait([
        FarmService.fetchLatestTelemetry(_farmId),
        FarmService.fetchRecentAlerts(_farmId, limit: 3),
      ]);

      if (!mounted) return;

      if (results[0] == null) {
        print(
            'ERROR [HomeScreen]: fetchLatestTelemetry returned null / empty array []');
      } else {
        print('DEBUG [HomeScreen]: fetchLatestTelemetry succeeded');
      }

      if ((results[1] as List).isEmpty) {
        print('ERROR [HomeScreen]: fetchRecentAlerts returned empty array []');
      }

      setState(() {
        _telemetry = results[0] as Map<String, dynamic>?;
        _alerts = (results[1] as List<Map<String, dynamic>>);
        _loading = false;
      });
    } catch (e) {
      print('ERROR [HomeScreen]: Failed to fetch data: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load data: $e';
        _loading = false;
      });
    }
  }

  // ── Telemetry helpers ─────────────────────────────────────────────────
  String _temp() {
    final v = _telemetry?['temperature_c'];
    if (v == null) {
      print(
          'ERROR [HomeScreen]: temperature_c field is null in telemetry data');
    }
    if (v == null) return '--';
    final numVal = (v as num?)?.toDouble();
    return numVal != null ? numVal.toStringAsFixed(1) : '--';
  }

  String _humidity() {
    final v = _telemetry?['humidity_percent'];
    if (v == null) {
      print(
          'ERROR [HomeScreen]: humidity_percent field is null in telemetry data');
    }
    if (v == null) return '--';
    final numVal = (v as num?)?.toDouble();
    return numVal != null ? numVal.toStringAsFixed(1) : '--';
  }

  String _power() {
    final v = _telemetry?['power_load_kw'];
    if (v == null) {
      print(
          'ERROR [HomeScreen]: power_load_kw field is null in telemetry data');
    }
    if (v == null) return '--';
    final numVal = (v as num?)?.toDouble();
    return numVal != null ? numVal.toStringAsFixed(1) : '--';
  }

  String _ammonia() {
    final v = _telemetry?['ammonia_ppm'];
    if (v == null) {
      print('ERROR [HomeScreen]: ammonia_ppm field is null in telemetry data');
    }
    if (v == null) return '--';
    final numVal = (v as num?)?.toDouble();
    return numVal != null ? numVal.toStringAsFixed(1) : '--';
  }

  // ── Alert helpers ─────────────────────────────────────────────────────
  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return FarmoraColors.crit;
      case 'warning':
        return FarmoraColors.warn;
      default:
        return FarmoraColors.info;
    }
  }

  String _formatAlertTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            color: FarmoraColors.surface,
            border: Border(bottom: BorderSide(color: FarmoraColors.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _farmName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: FarmoraColors.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Farm overview',
                        style: TextStyle(
                          fontSize: 13,
                          color: FarmoraColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                  TopBar(
                    onBell: () => widget.go('notifications'),
                    onAdvisory: () => widget.go('advisoryList'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const StatusBadge(
                level: 'good',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 11),
                    SizedBox(width: 5),
                    Text('SYSTEM INTEGRITY: ONLINE'),
                  ],
                ),
              ),
            ],
          ),
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
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Live Telemetry
                        Text(
                          'Live telemetry',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: FarmoraColors.ink,
                          ),
                        ),
                        const SizedBox(height: 9),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cellW = (constraints.maxWidth - 10) / 2;
                            const cellH = 100.0;
                            final ratio = cellW / cellH;
                            return GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: ratio,
                              children: [
                                _MetricCard(
                                    icon: Icons.thermostat,
                                    label: 'Barn air temp',
                                    value: _temp(),
                                    unit: 'degC'),
                                _MetricCard(
                                    icon: Icons.water_drop_outlined,
                                    label: 'Relative hum.',
                                    value: _humidity(),
                                    unit: '%'),
                                _MetricCard(
                                    icon: Icons.air,
                                    label: 'Ammonia level',
                                    value: _ammonia(),
                                    unit: 'PPM'),
                                _MetricCard(
                                    icon: Icons.bolt_outlined,
                                    label: 'Power load',
                                    value: _power(),
                                    unit: 'KW'),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),

                        // Uploads Section
                        Text(
                          'Uploads',
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
                              child: _UploadButton(
                                icon: Icons.grain,
                                label: 'Farm Log',
                                onClick: () => widget.go('farmLogInput'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _UploadButton(
                                icon: Icons.upload_file,
                                label: 'Report',
                                onClick: () => widget.go('reportUpload'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Advisory & Guides entry
                        _AdvisoryBannerCard(
                          onTap: () => widget.go('advisoryList'),
                        ),
                        const SizedBox(height: 18),

                        // Active Alerts
                        Text(
                          'Active alerts',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: FarmoraColors.ink,
                          ),
                        ),
                        const SizedBox(height: 9),
                        if (!_acknowledged) ...[
                          if (_alerts.isNotEmpty)
                            BannerWidget(
                                level: 'warn',
                                message:
                                    '${_alerts.length} alert${_alerts.length > 1 ? "s" : ""} require review.'),
                          ..._alerts.map((a) {
                            final sev = (a['severity'] as String? ?? 'warning');
                            final time =
                                _formatAlertTime(a['created_at'] as String?);
                            final type =
                                (a['alert_type'] as String? ?? 'Alert');
                            print(
                                'DEBUG [HomeScreen]: Rendering alert - severity: $sev, type: $type, time: $time');
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _AlertCard(
                                time: '$time · ${sev.toUpperCase()}',
                                message: type,
                                borderColor: _severityColor(sev),
                              ),
                            );
                          }),
                          if (_alerts.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            PrimaryButton(
                              text: 'Acknowledge all alerts',
                              onClick: () =>
                                  setState(() => _acknowledged = true),
                            ),
                          ],
                          if (_alerts.isEmpty)
                            const BannerWidget(
                              level: 'info',
                              message: 'No active alerts. All systems nominal.',
                            ),
                        ] else ...[
                          const BannerWidget(
                            level: 'info',
                            message:
                                'All alerts acknowledged. Monitoring continues automatically.',
                          ),
                        ],
                        const SizedBox(height: 18),

                        // Actuators
                        Text(
                          'Environment actuators',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: FarmoraColors.ink,
                          ),
                        ),
                        const SizedBox(height: 9),
                        FarmoraCard(
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            children: [
                              _ActuatorRow(
                                name: 'Ventilation',
                                on: _vent,
                                onChange: (val) => setState(() => _vent = val),
                              ),
                              Divider(
                                  height: 1,
                                  color: FarmoraColors.line,
                                  indent: 12,
                                  endIndent: 12),
                              _ActuatorRow(
                                name: 'Irrigation',
                                on: _irrigation,
                                onChange: (val) =>
                                    setState(() => _irrigation = val),
                              ),
                              Divider(
                                  height: 1,
                                  color: FarmoraColors.line,
                                  indent: 12,
                                  endIndent: 12),
                              _ActuatorRow(
                                name: 'Lighting',
                                on: _light,
                                onChange: (val) => setState(() => _light = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Recent telemetry log preview
                        Text(
                          'Recent readings',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: FarmoraColors.ink,
                          ),
                        ),
                        const SizedBox(height: 9),
                        if (_telemetry != null)
                          FarmoraCard(
                            padding: const EdgeInsets.all(4),
                            child: Column(
                              children: [
                                _LogRow(
                                  text:
                                      'Temp ${_temp()} \u00b0C | Humidity ${_humidity()}%',
                                  time: _formatAlertTime(
                                      _telemetry!['recorded_at'] as String?),
                                ),
                                Divider(
                                    height: 1,
                                    color: FarmoraColors.line,
                                    indent: 12,
                                    endIndent: 12),
                                _LogRow(
                                  text:
                                      'Ammonia ${_ammonia()} ppm | Power ${_power()} kW',
                                  time: _formatAlertTime(
                                      _telemetry!['recorded_at'] as String?),
                                ),
                              ],
                            ),
                          )
                        else
                          const BannerWidget(
                              level: 'info',
                              message: 'No telemetry readings yet.'),
                      ],
                    ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return FarmoraCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: FarmoraColors.brand),
          const SizedBox(height: 9),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: FarmoraColors.inkSoft),
          ),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: FarmoraColors.ink,
              ),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: FarmoraColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String time;
  final String message;
  final Color borderColor;

  const _AlertCard({
    required this.time,
    required this.message,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FarmoraColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: borderColor, width: 3),
          top: BorderSide(color: FarmoraColors.line),
          right: BorderSide(color: FarmoraColors.line),
          bottom: BorderSide(color: FarmoraColors.line),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: borderColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            message,
            style: TextStyle(fontSize: 12.5, color: FarmoraColors.ink),
          ),
        ],
      ),
    );
  }
}

class _ActuatorRow extends StatelessWidget {
  final String name;
  final bool on;
  final ValueChanged<bool> onChange;

  const _ActuatorRow({
    required this.name,
    required this.on,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FarmoraColors.ink),
              ),
              const SizedBox(height: 1),
              Text(
                on ? 'System: ON \u00b7 Live' : 'System: OFF \u00b7 Standby',
                style: TextStyle(
                  fontSize: 11,
                  color: on ? FarmoraColors.good : FarmoraColors.inkFaint,
                ),
              ),
            ],
          ),
          Switch.adaptive(
            value: on,
            onChanged: onChange,
            activeTrackColor: FarmoraColors.brand,
          ),
        ],
      ),
    );
  }
}

/// Prominent dashboard entry point to the Advisory & Guides library.
class _AdvisoryBannerCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AdvisoryBannerCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FarmoraCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      border: Border.all(color: FarmoraColors.brand.withOpacity(0.35)),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: FarmoraColors.brandSoft,
              borderRadius: const BorderRadius.all(Radius.circular(9)),
            ),
            child: Icon(Icons.lightbulb_outline,
                size: 22, color: FarmoraColors.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Advisory & Guides',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: FarmoraColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Step-by-step field playbooks for current situations',
                  style: TextStyle(fontSize: 12, color: FarmoraColors.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: FarmoraColors.brand,
              borderRadius: const BorderRadius.all(Radius.circular(7)),
            ),
            child: Icon(Icons.arrow_forward_rounded,
                size: 15, color: FarmoraColors.onBrand),
          ),
        ],
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onClick;

  const _UploadButton({
    required this.icon,
    required this.label,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    return FarmoraCard(
      padding: const EdgeInsets.all(14),
      onTap: onClick,
      child: Column(
        children: [
          Icon(icon, size: 28, color: FarmoraColors.brand),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: FarmoraColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final String text;
  final String time;

  const _LogRow({required this.text, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: FarmoraColors.ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: TextStyle(fontSize: 11, color: FarmoraColors.inkFaint),
          ),
        ],
      ),
    );
  }
}
