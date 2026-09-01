import 'package:flutter/material.dart';
import 'package:curecordai/core/theme/app_fonts.dart';

import '../../../core/theme/app_theme.dart';

class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.step, required this.onHelp});
  final int step;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
          child: Row(
            children: [
              Text(
                'Step $step of 3',
                style: AppFonts.manrope(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.help_outline, color: AppTheme.textSecondary),
                onPressed: onHelp,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: step / 3,
              minHeight: 5,
              backgroundColor: AppTheme.cardBorder,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class FormCard extends StatelessWidget {
  const FormCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

class FieldErrorText extends StatelessWidget {
  const FieldErrorText(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        message,
        style: AppFonts.manrope(fontSize: 12, color: AppTheme.error),
      ),
    );
  }
}

class StepBottomBar extends StatelessWidget {
  const StepBottomBar({
    super.key,
    required this.step,
    required this.onNext,
    required this.nextEnabled,
    required this.nextLabel,
    this.onPrevious,
  });
  final int step;
  final VoidCallback onNext;
  final bool nextEnabled;
  final String nextLabel;
  final VoidCallback? onPrevious;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: AppTheme.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (step > 1) ...[
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onPrevious ?? () => Navigator.of(context).pop(),
                  child: Text(
                    'Previous',
                    style: AppFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      nextEnabled ? AppTheme.primary : AppTheme.cardBorder,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: nextEnabled ? onNext : null,
                child: Text(
                  nextLabel,
                  style: AppFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
