import 'package:flutter/foundation.dart';
import 'api_service.dart';

// ── Safe JSON cast helpers ─────────────────────────────────────────────────
// The PHP/MySQL backend can return numeric/id columns as int, num or String
// depending on the underlying type, so every value read from a response row
// is normalised here instead of being force-cast.
num? _asNum(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  return null;
}

String? _asStr(dynamic v) => v?.toString();

/// One nutritional phase of a broiler batch (Starter → Grower → Finisher),
/// including its guaranteed-analysis values. Read from the `feed_phases` table.
class FeedPhase {
  final String name;
  final int startDay;
  final int endDay;
  final double crudeProtein; // %
  final double crudeFat; // %
  final double crudeFiber; // %
  final double calcium; // %
  final double phosphorus; // %
  final double lysine; // %
  final double methionine; // %
  final double metabolizableEnergy; // kcal/kg

  const FeedPhase({
    required this.name,
    required this.startDay,
    required this.endDay,
    required this.crudeProtein,
    required this.crudeFat,
    required this.crudeFiber,
    required this.calcium,
    required this.phosphorus,
    required this.lysine,
    required this.methionine,
    required this.metabolizableEnergy,
  });

  factory FeedPhase.fromRow(Map<String, dynamic> row) => FeedPhase(
        name: _asStr(row['name']) ?? 'Phase',
        startDay: _asNum(row['start_day'])?.toInt() ?? 1,
        endDay: _asNum(row['end_day'])?.toInt() ?? 1,
        crudeProtein: _asNum(row['crude_protein'])?.toDouble() ?? 0,
        crudeFat: _asNum(row['crude_fat'])?.toDouble() ?? 0,
        crudeFiber: _asNum(row['crude_fiber'])?.toDouble() ?? 0,
        calcium: _asNum(row['calcium'])?.toDouble() ?? 0,
        phosphorus: _asNum(row['phosphorus'])?.toDouble() ?? 0,
        lysine: _asNum(row['lysine'])?.toDouble() ?? 0,
        methionine: _asNum(row['methionine'])?.toDouble() ?? 0,
        metabolizableEnergy: _asNum(row['metabolizable_energy'])?.toDouble() ?? 0,
      );

  bool contains(int day) => day >= startDay && day <= endDay;

  bool isPast(int currentDay) => endDay < currentDay;
  bool isUpcoming(int currentDay) => startDay > currentDay;

  /// Status used on the Feed-program screen: done / active / upcoming.
  String statusFor(int currentDay) {
    if (isPast(currentDay)) return 'done';
    if (contains(currentDay)) return 'active';
    return 'upcoming';
  }
}

/// A single daily nutrition reading (feed intake per bird + FCR) for the
/// "Nutrition history" strip, read from the `nutrition_logs` table.
class NutritionReading {
  final DateTime date;
  final double intakeG; // grams / bird / day
  final double? fcr; // feed conversion ratio (null when not recorded)

  const NutritionReading({
    required this.date,
    required this.intakeG,
    this.fcr,
  });

  factory NutritionReading.fromRow(Map<String, dynamic> row) => NutritionReading(
        date: DateTime.tryParse(_asStr(row['log_date']) ?? '') ?? DateTime.now(),
        intakeG: _asNum(row['feed_intake_g'])?.toDouble() ?? 0,
        fcr: _asNum(row['fcr'])?.toDouble(),
      );
}

/// Immutable snapshot of the active batch's nutrition program, built by
/// [NutritionService] once real data is loaded. Screens read it synchronously.
class BatchNutritionState {
  final String batchId;
  final int currentDay;
  final int programLength;
  final List<FeedPhase> phases;

  const BatchNutritionState({
    required this.batchId,
    required this.currentDay,
    required this.programLength,
    required this.phases,
  });

  FeedPhase get currentPhase =>
      phases.firstWhere((p) => p.contains(currentDay), orElse: () => phases.first);

  /// Subtitle for the Feed-program row, e.g. "Grower phase · Day 18 of 45".
  String get phaseLabel =>
      '${currentPhase.name} phase · Day $currentDay of $programLength';
}

/// Hostinger PHP/MySQL-backed feed-program + nutrition-history store.
///
/// Replaces the former hardcoded demo data. It is a [ChangeNotifier] singleton
/// so the Nutrition screens refresh live once [ensureLoaded] resolves the
/// active batch, its phases and its history. Every query is scoped to the
/// signed-in user server-side: the PHP endpoint resolves the batch through the
/// bearer token's owner id.
class NutritionService extends ChangeNotifier {
  NutritionService._();

  static final NutritionService instance = NutritionService._();

  List<FeedPhase> _phases = const [];
  List<NutritionReading> _history = const [];
  String? _batchId;
  int _currentDay = 1;
  int _programLength = 45;
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;
  String? get batchId => _batchId;
  int get currentDay => _currentDay;
  int get programLength => _programLength;
  List<FeedPhase> get phases => _phases;
  List<NutritionReading> get history => _history;

  /// True once real phases are available; screens use this to decide whether
  /// to show content or a loading / empty state (no more fake data).
  bool get hasData => _phases.isNotEmpty;

  /// The current program snapshot, or null while loading / when the user has
  /// no feed phases yet. Callers must null-check (screens show a spinner).
  BatchNutritionState? get state {
    if (_phases.isEmpty) return null;
    return BatchNutritionState(
      batchId: _batchId ?? '',
      currentDay: _currentDay,
      programLength: _programLength,
      phases: _phases,
    );
  }

  /// Loads the program once. Safe to call from multiple screens; [force]
  /// re-fetches even if already loaded.
  Future<void> ensureLoaded({bool force = false}) async {
    if (_loaded && !force) return;
    await load();
  }

  Future<void> load() async {
    _setLoading(true);
    _error = null;
    try {
      await _loadProgram();
      _loaded = true;
    } catch (e) {
      print('DEBUG: NutritionService.load error = $e');
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Clears all cached, per-user data so the next [ensureLoaded] re-fetches
  /// for a newly signed-in user. Called on sign-out / account switch.
  void reset() {
    _phases = const [];
    _history = const [];
    _batchId = null;
    _currentDay = 1;
    _programLength = 45;
    _loaded = false;
    _loading = false;
    _error = null;
    _notify();
  }

  // ── Program fetch ───────────────────────────────────────────────────────
  //
  // get_feed_program.php resolves everything this store needs in one round
  // trip: the caller's most-recent batch (id + start_date), the batch's feed
  // phases (falling back to the shared templates server-side) and the last
  // 7 days of nutrition history.

  Future<void> _loadProgram() async {
    final data = await ApiService.instance.get('get_feed_program.php');
    final map = Map<String, dynamic>.from(data as Map);

    final batch = map['batch'];
    if (batch is Map) {
      _batchId = _asStr(batch['id']);
      final start = DateTime.tryParse(_asStr(batch['start_date']) ?? '');
      if (start != null) {
        final now = DateTime.now();
        final days = DateTime(now.year, now.month, now.day)
                .difference(DateTime(start.year, start.month, start.day))
                .inDays +
            1;
        _currentDay = days < 1 ? 1 : days;
      }
    } else {
      // No batches row for this user — day stays 1 and shared template
      // phases are what the backend returned, so the screen still renders
      // with real (non-demo) data.
      _batchId = null;
      _currentDay = 1;
    }

    _phases = (map['phases'] as List? ?? [])
        .map((r) => FeedPhase.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
    _history = (map['history'] as List? ?? [])
        .map((r) => NutritionReading.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();

    if (_phases.isNotEmpty) {
      _programLength = _phases.last.endDay;
      // Keep the current day within the program length.
      if (_currentDay > _programLength) _currentDay = _programLength;
    }
    _notify();
  }

  Future<void> _reloadHistory() async {
    try {
      await _loadProgram();
    } catch (e) {
      print('DEBUG: NutritionService._reloadHistory error = $e');
    }
  }

  // ── Write ───────────────────────────────────────────────────────────────

  /// Inserts or updates one daily reading for the active batch through
  /// upsert_nutrition_log.php, which stamps the row with the token's user id.
  Future<void> upsertDailyReading({
    required DateTime date,
    required double intakeG,
    double? bodyWeightKg,
    double? fcr,
    String? notes,
  }) async {
    if (_batchId == null) {
      throw Exception('No active batch to record nutrition against.');
    }
    final dateIso =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    await ApiService.instance.post('upsert_nutrition_log.php', {
      'batch_id': int.tryParse(_batchId!) ?? _batchId,
      'log_date': dateIso,
      'feed_intake_g': intakeG,
      'body_weight_kg': bodyWeightKg,
      'fcr': fcr,
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
    });
    await _reloadHistory();
  }

  // ── Notify helpers ─────────────────────────────────────────────────────────

  void _setLoading(bool v) {
    _loading = v;
    _notify();
  }

  void _notify() {
    notifyListeners();
  }
}
