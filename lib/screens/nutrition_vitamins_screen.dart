import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/screen_header.dart';
import '../services/nutrition_service.dart';

/// Full dosing schedule / history for vitamins & additives. Farm workers can
/// mark a dose as given (or undo it); [NutritionService] notifies listeners so
/// the "due today" pill on the Nutrition hub updates live.
class NutritionVitaminsScreen extends StatefulWidget {
  final ValueChanged<String> go;

  const NutritionVitaminsScreen({super.key, required this.go});

  @override
  State<NutritionVitaminsScreen> createState() =>
      _NutritionVitaminsScreenState();
}

class _NutritionVitaminsScreenState extends State<NutritionVitaminsScreen> {
  @override
  void initState() {
    super.initState();
    NutritionService.instance.addListener(_onChange);
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
    final doses = svc.state.doses;

    // Group doses by date, most recent first.
    final byDate = <DateTime, List<VitaminDose>>{};
    for (final d in doses) {
      byDate.putIfAbsent(d.date, () => []).add(d);
    }
    final dates = byDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final due = svc.state.dueTodayCount;

    return Column(
      children: [
        ScreenHeader(
          title: 'Vitamins & additives',
          subtitle: 'Given through drinking water',
          onBack: () => widget.go('nutrition'),
          right: StatusBadge(
            level: due > 0 ? 'warn' : 'good',
            child: Text(due > 0 ? '$due due today' : 'All given'),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final date in dates) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Text(
                    _dateLabel(date),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: FarmoraColors.inkSoft,
                    ),
                  ),
                ),
                FarmoraCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(
                    children: [
                      for (int i = 0; i < byDate[date]!.length; i++) ...[
                        if (i > 0)
                          Divider(
                              height: 1, thickness: 1, color: FarmoraColors.line),
                        _editableDoseRow(byDate[date]![i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _editableDoseRow(VitaminDose dose) {
    final status = dose.effectiveStatus;
    final given = status == DoseStatus.given;

    final Color dotColor;
    final Color statusColor;
    final String statusText;
    switch (status) {
      case DoseStatus.given:
        dotColor = FarmoraColors.good;
        statusColor = FarmoraColors.inkSoft;
        statusText = 'Given';
        break;
      case DoseStatus.due:
        dotColor = FarmoraColors.warn;
        statusColor = FarmoraColors.warn;
        statusText = 'Due ${dose.timeLabel}';
        break;
      default:
        dotColor = FarmoraColors.inkFaint;
        statusColor = FarmoraColors.inkSoft;
        statusText = 'Scheduled';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FarmoraColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dose.dosageLine,
                  style:
                      TextStyle(fontSize: 11.5, color: FarmoraColors.inkSoft),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: status == DoseStatus.due
                      ? FontWeight.bold
                      : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => given
                    ? NutritionService.instance.markScheduled(dose)
                    : NutritionService.instance.markGiven(dose),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: given ? FarmoraColors.line : FarmoraColors.brand,
                    ),
                    color: given
                        ? FarmoraColors.surface
                        : FarmoraColors.brandSoft,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        given ? Icons.undo : Icons.check,
                        size: 14,
                        color: given
                            ? FarmoraColors.inkSoft
                            : FarmoraColors.brand,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        given ? 'Undo' : 'Mark given',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: given
                              ? FarmoraColors.inkSoft
                              : FarmoraColors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}
