import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final storageService = StorageService();

    final hasToken = await storageService.hasToken();
    if (!mounted) return;

    if (hasToken) {
      final isValid = await authProvider.checkAuthStatus();
      if (!mounted) return;
      if (isValid) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/welcome-back');
      }
      return;
    }

    final hasSeenCarousel = await storageService.hasSeenCarousel();
    if (!mounted) return;
    if (hasSeenCarousel) {
      Navigator.pushReplacementNamed(context, '/welcome-back');
    } else {
      Navigator.pushReplacementNamed(context, '/carousel');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFC8EFEC)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                AppStrings.logoAsset,
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 16),
              Text(AppStrings.appName, style: AppTextStyles.appNameSplash),
              const SizedBox(height: 8),
              Text(AppStrings.tagline, style: AppTextStyles.subtitle),
            ],
          ),
        ),
      ),
    );
  }
}
