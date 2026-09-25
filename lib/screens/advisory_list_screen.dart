import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/screen_header.dart';
import '../widgets/farmora_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/primary_button.dart';
import '../services/farm_service.dart';
import '../utils/app_route.dart';
import 'advisory_detail_screen.dart';

/// Lists every guide stored in the `farming_advisories` Supabase table.
/// Tapping a card pushes [AdvisoryDetailScreen] with the 300ms slide route.
class AdvisoryListScreen extends StatefulWidget {
  final ValueChanged<String> go;

  const AdvisoryListScreen({super.key, required this.go});

  @override
  State<AdvisoryListScreen> createState() => _AdvisoryListScreenState();
}

class _AdvisoryListScreenState extends State<AdvisoryListScreen> {
  List<Map<String, dynamic>> _advisories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await FarmService.fetchAdvisories();
      if (!mounted) return;
      setState(() {
        _advisories = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load advisories: $e';
        _loading = false;
      });
    }
  }

  void _openDetail(Map<String, dynamic> advisory) {
    Navigator.of(context).push(
      SlideFadeRoute(
        AdvisoryDetailScreen(
          advisory: advisory,
          // Route system back through the shell so its state stays in sync.
          onBack: () {
            if (Navigator.of(context).canPop()) {
              Navigator.pop(context);
            } else {
              widget.go('home');
            }
          },
        ),
      ),
    );
  }

  // ── Flexible schema helpers (column names may vary) ──────────────────
  static String titleOf(Map<String, dynamic> a) =>
      (a['title'] ?? a['name'] ?? 'Untitled advisory').toString();
  static String categoryOf(Map<String, dynamic> a) =>
      (a['category'] ?? a['type'] ?? a['topic'] ?? 'General').toString();
  static String situationOf(Map<String, dynamic> a) =>
      (a['situation'] ?? a['description'] ?? a['summary'] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScreenHeader(
          title: 'Advisory & Guides',
          subtitle: 'Best-practice playbooks from the field',
          onBack: () {
            if (Navigator.of(context).canPop()) {
              Navigator.pop(context);
            } else {
              widget.go('home');
            }
          },
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_outlined,
                                size: 34, color: FarmoraColors.inkFaint),
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: FarmoraColors.crit, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: 160,
                              child: PrimaryButton(
                                text: 'Retry',
                                onClick: _load,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _advisories.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No advisories published yet.\nAdd rows to the farming_advisories table.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: FarmoraColors.inkFaint, fontSize: 13),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _advisories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final a = _advisories[i];
                              final situation = situationOf(a);
                              return FarmoraCard(
                                onTap: () => _openDetail(a),
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            titleOf(a),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              color: FarmoraColors.ink,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.chevron_right,
                                            size: 16,
                                            color: FarmoraColors.inkFaint),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        StatusBadge(
                                          level: 'info',
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.label_outline,
                                                  size: 10),
                                              const SizedBox(width: 4),
                                              Text(
                                                  categoryOf(a).toUpperCase()),
                                            ],
                                          ),
                                        ),
                                        // Hint that an external guide/video
                                        // link is included.
                                        if (AdvisoryDetailScreen.resourceLinkOf(
                                                a) !=
                                            null) ...[
                                          const SizedBox(width: 8),
                                          const StatusBadge(
                                            level: 'good',
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.link, size: 10),
                                                SizedBox(width: 4),
                                                Text('LINK'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (situation.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        situation,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: FarmoraColors.inkSoft,
                                          height: 1.45,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}
