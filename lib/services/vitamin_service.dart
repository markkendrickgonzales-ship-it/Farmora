import 'package:flutter/material.dart';
import 'supabase_client.dart';
import 'farm_service.dart';
import 'nutrition_service.dart';

/// A suggested vitamin/additive row from the `vitamin_catalog` table, used to
/// seed the quick-add chips (name + default dosage/unit) instead of hardcoding
/// them in the UI.
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
        id: row['id'].toString(),
        name: row['name'] as String? ?? '',
        defaultDosage: (row['default_dosage'] as num?)?.toDouble(),
        defaultUnit: row['default_unit'] as String?,
        purpose: row['purpose'] as String?,
        isDefault: row['is_default'] as bool? ?? false,
      );
}

/// One logged daily dose, read from `vitamin_logs_view` (which resolves the
/// display name via COALESCE(catalog.name, custom_name)).
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
    final date = DateTime.tryParse(row['log_date'] as String? ?? '') ??
        DateTime.now();
    return VitaminLogEntry(
      id: row['id'].toString(),
      vitaminId: row['vitamin_id'] as String?,
      displayName: row['display_name'] as String? ??
          row['custom_name'] as String? ??
          'Vitamin',
      dosage: (row['dosage'] as num?)?.toDouble() ?? 0,
      unit: row['unit'] as String? ?? '',
      logDate: DateTime(date.year, date.month, date.day),
      timeGiven: _parseTime(row['time_given'] as String?),
      dayNumber: (row['day_number'] as num?)?.toInt() ?? 1,
      notes: row['notes'] as String?,
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

/// Supabase-backed store for the daily vitamin log, following the app's
/// `supabase.from(...)` query style. It is a [ChangeNotifier] singleton so the
/// parent Nutrition pill and the Vitamins screen refresh live after every
/// insert / update / delete.
class VitaminService extends ChangeNotifier {
  VitaminService._();

  static final VitaminService instance = VitaminService._();

  /// The four selectable dosing units offered by the entry form.
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

  /// Loads catalog + today's log once. Safe to call from multiple screens;
  /// [force] re-fetches even if already loaded.
  Future<void> ensureLoaded({bool force = false}) async {
    if (_loaded && !force) return;
    await load();
  }

  Future<void> load() async {
    _setLoading(true);
    _error = null;
    try {
      await _resolveBatchContext();
      await Future.wait([_loadCatalog(), _loadTodayLogs()]);
      _loaded = true;
    } catch (e) {
      print('DEBUG: VitaminService.load error = $e');
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── Reads ───────────────────────────────────────────────────────────────

  Future<void> _loadCatalog() async {
    try {
      final data = await supabase
          .from('vitamin_catalog')
          .select()
          .order('is_default', ascending: false)
          .order('name', ascending: true);
      _catalog = (data as List)
          .map((r) => VitaminCatalogItem.fromRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      // Catalog may be empty before the migration is applied — not fatal.
      print('DEBUG: VitaminService._loadCatalog skipped = $e');
      _catalog = const [];
    }
    _notify();
  }

  Future<void> _loadTodayLogs() async {
    if (_batchId == null || _batchId!.isEmpty) {
      _todayLogs = const [];
      _notify();
      return;
    }
    try {
      final data = await supabase
          .from('vitamin_logs_view')
          .select()
          .eq('batch_id', _batchId!)
          .eq('log_date', _todayIso())
          .order('time_given', ascending: false);
      _todayLogs = (data as List)
          .map((r) => VitaminLogEntry.fromRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      print('DEBUG: VitaminService._loadTodayLogs error = $e');
      _todayLogs = const [];
      rethrow;
    }
    _notify();
  }

  // ── Writes ──────────────────────────────────────────────────────────────

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
    final user = supabase.auth.currentUser;
    final payload = <String, dynamic>{
      'batch_id': _batchId,
      'vitamin_id': vitaminId,
      'custom_name': (customName != null && customName.trim().isNotEmpty)
          ? customName.trim()
          : null,
      'dosage': dosage,
      'unit': unit,
      'log_date': _isoDate(date),
      'time_given': _isoTime(time),
      'day_number': _dayNumber,
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
      'logged_by': user?.id,
    };
    try {
      await supabase.from('vitamin_logs').insert(payload).select().single();
      await _loadTodayLogs();
    } catch (e) {
      print('DEBUG: VitaminService.insertLog error = $e');
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
    final payload = <String, dynamic>{
      'vitamin_id': vitaminId,
      'custom_name': (customName != null && customName.trim().isNotEmpty)
          ? customName.trim()
          : null,
      'dosage': dosage,
      'unit': unit,
      'log_date': _isoDate(date),
      'time_given': _isoTime(time),
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
    };
    try {
      await supabase
          .from('vitamin_logs')
          .update(payload)
          .eq('id', id)
          .select()
          .single();
      await _loadTodayLogs();
    } catch (e) {
      print('DEBUG: VitaminService.updateLog error = $e');
      rethrow;
    }
  }

  Future<void> deleteLog(String id) async {
    try {
      await supabase.from('vitamin_logs').delete().eq('id', id);
      await _loadTodayLogs();
    } catch (e) {
      print('DEBUG: VitaminService.deleteLog error = $e');
      rethrow;
    }
  }

  // ── Batch / day resolution ────────────────────────────────────────────────

  /// Resolves the active batch id and day-within-cycle number. Prefers a real
  /// `batches` row (id + start_date); falls back to the telemetry farm id and
  /// the feed-cycle day tracked by [NutritionService] so logging still works
  /// in the current Farmora schema.
  Future<void> _resolveBatchContext() async {
    try {
      final rows = await supabase
          .from('batches')
          .select('id, start_date')
          .order('start_date', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(rows as List);
      if (list.isNotEmpty) {
        _batchId = list.first['id']?.toString();
        final start =
            DateTime.tryParse(list.first['start_date'] as String? ?? '');
        if (start != null) {
          final now = DateTime.now();
          final days = DateTime(now.year, now.month, now.day)
              .difference(DateTime(start.year, start.month, start.day))
              .inDays +
              1;
          _dayNumber = days.clamp(1, 45);
          return;
        }
        _dayNumber = NutritionService.instance.currentDay;
        return;
      }
    } catch (e) {
      print('DEBUG: VitaminService batches lookup skipped = $e');
    }

    // Fallback: telemetry farm id + feed-cycle day.
    try {
      final farms = await FarmService.fetchTelemetryFarms();
      if (farms.isNotEmpty) {
        _batchId = farms.first['farm_id']?.toString();
      }
    } catch (e) {
      print('DEBUG: VitaminService farm fallback skipped = $e');
    }
    _dayNumber = NutritionService.instance.currentDay;
  }

  void _requireBatch() {
    if (_batchId == null || _batchId!.isEmpty) {
      throw Exception('No active batch or farm is available to log against.');
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String _todayIso() => _isoDate(DateTime.now());

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _isoTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:00';

  void _setLoading(bool v) {
    _loading = v;
    _notify();
  }

  void _notify() {
    notifyListeners();
  }
}
