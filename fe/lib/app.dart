import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_fonts.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/offline_banner.dart';
import 'features/profile/providers/profile_providers.dart';
import 'l10n/generated/app_localizations.dart';

class CurecordAiApp extends ConsumerWidget {
  const CurecordAiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final language = ref.watch(preferencesProvider).language;

    // AppTheme.x are read directly (not via Theme.of(context)) throughout the app, so flipping
    // MaterialApp's themeMode alone wouldn't change anything visually. Setting the flag here and
    // keying the whole tree on themeMode forces every screen to remount and re-read the palette.
    AppTheme.setDark(themeMode == ThemeMode.dark);
    // Same story for fonts: AppFonts.manrope/textTheme are read directly by every screen
    // instead of through Theme.of(context), so the whole app is switched onto Noto Nastaliq
    // Urdu here whenever the persisted language is Urdu script (not Roman Urdu, which is
    // Latin-script and stays on Manrope).
    AppFonts.setLanguage(language);

    return MaterialApp.router(
      key: ValueKey('$themeMode-$language'),
      title: 'CurecordAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      // Drives only the framework's own locale-aware bits (RTL direction for
      // Urdu, Material/Cupertino widget strings like date-picker labels).
      // Our own screen strings are resolved separately by
      // `appLocalizationsProvider`, which is keyed off the raw `language`
      // string ('en'|'ur'|'roman_ur') and not this Locale - Roman Urdu has
      // no real Locale of its own and intentionally reuses 'en' here so it
      // renders LTR.
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ur'),
      ],
      routerConfig: router,
      builder: (context, child) =>
          OfflineBannerScope(child: child ?? const SizedBox.shrink()),
    );
  }
}
