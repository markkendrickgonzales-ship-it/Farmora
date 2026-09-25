import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BottomNavItem {
  final String id;
  final String label;
  final IconData icon;
  final List<String>? group;

  BottomNavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.group,
  });
}

class BottomNav extends StatelessWidget {
  final String screen;
  final ValueChanged<String> go;

  const BottomNav({
    super.key,
    required this.screen,
    required this.go,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      BottomNavItem(id: 'home', label: 'Home', icon: Icons.home_outlined),
      BottomNavItem(
        id: 'monitoringHub',
        label: 'Monitoring',
        icon: Icons.graphic_eq_outlined,
        group: [
          'monitoringHub',
          'resourceMonitoring',
          'envMonitoring',
          'historyLog'
        ],
      ),
      BottomNavItem(
          id: 'farmLogs', label: 'Farm Logs', icon: Icons.list_alt_outlined),
      BottomNavItem(
          id: 'reportCreate',
          label: 'Reports',
          icon: Icons.assignment_outlined),
      BottomNavItem(
          id: 'profile', label: 'Profile', icon: Icons.person_outline),
    ];

    return Container(
      decoration: BoxDecoration(
        color: FarmoraColors.surface,
        border: Border(top: BorderSide(color: FarmoraColors.line)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: items.map((it) {
          final active =
              it.group != null ? it.group!.contains(screen) : screen == it.id;
          return Expanded(
            child: InkWell(
              onTap: () => go(it.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      it.icon,
                      size: 20,
                      color:
                          active ? FarmoraColors.brand : FarmoraColors.inkFaint,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      it.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.bold : FontWeight.w500,
                        color: active
                            ? FarmoraColors.brand
                            : FarmoraColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
