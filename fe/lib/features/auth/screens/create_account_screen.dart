import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations_provider.dart';
import '../../../core/theme/app_theme.dart';

class CreateAccountScreen extends ConsumerWidget {
  const CreateAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLocalizationsProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                child: IconButton(
                  icon: Icon(Icons.help_outline, color: AppTheme.textSecondary),
                  onPressed: () {},
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      AppTheme.imagePath('signup_options.png'),
                      height: 260,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => SizedBox(
                        height: 260,
                        child: Icon(Icons.image_outlined,
                            color: AppTheme.textMuted, size: 48),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      t.authCreateAccountTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.authCreateAccountSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton(
                      onPressed: () => context.push('/auth/phone-signup'),
                      child: Text(t.authContinueWithPhone),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context.push('/auth/email-signup'),
                      child: Text(t.authContinueWithEmail),
                    ),
                    const SizedBox(height: 24),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                        children: [
                          TextSpan(text: t.authAlreadyHaveAccount),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () => context.go('/auth/login'),
                              child: Text(
                                t.authLogIn,
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
