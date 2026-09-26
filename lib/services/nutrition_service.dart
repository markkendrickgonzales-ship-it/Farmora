import 'package:flutter/material.dart';

/// Feed-phase and vitamin-dosing models plus the in-memory
/// [BatchNutritionState] the Nutrition screens read and mutate.
///
/// The service is a [ChangeNotifier]: marking a dose as given flips its status
/// and notifies listeners, so "due today" pills on the Nutrition hub update
/// live without a manual refresh.

enum DoseStatus { given, due, scheduled }

/// One nutritional phase of a broiler batch (Starter → Grower → Finisher),
/// including its guaranteed-analysis values.
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

  bool contains(int day) => day >= startDay && day <= endDay;

  bool get isPast => endDay < NutritionService.instance.currentDay;

  /// Status used on the Feed-program screen: done / active / upcoming.
  String get batchStatus {
    if (isPast) return 'done';
    if (contains(NutritionService.instance.currentDay)) return 'active';
    return 'upcoming';
  }
}

/// A single scheduled vitamin/additive dose given through drinking water.
class VitaminDose {
  final String name;
  final double dosage;
  final String unit; // e.g. 'mL / L water'
  final String timeOfDay; // morning / afternoon / evening
  final TimeOfDay scheduledTime;
  final DateTime date; // local, time stripped
  DoseStatus status;
  DateTime? dateGiven;

  VitaminDose({
    required this.name,
    required this.dosage,
    required this.unit,
    required this.timeOfDay,
    required this.scheduledTime,
    required this.date,
    this.status = DoseStatus.scheduled,
    this.dateGiven,
  });

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// Doses that are due get re-tagged; anything not yet due stays scheduled.
  DoseStatus get effectiveStatus {
    if (status == DoseStatus.given) return DoseStatus.given;
    final now = DateTime.now();
    if (!date.isAfter(DateTime(now.year, now.month, now.day))) {
      final dueAt = DateTime(date.year, date.month, date.day,
          scheduledTime.hour, scheduledTime.minute);
      if (!now.isBefore(dueAt)) return DoseStatus.due;
    }
    return DoseStatus.scheduled;
  }

  String get timeLabel {
    final h = scheduledTime.hourOfPeriod == 0
        ? 12
        : scheduledTime.hourOfPeriod;
    final m = scheduledTime.minute.toString().padLeft(2, '0');
    final ap = scheduledTime.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  String get dosageLine => '$dosage $unit · ${timeOfDay.toLowerCase()}';
}

/// The live state of the active batch. [currentDay] is a plain field and
/// mutations go through [markGiven]/[markScheduled], which notify listeners.
class BatchNutritionState {
  final String batchId;
  int currentDay;
  final int programLength;
  final List<FeedPhase> phases;
  final List<VitaminDose> doses;

  BatchNutritionState({
    required this.batchId,
    required this.currentDay,
    required this.programLength,
    required this.phases,
    required this.doses,
  });

  FeedPhase get currentPhase =>
      phases.firstWhere((p) => p.contains(currentDay), orElse: () => phases.last);

  List<VitaminDose> get todayDoses {
    for (final d in doses) {
      if (d.status != DoseStatus.given && d.effectiveStatus == DoseStatus.due) {
        d.status = DoseStatus.due;
      }
    }
    final today = doses.where((d) => d.isToday).toList()
      ..sort((a, b) => a.scheduledTime.hour * 60 + a.scheduledTime.minute -
          (b.scheduledTime.hour * 60 + b.scheduledTime.minute));
    return today;
  }

  int get dueTodayCount =>
      todayDoses.where((d) => d.effectiveStatus == DoseStatus.due).length;

  /// Subtitle for the Feed-program row, e.g. "Grower phase · Day 18 of 45".
  String get phaseLabel =>
      '${currentPhase.name} phase · Day $currentDay of $programLength';
}

class NutritionService extends ChangeNotifier {
  NutritionService._() {
    _state = _seed();
  }

  static final NutritionService instance = NutritionService._();

  late BatchNutritionState _state;
  BatchNutritionState get state => _state;

  int get currentDay => _state.currentDay;

  DateTime _dateOf(int offsetDays) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: offsetDays));
  }

  BatchNutritionState _seed() {
    const phases = [
      FeedPhase(
        name: 'Starter', startDay: 1, endDay: 14,
        crudeProtein: 23.0, crudeFat: 5.0, crudeFiber: 4.0,
        calcium: 1.0, phosphorus: 0.65, lysine: 1.40, methionine: 0.60,
        metabolizableEnergy: 3000,
      ),
      FeedPhase(
        name: 'Grower', startDay: 15, endDay: 28,
        crudeProtein: 21.0, crudeFat: 5.5, crudeFiber: 4.5,
        calcium: 0.95, phosphorus: 0.60, lysine: 1.30, methionine: 0.55,
        metabolizableEnergy: 3100,
      ),
      FeedPhase(
        name: 'Finisher', startDay: 29, endDay: 45,
        crudeProtein: 19.0, crudeFat: 6.0, crudeFiber: 5.0,
        calcium: 0.90, phosphorus: 0.55, lysine: 1.20, methionine: 0.50,
        metabolizableEnergy: 3200,
      ),
    ];

    final doses = <VitaminDose>[
      // Yesterday — one given, one missed-then-given-late.
      VitaminDose(
        name: 'Vitamin AD3E', dosage: 1, unit: 'mL / L water',
        timeOfDay: 'Morning', scheduledTime: const TimeOfDay(hour: 9, minute: 0),
        date: _dateOf(-1), status: DoseStatus.given, dateGiven: _dateOf(-1),
      ),
      VitaminDose(
        name: 'Electrolyte + Vitamin C', dosage: 2, unit: 'g / L water',
        timeOfDay: 'Afternoon', scheduledTime: const TimeOfDay(hour: 15, minute: 0),
        date: _dateOf(-1), status: DoseStatus.given, dateGiven: _dateOf(-1),
      ),
      // Today.
      VitaminDose(
        name: 'Vitamin AD3E', dosage: 1, unit: 'mL / L water',
        timeOfDay: 'Morning', scheduledTime: const TimeOfDay(hour: 8, minute: 0),
        date: _dateOf(0), status: DoseStatus.given, dateGiven: _dateOf(0),
      ),
      VitaminDose(
        name: 'B-Complex', dosage: 1, unit: 'mL / L water',
        timeOfDay: 'Afternoon', scheduledTime: const TimeOfDay(hour: 15, minute: 0),
        date: _dateOf(0),
      ),
      VitaminDose(
        name: 'Probiotic', dosage: 0.5, unit: 'g / L water',
        timeOfDay: 'Evening', scheduledTime: const TimeOfDay(hour: 18, minute: 0),
        date: _dateOf(0),
      ),
      // Tomorrow.
      VitaminDose(
        name: 'Electrolyte + Vitamin C', dosage: 2, unit: 'g / L water',
        timeOfDay: 'Morning', scheduledTime: const TimeOfDay(hour: 9, minute: 0),
        date: _dateOf(1),
      ),
    ];

    return BatchNutritionState(
      batchId: 'BATCH-2026-04',
      currentDay: 18,
      programLength: 45,
      phases: phases,
      doses: doses,
    );
  }

  // ── Mutations (worker-editable dosing) ────────────────────────────────

  void markGiven(VitaminDose dose) {
    if (dose.status == DoseStatus.given) return;
    dose.status = DoseStatus.given;
    dose.dateGiven = DateTime.now();
    notifyListeners();
  }

  void markScheduled(VitaminDose dose) {
    if (dose.status == DoseStatus.given) {
      dose.status = dose.effectiveStatus == DoseStatus.due
          ? DoseStatus.due
          : DoseStatus.scheduled;
      dose.dateGiven = null;
      notifyListeners();
    }
  }
}
