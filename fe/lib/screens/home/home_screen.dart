import 'package:flutter/material.dart';
import 'package:curecordai/core/theme/app_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/secondary_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final displayName = user?.fullName ?? auth.fullName ?? 'User';
    final displaySub = user?.email ?? user?.phoneNumber ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'CurecordAI',
          style: AppFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryTeal,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 80,
                height: 80,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primaryTealLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.health_and_safety_outlined,
                      color: AppColors.primaryTeal, size: 40),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome, $displayName!',
                style: AppFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
                textAlign: TextAlign.center,
              ),
              if (displaySub.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(displaySub, style: AppTextStyles.subtitle),
              ],
              const SizedBox(height: 16),
              Text(
                'Your health dashboard is coming soon.',
                style: AppTextStyles.subtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SecondaryButton(
                label: 'Logout',
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/welcome-back', (route) => false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
