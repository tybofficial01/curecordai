import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';

enum SocialButtonType { google, apple }

class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.type,
    required this.onPressed,
  });

  final SocialButtonType type;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.darkText,
          side: const BorderSide(color: AppColors.inputBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (type == SocialButtonType.google)
              _GoogleLogo()
            else
              _AppleLogo(),
            const SizedBox(width: 8),
            Text(
              type == SocialButtonType.google ? 'Google' : 'Apple',
              style: AppTextStyles.socialButtonText,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}

class _AppleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.apple,
      size: 20,
      color: AppColors.darkText,
    );
  }
}
