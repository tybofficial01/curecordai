import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One explainer card in an [showInfoExplainerDialog] grid - an icon, a short
/// title, and a one or two sentence description.
class InfoExplainerItem {
  const InfoExplainerItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

/// Shared "what is this page about" dialog used across fe/ - a small info
/// icon next to a page heading opens this, showing a 2 column grid of
/// explainer cards and a "Got it" button to dismiss. Mirrors the
/// HowToUseModal/HowItWorksModal pattern on the web dashboard so the three
/// pages that use it (AI Assistant, Family Management, Medications) share one
/// implementation instead of three near identical ones.
Future<void> showInfoExplainerDialog(
  BuildContext context, {
  required String title,
  required List<InfoExplainerItem> items,
  required String gotItLabel,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _InfoExplainerDialog(
      title: title,
      items: items,
      gotItLabel: gotItLabel,
    ),
  );
}

class _InfoExplainerDialog extends StatelessWidget {
  const _InfoExplainerDialog({
    required this.title,
    required this.items,
    required this.gotItLabel,
  });

  final String title;
  final List<InfoExplainerItem> items;
  final String gotItLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close,
                          size: 18, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 12.0;
                      final cardWidth = (constraints.maxWidth - spacing) / 2;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final item in items)
                            SizedBox(
                              width: cardWidth,
                              child: _ExplainerCard(item: item),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                    elevation: 0,
                  ),
                  child: Text(
                    gotItLabel,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExplainerCard extends StatelessWidget {
  const _ExplainerCard({required this.item});

  final InfoExplainerItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 18, color: AppTheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.description,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
