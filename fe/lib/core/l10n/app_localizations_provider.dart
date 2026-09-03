import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/providers/profile_providers.dart';
import '../../l10n/generated/app_localizations.dart';
// `app_localizations.dart` only imports these per-language files internally -
// it doesn't re-export them - so the concrete classes (`AppLocalizationsEn`,
// `AppLocalizationsUr`) must be imported directly here to be constructible.
// `AppLocalizationsUrLatn` (Roman Urdu) is generated as a subclass of
// `AppLocalizationsUr` inside app_localizations_ur.dart rather than getting
// its own file - `flutter gen-l10n` only emits a standalone file per *base*
// locale (no script/country suffix) - so importing that one file is enough
// to reach both `AppLocalizationsUr` and `AppLocalizationsUrLatn`.
import '../../l10n/generated/app_localizations_en.dart';
import '../../l10n/generated/app_localizations_ur.dart';

/// Resolves which of the three generated string sets (`en` / `ur` /
/// Roman Urdu) to show, keyed off the app's own persisted `language` value
/// (`'en' | 'ur' | 'roman_ur'`) rather than the OS/browser locale.
///
/// Roman Urdu has no real BCP-47 language tag, so it cannot be a distinct
/// `Locale` that `MaterialApp.supportedLocales`/`Localizations.of` would
/// resolve to on its own. It's modelled here as the ARB locale `ur_Latn`
/// ("Urdu written in Latin script" - the standard tag for exactly this),
/// generated as `AppLocalizationsUrLatn`, and selected explicitly by this
/// provider instead of through Flutter's locale-negotiation machinery.
///
/// Use `ref.watch(appLocalizationsProvider)` wherever a screen would
/// otherwise call `AppLocalizations.of(context)!`.
final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  final language = ref.watch(preferencesProvider).language;
  switch (language) {
    case 'ur':
      return AppLocalizationsUr();
    case 'roman_ur':
      return AppLocalizationsUrLatn();
    case 'en':
    default:
      return AppLocalizationsEn();
  }
});

/// Localized 3-letter month abbreviation for `month` (1-12).
///
/// `intl`'s `DateFormat` can't be used for this: Roman Urdu has no ICU locale,
/// so its month names have to come from the ARB files like every other string.
String shortMonthName(AppLocalizations t, int month) {
  switch (month) {
    case 1:
      return t.monthJan;
    case 2:
      return t.monthFeb;
    case 3:
      return t.monthMar;
    case 4:
      return t.monthApr;
    case 5:
      return t.monthMay;
    case 6:
      return t.monthJun;
    case 7:
      return t.monthJul;
    case 8:
      return t.monthAug;
    case 9:
      return t.monthSep;
    case 10:
      return t.monthOct;
    case 11:
      return t.monthNov;
    default:
      return t.monthDec;
  }
}
