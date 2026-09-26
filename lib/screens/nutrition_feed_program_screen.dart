import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/screen_header.dart';
import '../services/nutrition_service.dart';

/// Full-screen detail reached from "Feed program", "Guaranteed analysis" and
/// "Nutrition history". Shows the current phase's guaranteed analysis, all
/// three phases (past ones marked completed) and a 7-day intake / FCR strip.
class NutritionFeedProgramScreen extends StatelessWidget {
  final ValueChanged<String> go;

  const NutritionFeedProgramScreen({super.key, required this.go});

  @override
  Widget build(BuildContext context) {
    final state = NutritionService.instance.state;
    final current = state.currentPhase;

    // Representative last-7-day intake & FCR readings (in per bird per day, FCR).
    const intake = [118.0, 124.5, 121.0, 130.2, 133.8, 129.4, 136.1];
    const fcr = [1.62, 1.65, 1.63, 1.68, 1.70, 1.69, 1.71];

    return Column(
      children: [
        ScreenHeader(
          title: 'Feed program',
          subtitle: state.phaseLabel,
          onBack: () => go('nutrition'),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionLabel('Current phase — guaranteed analysis'),
              const SizedBox(height: 10),
              _analysisCard(current),
              const SizedBox(height: 22),
              _sectionLabel('All phases'),
              const SizedBox(height: 10),
              for (final p in state.phases) ...[
                _phaseRow(p, current.name == p.name),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 12),
              _sectionLabel('Intake & FCR — last 7 days'),
              const SizedBox(height: 10),
              _historyCard(intake, fcr),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
          color: FarmoraColors.ink,
        ),
      );

  Widget _analysisCard(FeedPhase p) {
    final rows = <List<String>>[
      ['Crude protein', '${p.crudeProtein.toStringAsFixed(1)} %'],
      ['Crude fat', '${p.crudeFat.toStringAsFixed(1)} %'],
      ['Crude fiber', '${p.crudeFiber.toStringAsFixed(1)} %'],
      ['Calcium', '${p.calcium.toStringAsFixed(2)} %'],
      ['Phosphorus', '${p.phosphorus.toStringAsFixed(2)} %'],
      ['Lysine', '${p.lysine.toStringAsFixed(2)} %'],
      ['Methionine', '${p.methionine.toStringAsFixed(2)} %'],
      ['Metabolizable energy', '${p.metabolizableEnergy.toStringAsFixed(0)} kcal/kg'],
    ];

    return FarmoraCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: FarmoraColors.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    rows[i][0],
                    style: TextStyle(
                        fontSize: 12.5, color: FarmoraColors.inkSoft),
                  ),
                  Text(
                    rows[i][1],
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: FarmoraColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _phaseRow(FeedPhase p, bool isCurrent) {
    final String level;
    final String tag;
    if (p.isPast) {
      level = 'info';
      tag = 'Completed';
    } else if (isCurrent) {
      level = 'good';
      tag = 'Active';
    } else {
      level = 'warn';
      tag = 'Upcoming';
    }

    return FarmoraCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FarmoraColors.brandSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.grain_outlined,
                size: 19, color: FarmoraColors.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p.name} phase',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: FarmoraColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Day ${p.startDay}–${p.endDay} · CP ${p.crudeProtein.toStringAsFixed(1)}%',
                  style:
                      TextStyle(fontSize: 11.5, color: FarmoraColors.inkSoft),
                ),
              ],
            ),
          ),
          StatusBadge(level: level, child: Text(tag)),
        ],
      ),
    );
  }

  Widget _historyCard(List<double> intake, List<double> fcr) {
    final now = DateTime.now();
    return FarmoraCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (int i = 0; i < intake.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: FarmoraColors.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      _dayLabel(now, i, intake.length),
                      style: TextStyle(
                          fontSize: 11.5, color: FarmoraColors.inkSoft),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${intake[i].toStringAsFixed(0)} g/bird',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FarmoraColors.ink,
                      ),
                    ),
                  ),
                  Text(
                    'FCR ${fcr[i].toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FarmoraColors.brand,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _dayLabel(DateTime now, int i, int len) {
    final offset = -(len - 1 - i);
    final d = now.add(Duration(days: offset));
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return wd[(d.weekday - 1) % 7];
  }
}
