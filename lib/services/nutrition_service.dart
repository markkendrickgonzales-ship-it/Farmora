import 'package:flutter/foundation.dart';
import 'supabase_client.dart';

// ── Safe JSON cast helpers ─────────────────────────────────────────────────
// Supabase can return numeric/id columns as int, num or String depending on
// the underlying type, so every value read from a response row is normalised
// here instead of being force-cast (see the vitamin_logs int/String lesson).
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

/// Supabase-backed feed-program + nutrition-history store.
///
/// Replaces the former hardcoded demo data. It is a [ChangeNotifier] singleton
/// so the Nutrition screens refresh live once [ensureLoaded] resolves the
/// active batch, its phases and its history. Every query is scoped to the
/// signed-in user (via the active batch, which is itself owner-scoped, plus the
/// RLS policies from migration 0003).
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
      await _resolveBatchContext();
      await Future.wait([_loadPhases(), _loadHistory()]);
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

  // ── Batch / day resolution ────────────────────────────────────────────────

  /// Finds the caller's most-recent batch (id + start_date) and derives the
  /// day-within-cycle. When no `batches` row exists the day stays 1 and reads
  /// fall back to shared templates, so the screen still renders with real
  /// (non-demo) phase data.
  Future<void> _resolveBatchContext() async {
    final userId = supabase.auth.currentUser?.id;
    try {
      dynamic query = supabase
          .from('batches')
          .select('id, start_date, flock_size')
          .order('start_date', ascending: false)
          .limit(1);
      if (userId != null) query = query.eq('owner_id', userId);
      final rows = await query;
      final list = List<Map<String, dynamic>>.from(rows as List);
      if (list.isNotEmpty) {
        final batch = list.first;
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
      }
    } catch (e) {
      // batches table may be absent / column missing — degrade gracefully.
      print('DEBUG: NutritionService._resolveBatchContext skipped = $e');
      _batchId = null;
      _currentDay = 1;
    }
  }

  // ── Feed phases ────────────────────────────────────────────────────────────

  Future<void> _loadPhases() async {
    try {
      List<FeedPhase> phases = const [];
      // 1. Batch-specific phases for the active batch (if any).
      final batchId = _batchId;
      if (batchId != null) {
        final rows = await supabase
            .from('feed_phases')
            .select()
            .eq('batch_id', batchId)
            .order('start_day', ascending: true);
        phases = (rows as List)
            .map((r) => FeedPhase.fromRow(Map<String, dynamic>.from(r)))
            .toList();
      }
      // 2. Fall back to the shared templates (batch_id IS NULL). RLS exposes
      //    these to every authenticated user.
      if (phases.isEmpty) {
        final rows = await supabase
            .from('feed_phases')
            .select()
            .isFilter('batch_id', null)
            .order('start_day', ascending: true);
        phases = (rows as List)
            .map((r) => FeedPhase.fromRow(Map<String, dynamic>.from(r)))
            .toList();
      }
      _phases = phases;
      if (phases.isNotEmpty) {
        _programLength = phases.last.endDay;
        // Keep the current day within the program length.
        if (_currentDay > _programLength) _currentDay = _programLength;
      }
    } catch (e) {
      print('DEBUG: NutritionService._loadPhases error = $e');
      _phases = const [];
    }
    _notify();
  }

  // ── Nutrition history (last 7 days) ────────────────────────────────────────

  Future<void> _loadHistory() async {
    if (_batchId == null) {
      _history = const [];
      _notify();
      return;
    }
    try {
      final since = DateTime.now().subtract(const Duration(days: 6));
      final sinceIso =
          '${since.year.toString().padLeft(4, '0')}-'
          '${since.month.toString().padLeft(2, '0')}-'
          '${since.day.toString().padLeft(2, '0')}';
      final batchId = _batchId!;
      final rows = await supabase
          .from('nutrition_logs')
          .select()
          .eq('batch_id', batchId)
          .gte('log_date', sinceIso)
          .order('log_date', ascending: true);
      final list = (rows as List)
          .map((r) => NutritionReading.fromRow(Map<String, dynamic>.from(r)))
          .toList();
      _history = list;
    } catch (e) {
      print('DEBUG: NutritionService._loadHistory error = $e');
      _history = const [];
    }
    _notify();
  }

  // ── Write (owner-scoped) ─────────────────────────────────────────────────

  /// Inserts or updates one daily reading for the active batch. Stamps
  /// `owner_id` with the signed-in user so the row is isolated to them (RLS
  /// insert policy in migration 0003 also enforces this).
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
    final userId = supabase.auth.currentUser?.id;
    final dateIso =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    await supabase.from('nutrition_logs').upsert({
      'batch_id': _batchId,
      'owner_id': userId,
      'log_date': dateIso,
      'feed_intake_g': intakeG,
      'body_weight_kg': bodyWeightKg,
      'fcr': fcr,
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
    }, onConflict: 'batch_id,log_date');
    await _loadHistory();
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
