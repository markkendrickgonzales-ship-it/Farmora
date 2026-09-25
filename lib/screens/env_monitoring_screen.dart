import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/banner_widget.dart';
import '../widgets/screen_header.dart';
import '../services/farm_service.dart';

class EnvMonitoringScreen extends StatefulWidget {
  final ValueChanged<String> go;

  const EnvMonitoringScreen({super.key, required this.go});

  @override
  State<EnvMonitoringScreen> createState() => _EnvMonitoringScreenState();
}

class _EnvMonitoringScreenState extends State<EnvMonitoringScreen> {
  bool _exhaust = true;
  bool _circulation = false;
  bool _flaps = true;
  String _lastSync = 'Never';
  bool _refreshing = false;

  // ── Live data ─────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _telemetry;
  String? _farmId;

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
        print(
            'ERROR [EnvMonitoring]: Data fetch returned empty farms array []');
        setState(() {
          _loading = false;
          _error = 'No farms found.';
        });
        return;
      }
      _farmId = farms.first['farm_id']?.toString() ?? '';
      final t = await FarmService.fetchLatestTelemetry(_farmId!);
      if (!mounted) return;

      if (t == null) {
        print('ERROR [EnvMonitoring]: Telemetry array was empty []');
      } else {
        print('DEBUG [EnvMonitoring]: Telemetry fetched successfully');
      }

      setState(() {
        _telemetry = t;
        _loading = false;
        _lastSync = 'Just now';
      });
    } catch (e) {
      print('ERROR [EnvMonitoring]: Failed to fetch data: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Load failed: $e';
        _loading = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _refreshing = true);
    try {
      if (_farmId != null) {
        final t = await FarmService.fetchLatestTelemetry(_farmId!);
        if (mounted)
          setState(() {
            _telemetry = t;
            _lastSync = 'Just now';
          });
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  String _fmt(String key, {int decimals = 1}) {
    final v = _telemetry?[key];
    if (v == null) {
      print('ERROR [EnvMonitoring]: Field "$key" is null in telemetry data');
    }
    if (v == null) return '--';
    final numVal = (v as num?)?.toDouble();
    return numVal != null ? numVal.toStringAsFixed(decimals) : '--';
  }

  String _tempStr() => '${_fmt("temperature_c")}°C';
  String _humStr() => '${_fmt("humidity_percent")}%';

  String _humLevel() {
    final v = (_telemetry?['humidity_percent'] as num?)?.toDouble();
    if (v == null) {
      print(
          'ERROR [EnvMonitoring]: humidity_percent is null, cannot determine level');
      return 'good';
    }
    return v >= 75
        ? 'crit'
        : v >= 65
            ? 'warn'
            : 'good';
  }

  String _humTag() {
    final v = (_telemetry?['humidity_percent'] as num?)?.toDouble();
    if (v == null) {
      print(
          'ERROR [EnvMonitoring]: humidity_percent is null, cannot determine tag');
      return 'NORMAL';
    }
    return v >= 75
        ? 'HIGH'
        : v >= 65
            ? 'WARNING'
            : 'NORMAL';
  }

  String _tempLevel() {
    final v = (_telemetry?['temperature_c'] as num?)?.toDouble();
    if (v == null) {
      print(
          'ERROR [EnvMonitoring]: temperature_c is null, cannot determine level');
      return 'good';
    }
    return v >= 30
        ? 'crit'
        : v >= 27
            ? 'warn'
            : 'good';
  }

  String _tempTag() {
    final v = (_telemetry?['temperature_c'] as num?)?.toDouble();
    if (v == null) {
      print(
          'ERROR [EnvMonitoring]: temperature_c is null, cannot determine tag');
      return 'NORMAL';
    }
    return v >= 30
        ? 'HIGH'
        : v >= 27
            ? 'WARM'
            : 'NORMAL';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScreenHeader(
          title: 'Environmental monitoring',
          onBack: () => widget.go('monitoringHub'),
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
                    ))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_telemetry == null)
                          const BannerWidget(
                            level: 'warn',
                            message: 'No telemetry data available yet.',
                          )
                        else
                          BannerWidget(
                            level: _humLevel() == 'good' ? 'info' : _humLevel(),
                            message: _humLevel() == 'good'
                                ? 'All environmental readings are within normal range.'
                                : 'Humidity at ${_humStr()} — review ventilation settings.',
                          ),
                        const SizedBox(height: 18),
                        Text(
                          'Real-time data',
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
                              _DataRow(
                                icon: Icons.thermostat,
                                label: 'Temperature',
                                value: _tempStr(),
                                level: _tempLevel(),
                                tag: _tempTag(),
                              ),
                              Divider(
                                  height: 1,
                                  color: FarmoraColors.line,
                                  indent: 12,
                                  endIndent: 12),
                              _DataRow(
                                icon: Icons.water_drop_outlined,
                                label: 'Humidity',
                                value: _humStr(),
                                level: _humLevel(),
                                tag: _humTag(),
                              ),
                              Divider(
                                  height: 1,
                                  color: FarmoraColors.line,
                                  indent: 12,
                                  endIndent: 12),
                              _DataRow(
                                icon: Icons.air,
                                label: 'Ammonia',
                                value: '${_fmt("ammonia_ppm")} ppm',
                                level: 'good',
                                tag: 'LIVE',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Climate control',
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
                              _ClimateRow(
                                  name: 'Exhaust fans',
                                  desc: 'Main ventilation units',
                                  on: _exhaust,
                                  tag: 'Manual mode',
                                  onChange: (v) =>
                                      setState(() => _exhaust = v)),
                              Divider(
                                  height: 1,
                                  color: FarmoraColors.line,
                                  indent: 12,
                                  endIndent: 12),
                              _ClimateRow(
                                  name: 'Circulation fans',
                                  desc: 'Internal air movement',
                                  on: _circulation,
                                  onChange: (v) =>
                                      setState(() => _circulation = v)),
                              Divider(
                                  height: 1,
                                  color: FarmoraColors.line,
                                  indent: 12,
                                  endIndent: 12),
                              _ClimateRow(
                                  name: 'Ventilation flaps',
                                  desc: 'Ceiling ridge vents',
                                  on: _flaps,
                                  onChange: (v) => setState(() => _flaps = v)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Latest reading',
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
                                padding: const EdgeInsets.all(13),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('TEMPERATURE',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: FarmoraColors.inkSoft)),
                                    const SizedBox(height: 3),
                                    Text(_tempStr(),
                                        style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: FarmoraColors.ink)),
                                    const SizedBox(height: 1),
                                    Text(_tempTag(),
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            color: FarmoraColors.inkFaint)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FarmoraCard(
                                padding: const EdgeInsets.all(13),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('HUMIDITY',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: FarmoraColors.inkSoft)),
                                    const SizedBox(height: 3),
                                    Text(_humStr(),
                                        style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: FarmoraColors.ink)),
                                    const SizedBox(height: 1),
                                    Text(_humTag(),
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            color: FarmoraColors.inkFaint)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        FarmoraCard(
                          padding: const EdgeInsets.all(13),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('GATEWAY FM-02',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: FarmoraColors.ink)),
                                  const SizedBox(height: 2),
                                  Text('Connected · last sync $_lastSync',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: FarmoraColors.good)),
                                ],
                              ),
                              IconButton(
                                icon: Icon(
                                    _refreshing ? Icons.sync : Icons.refresh,
                                    size: 18,
                                    color: FarmoraColors.brand),
                                onPressed: _handleRefresh,
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

class _DataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String level;
  final String tag;

  const _DataRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.level,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: FarmoraColors.inkSoft),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: FarmoraColors.ink)),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: FarmoraColors.ink)),
              const SizedBox(width: 8),
              StatusBadge(level: level, child: Text(tag)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClimateRow extends StatelessWidget {
  final String name;
  final String desc;
  final bool on;
  final ValueChanged<bool> onChange;
  final String? tag;

  const _ClimateRow({
    required this.name,
    required this.desc,
    required this.on,
    required this.onChange,
    this.tag,
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
              Text(name,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: FarmoraColors.ink)),
              const SizedBox(height: 1),
              Text(
                '$desc${tag != null ? " · $tag" : ""}',
                style: TextStyle(fontSize: 11, color: FarmoraColors.inkFaint),
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
