import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class IllustrationHeader extends StatelessWidget {
  const IllustrationHeader({
    super.key,
    required this.imagePath,
    this.height = 250,
  });

  final String imagePath;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      color: AppColors.background,
      alignment: Alignment.center,
      child: Image.asset(
        imagePath,
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}
