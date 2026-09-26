import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/screen_header.dart';
import '../services/nutrition_service.dart';
import '../services/vitamin_service.dart';

/// Nutrition landing screen, nested under Monitoring
/// (breadcrumb: Monitoring › Nutrition).
///
/// Lists four rows in the same style as the Monitoring hub, then a "Today's
/// log" preview. It listens to [VitaminService] so the Vitamins pill and the
/// preview update live as doses are logged.
class NutritionScreen extends StatefulWidget {
  final ValueChanged<String> go;

  const NutritionScreen({super.key, required this.go});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  @override
  void initState() {
    super.initState();
    NutritionService.instance.addListener(_onChange);
    VitaminService.instance.addListener(_onChange);
    VitaminService.instance.ensureLoaded();
  }

  @override
  void dispose() {
    NutritionService.instance.removeListener(_onChange);
    VitaminService.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final svc = NutritionService.instance;
    final state = svc.state;
    final vit = VitaminService.instance;
    final logged = vit.loggedTodayCount;

    return Column(
      children: [
        ScreenHeader(
          title: 'Nutrition',
          subtitle: 'Feed program and vitamin schedule',
          onBack: () => widget.go('monitoringHub'),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _navRow(
                icon: Icons.restaurant_outlined,
                title: 'Feed program',
                desc: state.phaseLabel,
                level: 'good',
                tag: 'On track',
                onTap: () => widget.go('nutritionFeedProgram'),
              ),
              const SizedBox(height: 10),
              _navRow(
                icon: Icons.medication_liquid_outlined,
                title: 'Vitamins & additives',
                desc: 'Log daily doses given through water',
                level: logged > 0 ? 'good' : 'warn',
                tag: logged > 0 ? '$logged logged today' : 'None logged today',
                onTap: () => widget.go('nutritionVitamins'),
              ),
              const SizedBox(height: 10),
              _navRow(
                icon: Icons.science_outlined,
                title: 'Guaranteed analysis',
                desc: 'Current feed composition',
                onTap: () => widget.go('nutritionFeedProgram'),
              ),
              const SizedBox(height: 10),
              _navRow(
                icon: Icons.timeline_outlined,
                title: 'Nutrition history',
                desc: 'Intake & FCR, last 7 days',
                level: 'info',
                tag: 'Archive',
                onTap: () => widget.go('nutritionFeedProgram'),
              ),
              const SizedBox(height: 22),
              Text(
                "Today's log",
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: FarmoraColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              _todayLogCard(vit.todayLogs),
            ],
          ),
        ),
      ],
    );
  }

  Widget _navRow({
    required IconData icon,
    required String title,
    required String desc,
    String? level,
    String? tag,
    required VoidCallback onTap,
  }) {
    return FarmoraCard(
      onTap: onTap,
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
            child: Icon(icon, size: 19, color: FarmoraColors.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: FarmoraColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(fontSize: 11.5, color: FarmoraColors.inkSoft),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (level != null && tag != null) ...[
                StatusBadge(level: level, child: Text(tag)),
                const SizedBox(height: 6),
              ],
              Icon(Icons.chevron_right, size: 15, color: FarmoraColors.inkFaint),
            ],
          ),
        ],
      ),
    );
  }

  Widget _todayLogCard(List<VitaminLogEntry> logs) {
    if (logs.isEmpty) {
      return FarmoraCard(
        onTap: () => widget.go('nutritionVitamins'),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline,
                size: 18, color: FarmoraColors.brand),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No vitamins logged yet today — tap to add one',
                style: TextStyle(fontSize: 12.5, color: FarmoraColors.inkSoft),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 15, color: FarmoraColors.inkFaint),
          ],
        ),
      );
    }

    return FarmoraCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (int i = 0; i < logs.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: FarmoraColors.line),
            _logPreviewRow(logs[i]),
          ],
        ],
      ),
    );
  }

  Widget _logPreviewRow(VitaminLogEntry e) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration:
                BoxDecoration(color: FarmoraColors.good, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FarmoraColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  e.dosageLabel,
                  style:
                      TextStyle(fontSize: 11.5, color: FarmoraColors.inkSoft),
                ),
              ],
            ),
          ),
          Text(
            e.timeLabel,
            style: TextStyle(fontSize: 11.5, color: FarmoraColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
