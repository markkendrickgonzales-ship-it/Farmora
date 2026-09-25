import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/screen_header.dart';
import '../widgets/status_badge.dart';
import '../widgets/primary_button.dart';

/// Full-screen detail view for one row of `farming_advisories`.
/// Pushed on top of the advisory list via [SlideFadeRoute] and wrapped in a
/// [PopScope] so the system back gesture also re-syncs the shell's state.
class AdvisoryDetailScreen extends StatelessWidget {
  final Map<String, dynamic> advisory;
  final VoidCallback onBack;

  const AdvisoryDetailScreen({
    super.key,
    required this.advisory,
    required this.onBack,
  });

  // ── Flexible schema helpers (column names may vary) ──────────────────
  static String titleOf(Map<String, dynamic> a) =>
      (a['title'] ?? a['name'] ?? 'Untitled advisory').toString();

  static String categoryOf(Map<String, dynamic> a) =>
      (a['category'] ?? a['type'] ?? a['topic'] ?? 'General').toString();

  static String situationOf(Map<String, dynamic> a) =>
      (a['situation'] ?? a['description'] ?? a['summary'] ?? '').toString();

  /// Returns the external resource URL, or null when the advisory has no
  /// usable `resource_link` (also tolerates `link` / `url` / `resource_url`
  /// column names).
  static String? resourceLinkOf(Map<String, dynamic> a) {
    final raw =
        a['resource_link'] ?? a['link'] ?? a['url'] ?? a['resource_url'];
    if (raw == null) return null;
    var link = raw.toString().trim();
    if (link.isEmpty) return null;
    // Normalize bare "www.example.com" values so launching works.
    if (!link.startsWith(RegExp(r'^https?://', caseSensitive: false))) {
      link = 'https://$link';
    }
    return Uri.tryParse(link)?.hasAbsolutePath ?? false ? link : null;
  }

  /// Opens [link] in the device browser; surfaces a snackbar on failure.
  static Future<void> _launchLink(BuildContext context, String link) async {
    final uri = Uri.parse(link);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $link')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }

  /// Pulls the step-by-step instructions from whichever column holds them:
  /// a JSON/list `steps` array first, then long-text fallbacks split into
  /// numbered steps by line breaks.
  static List<String> stepsOf(Map<String, dynamic> a) {
    final raw = a['steps'] ?? a['instructions'] ?? a['step_by_step'];
    if (raw == null) return const [];

    // Steps stored as a JSON string or native list of strings.
    List? list;
    if (raw is List) {
      list = raw;
    } else if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return const [];
      try {
        final decoded = jsonDecode(text);
        list = decoded is List ? decoded : null;
        if (list == null) {
          // JSON string without newlines: treat as a single step.
          return [text];
        }
      } catch (_) {
        // Not JSON: split plain text into steps on newlines.
        return text
            .split(RegExp(r'\n+'))
            .map((s) => s.replaceFirst(RegExp(r'^\s*\d+[.)\-:]\s*'), '').trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }
    return (list ?? const [])
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final situation = situationOf(advisory);
    final steps = stepsOf(advisory);
    final resourceLink = resourceLinkOf(advisory);

    return PopScope(
      // The detail screen is always pushed as a route, so system back just
      // pops it; onBack re-syncs the shell state when the pop is blocked.
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack();
      },
      child: Scaffold(
        backgroundColor: FarmoraColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              ScreenHeader(
                title: 'Advisory guide',
                onBack: onBack,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      titleOf(advisory),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: FarmoraColors.ink,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        StatusBadge(
                          level: 'info',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.label_outline, size: 10),
                              const SizedBox(width: 4),
                              Text(categoryOf(advisory).toUpperCase()),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (situation.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FarmoraColors.warnSoft,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                              color: FarmoraColors.warn.withOpacity(0.25)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                size: 15, color: FarmoraColors.warn),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                situation,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: FarmoraColors.ink,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Text(
                      'STEP-BY-STEP INSTRUCTIONS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: FarmoraColors.inkFaint,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (steps.isEmpty)
                      const Text(
                        'No detailed instructions are available for this advisory yet.',
                        style: TextStyle(
                            fontSize: 13, color: FarmoraColors.inkSoft),
                      )
                    else
                      ...List.generate(steps.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: FarmoraColors.brandSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: FarmoraColors.brand,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: FarmoraColors.surface,
                                    borderRadius: BorderRadius.circular(9),
                                    border:
                                        Border.all(color: FarmoraColors.line),
                                  ),
                                  child: Text(
                                    steps[i],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: FarmoraColors.ink,
                                      height: 1.55,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    // External guide / video link from the `resource_link`
                    // column, when present.
                    if (resourceLink != null) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'RESOURCE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: FarmoraColors.inkFaint,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _launchLink(context, resourceLink),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FarmoraColors.brand,
                            side: const BorderSide(color: FarmoraColors.brand),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text(
                            'Open resource guide / video',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // The raw URL as a clickable text link too.
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: GestureDetector(
                          onTap: () => _launchLink(context, resourceLink),
                          child: Text(
                            resourceLink,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: FarmoraColors.info,
                              decoration: TextDecoration.underline,
                              decorationColor: FarmoraColors.info,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    PrimaryButton(
                      text: 'Back to guides',
                      onClick: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.pop(context);
                        } else {
                          onBack();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
