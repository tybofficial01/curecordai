import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class ProgressStepBar extends StatelessWidget {
  const ProgressStepBar({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isActive = index < currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < totalSteps - 1 ? 6 : 0),
            height: 6,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.progressActive
                  : AppColors.progressInactive,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
