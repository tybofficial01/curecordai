import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared empty state treatment used across fe/ - a bordered surface card with
/// a circular tinted icon badge, a single description line, and a real pill
/// shaped action button, rather than plain centered text and an icon.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.tintBg,
    required this.tintColor,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color tintBg;
  final Color tintColor;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: tintBg, shape: BoxShape.circle),
            child: Icon(icon, color: tintColor, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
