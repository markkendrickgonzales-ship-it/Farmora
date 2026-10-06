import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/screen_header.dart';
import '../services/nutrition_service.dart';

class NutritionFeedProgramScreen extends StatefulWidget {
  final ValueChanged<String> go;

  const NutritionFeedProgramScreen({super.key, required this.go});

  @override
  State<NutritionFeedProgramScreen> createState() =>
      _NutritionFeedProgramScreenState();
}

class _NutritionFeedProgramScreenState
    extends State<NutritionFeedProgramScreen> {
  @override
  void initState() {
    super.initState();
    NutritionService.instance.addListener(_onChange);
    NutritionService.instance.ensureLoaded();
  }

  @override
  void dispose() {
    NutritionService.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final svc = NutritionService.instance;
    final state = svc.state;

    return Column(
      children: [
        ScreenHeader(
          title: 'Feed program',
          subtitle: state?.phaseLabel ??
              (svc.loading ? 'Loading feed program…' : 'No feed program yet'),
          onBack: () => widget.go('nutrition'),
        ),
        Expanded(
          child: _buildBody(svc, state),
        ),
      ],
    );
  }

  Widget _buildBody(NutritionService svc, BatchNutritionState? state) {
    if (state == null) {
      if (svc.loading) {
        return Center(
          child: CircularProgressIndicator(color: FarmoraColors.brand),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            svc.error ?? 'No feed program is available for this batch yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: FarmoraColors.inkSoft),
          ),
        ),
      );
    }

    final current = state.currentPhase;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('Current phase — guaranteed analysis'),
        const SizedBox(height: 10),
        _analysisCard(current),
        const SizedBox(height: 22),
        _sectionLabel('All phases'),
        const SizedBox(height: 10),
        for (final p in state.phases) ...[
          _phaseRow(p, current.name == p.name, state.currentDay),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        _sectionLabel('Intake & FCR — last 7 days'),
        const SizedBox(height: 10),
        _historyCard(svc.history),
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
      [
        'Metabolizable energy',
        '${p.metabolizableEnergy.toStringAsFixed(0)} kcal/kg'
      ],
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
                    style:
                        TextStyle(fontSize: 12.5, color: FarmoraColors.inkSoft),
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

  Widget _phaseRow(FeedPhase p, bool isCurrent, int currentDay) {
    final String level;
    final String tag;
    if (p.isPast(currentDay)) {
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

  Widget _historyCard(List<NutritionReading> history) {
    if (history.isEmpty) {
      return FarmoraCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.timeline_outlined, size: 18, color: FarmoraColors.brand),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No intake readings logged in the last 7 days.',
                style: TextStyle(fontSize: 12.5, color: FarmoraColors.inkSoft),
              ),
            ),
          ],
        ),
      );
    }

    return FarmoraCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (int i = 0; i < history.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: FarmoraColors.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      _dayLabel(history[i].date),
                      style: TextStyle(
                          fontSize: 11.5, color: FarmoraColors.inkSoft),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${history[i].intakeG.toStringAsFixed(0)} g/bird',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FarmoraColors.ink,
                      ),
                    ),
                  ),
                  Text(
                    history[i].fcr != null
                        ? 'FCR ${history[i].fcr!.toStringAsFixed(2)}'
                        : 'FCR —',
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

  String _dayLabel(DateTime d) {
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return wd[(d.weekday - 1) % 7];
  }
}
