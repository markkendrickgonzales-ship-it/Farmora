import 'package:flutter/material.dart';
import 'api_service.dart';
import 'nutrition_service.dart';

String? _asStr(dynamic v) => v?.toString();

num? _asNum(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  return null;
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true' || v == 't' || v == '1';
  return false;
}

class VitaminCatalogItem {
  final String id;
  final String name;
  final double? defaultDosage;
  final String? defaultUnit;
  final String? purpose;
  final bool isDefault;

  const VitaminCatalogItem({
    required this.id,
    required this.name,
    this.defaultDosage,
    this.defaultUnit,
    this.purpose,
    this.isDefault = false,
  });

  factory VitaminCatalogItem.fromRow(Map<String, dynamic> row) =>
      VitaminCatalogItem(
        id: _asStr(row['id']) ?? '',
        name: _asStr(row['name']) ?? '',
        defaultDosage: _asNum(row['default_dosage'])?.toDouble(),
        defaultUnit: _asStr(row['default_unit']),
        purpose: _asStr(row['purpose']),
        isDefault: _asBool(row['is_default']),
      );
}

class VitaminLogEntry {
  final String id;
  final String? vitaminId;
  final String displayName;
  final double dosage;
  final String unit;
  final DateTime logDate;
  final TimeOfDay timeGiven;
  final int dayNumber;
  final String? notes;

  const VitaminLogEntry({
    required this.id,
    required this.vitaminId,
    required this.displayName,
    required this.dosage,
    required this.unit,
    required this.logDate,
    required this.timeGiven,
    required this.dayNumber,
    this.notes,
  });

  factory VitaminLogEntry.fromRow(Map<String, dynamic> row) {
    final date =
        DateTime.tryParse(_asStr(row['log_date']) ?? '') ?? DateTime.now();
    return VitaminLogEntry(
      id: _asStr(row['id']) ?? '',
      vitaminId: _asStr(row['vitamin_id']),
      displayName: _asStr(row['display_name']) ??
          _asStr(row['custom_name']) ??
          'Vitamin',
      dosage: _asNum(row['dosage'])?.toDouble() ?? 0,
      unit: _asStr(row['unit']) ?? '',
      logDate: DateTime(date.year, date.month, date.day),
      timeGiven: _parseTime(_asStr(row['time_given'])),
      dayNumber: _asNum(row['day_number'])?.toInt() ?? 1,
      notes: _asStr(row['notes']),
    );
  }

  static TimeOfDay _parseTime(String? raw) {
    if (raw == null) return TimeOfDay.now();
    final parts = raw.split(':');
    final h = int.tryParse(parts[0]) ?? TimeOfDay.now().hour;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: h, minute: m);
  }

  String get _dosageText {
    if (dosage == dosage.roundToDouble()) return dosage.toStringAsFixed(0);
    return dosage.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
  }

  String get dosageLabel => '$_dosageText $unit';

  String get timeLabel {
    final h = timeGiven.hourOfPeriod == 0 ? 12 : timeGiven.hourOfPeriod;
    final m = timeGiven.minute.toString().padLeft(2, '0');
    final ap = timeGiven.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ap';
  }
}

class VitaminService extends ChangeNotifier {
  VitaminService._();

  static final VitaminService instance = VitaminService._();

  static const List<String> units = [
    'mL/L water',
    'g/L water',
    'mg/bird',
    'drops/bird',
  ];

  List<VitaminCatalogItem> _catalog = const [];
  List<VitaminLogEntry> _todayLogs = const [];
  bool _loading = false;
  String? _error;
  String? _batchId;
  int _dayNumber = 1;
  bool _loaded = false;

  List<VitaminCatalogItem> get catalog => _catalog;
  List<VitaminLogEntry> get todayLogs => _todayLogs;
  bool get loading => _loading;
  String? get error => _error;
  int get loggedTodayCount => _todayLogs.length;
  int get dayNumber => _dayNumber;

  void reset() {
    _catalog = const [];
    _todayLogs = const [];
    _batchId = null;
    _dayNumber = 1;
    _loaded = false;
    _loading = false;
    _error = null;
    _notify();
  }

  Future<void> ensureLoaded({bool force = false}) async {
    if (_loaded && !force) return;
    await load();
  }

  Future<void> load() async {
    _setLoading(true);
    _error = null;
    try {
      await _fetchAll();
      _loaded = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _fetchAll() async {
    final data = await ApiService.instance.get('vitamins.php');
    final map = Map<String, dynamic>.from(data as Map);

    _batchId = _asStr(map['batch_id']);
    _dayNumber = _asNum(map['day_number'])?.toInt() ??
        NutritionService.instance.currentDay;

    _catalog = (map['catalog'] as List? ?? [])
        .map((r) =>
            VitaminCatalogItem.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
    _todayLogs = (map['logs'] as List? ?? [])
        .map(
            (r) => VitaminLogEntry.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
    _notify();
  }

  Map<String, dynamic> _logPayload({
    String? vitaminId,
    String? customName,
    required double dosage,
    required String unit,
    required DateTime date,
    required TimeOfDay time,
    String? notes,
  }) =>
      <String, dynamic>{
        'batch_id': int.tryParse(_batchId ?? '') ?? _batchId,
        'vitamin_id': int.tryParse(vitaminId ?? '') ?? vitaminId,
        'custom_name': (customName != null && customName.trim().isNotEmpty)
            ? customName.trim()
            : null,
        'dosage': dosage,
        'unit': unit,
        'log_date': _isoDate(date),
        'time_given': _isoTime(time),
        'day_number': _dayNumber,
        'notes':
            (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
      };

  Future<void> insertLog({
    String? vitaminId,
    String? customName,
    required double dosage,
    required String unit,
    required DateTime date,
    required TimeOfDay time,
    String? notes,
  }) async {
    _requireBatch();
    try {
      await ApiService.instance.post(
          'save_vitamin_log.php',
          _logPayload(
            vitaminId: vitaminId,
            customName: customName,
            dosage: dosage,
            unit: unit,
            date: date,
            time: time,
            notes: notes,
          ));
      await _fetchAll();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateLog(
    String id, {
    String? vitaminId,
    String? customName,
    required double dosage,
    required String unit,
    required DateTime date,
    required TimeOfDay time,
    String? notes,
  }) async {
    try {
      await ApiService.instance.post('save_vitamin_log.php', {
        ..._logPayload(
          vitaminId: vitaminId,
          customName: customName,
          dosage: dosage,
          unit: unit,
          date: date,
          time: time,
          notes: notes,
        ),
        'id': int.tryParse(id) ?? id,
      });
      await _fetchAll();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteLog(String id) async {
    try {
      await ApiService.instance
          .post('delete_vitamin_log.php', {'id': int.tryParse(id) ?? id});
      await _fetchAll();
    } catch (e) {
      rethrow;
    }
  }

  void _requireBatch() {
    if (_batchId == null || _batchId!.isEmpty) {
      throw Exception('No active batch or farm is available to log against.');
    }
  }

  String _isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _isoTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:00';

  void _setLoading(bool v) {
    _loading = v;
    _notify();
  }

  void _notify() {
    notifyListeners();
  }
}
