import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/screen_header.dart';

class NotificationsScreen extends StatefulWidget {
  final ValueChanged<String> go;

  const NotificationsScreen({super.key, required this.go});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _read = false;
  String _filter = 'All logs';
  final _filters = const ['All logs', 'Urgent alerts', 'Latest updates'];

  final _allItems = const [
    {
      'level': 'crit',
      'cat': 'RESOURCES',
      'time': '10:45 AM',
      'title': 'Water level critical',
      'body': 'Zone B main reservoir dropped below 15%',
    },
    {
      'level': 'warn',
      'cat': 'CLIMATE',
      'time': '09:12 AM',
      'title': 'High humidity warning',
      'body': 'Greenhouse 03 humidity rising',
    },
    {
      'level': 'info',
      'cat': 'SYSTEM GENERAL',
      'time': 'Yesterday',
      'title': 'System maintenance complete',
      'body': 'Firmware update applied',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final items = _allItems.where((it) {
      if (_filter == 'Urgent alerts') return it['level'] == 'crit' || it['level'] == 'warn';
      if (_filter == 'Latest updates') return it['level'] == 'info';
      return true;
    }).toList();

    Color getBarColor(String level) {
      switch (level) {
        case 'crit':
          return FarmoraColors.crit;
        case 'warn':
          return FarmoraColors.warn;
        case 'info':
        default:
          return FarmoraColors.inkFaint;
      }
    }

    return Column(
      children: [
        ScreenHeader(
          title: _read ? 'Activity' : 'Activity (2 new)',
          onBack: () => widget.go('home'),
          right: GestureDetector(
            onTap: () => setState(() => _read = true),
            child: const Text(
              'Mark all read',
              style: TextStyle(
                fontSize: 11.5,
                color: FarmoraColors.brand,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: _filters.map((f) {
              final active = _filter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: active,
                  onSelected: (_) => setState(() => _filter = f),
                  selectedColor: FarmoraColors.brandSoft,
                  backgroundColor: FarmoraColors.surface,
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: active ? FarmoraColors.brand : FarmoraColors.inkSoft,
                  ),
                  side: BorderSide(
                    color: active ? FarmoraColors.brand : FarmoraColors.line,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: FarmoraColors.line),
            itemBuilder: (context, index) {
              final it = items[index];
              final barColor = getBarColor(it['level']!);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 3,
                      height: 48,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${it["level"] != "info" ? "${it["level"]!.toUpperCase()} · " : ""}${it["cat"]} · ${it["time"]}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: barColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            it['title']!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: FarmoraColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            it['body']!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: FarmoraColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
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
