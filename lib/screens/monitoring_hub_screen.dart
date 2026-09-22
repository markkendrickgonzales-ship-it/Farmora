import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/screen_header.dart';

class MonitoringHubScreen extends StatelessWidget {
  final ValueChanged<String> go;

  const MonitoringHubScreen({super.key, required this.go});

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'id': 'resourceMonitoring',
        'title': 'Resources monitoring',
        'desc': 'Feed silo & water tank levels',
        'icon': Icons.warehouse_outlined,
        'level': 'crit',
        'tag': '1 critical',
      },
      {
        'id': 'envMonitoring',
        'title': 'Environmental monitoring',
        'desc': 'Temperature, humidity, airflow',
        'icon': Icons.air_outlined,
        'level': 'warn',
        'tag': '1 warning',
      },
      {
        'id': 'historyLog',
        'title': 'Monitoring history',
        'desc': 'Last 7 days of sensor activity',
        'icon': Icons.show_chart_outlined,
        'level': 'info',
        'tag': 'Archive',
      },
    ];

    return Column(
      children: [
        const ScreenHeader(title: 'Monitoring', subtitle: 'Choose a feed to inspect'),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final it = items[index];
              return FarmoraCard(
                onTap: () => go(it['id'] as String),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: FarmoraColors.brandSoft,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(it['icon'] as IconData, size: 18, color: FarmoraColors.brand),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it['title'] as String,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: FarmoraColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            it['desc'] as String,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: FarmoraColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusBadge(
                          level: it['level'] as String,
                          child: Text(it['tag'] as String),
                        ),
                        const SizedBox(height: 6),
                        const Icon(Icons.chevron_right, size: 15, color: FarmoraColors.inkFaint),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
