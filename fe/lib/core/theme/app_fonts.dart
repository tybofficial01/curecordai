import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central font resolver for every text style in the app.
///
/// Every call site that used to reach for `GoogleFonts.manrope`/
/// `GoogleFonts.manropeTextTheme` directly now goes through here instead, so
/// flipping [setLanguage] retargets the whole app onto Noto Nastaliq Urdu -
/// the correct Nastaliq calligraphic style for Urdu script - without having
/// to touch every screen. Roman Urdu (`roman_ur`) is Urdu transliterated
/// into the Latin script, so it keeps reading with Manrope like English does.
class AppFonts {
  AppFonts._();

  static bool _isUrdu = false;

  /// Called once per rebuild from `app.dart` alongside `AppTheme.setDark`,
  /// whenever the persisted `language` preference ('en' | 'ur' | 'roman_ur')
  /// changes.
  static void setLanguage(String language) => _isUrdu = language == 'ur';

  /// Whether text is currently rendered in Noto Nastaliq Urdu. Call sites
  /// that size fixed-padding chrome (e.g. chip padding) around text need
  /// this because Nastaliq's ascent/descent - and its stacked diacritics'
  /// actual ink - run well past what Manrope needs at the same font size,
  /// so layouts tuned for Manrope clip or visually overflow it.
  static bool get isUrdu => _isUrdu;

  /// Noto Nastaliq Urdu stacks diagonally - its loops and tails swing well
  /// above and below the baseline, and that reach grows faster than
  /// font-size does, so a single flat line-height multiplier that looks
  /// fine on body copy still collides on headline-sized text (mirrors the
  /// `html[data-locale="ur"] h1..h6` tier in web/app/globals.css, which
  /// hits the same problem for the same reason). `height` here is Flutter's
  /// line-height multiplier (relative to font size, so it already scales
  /// automatically within a band) - this just picks a bigger band as
  /// fontSize grows.
  static double _urduLineHeight(double? fontSize) {
    final size = fontSize ?? 14;
    if (size >= 24) return 2.6;
    if (size >= 18) return 2.3;
    return 2.0;
  }

  static TextStyle manrope({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    final builder =
        _isUrdu ? GoogleFonts.notoNastaliqUrdu : GoogleFonts.manrope;
    // Only fill in a default when the caller didn't already pick a height -
    // callers that explicitly size their own line spacing (rare) keep
    // full control.
    final resolvedHeight =
        _isUrdu ? (height ?? _urduLineHeight(fontSize)) : height;
    return builder(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: resolvedHeight,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  static TextTheme textTheme(TextTheme textTheme) {
    if (!_isUrdu) return GoogleFonts.manropeTextTheme(textTheme);

    final base = GoogleFonts.notoNastaliqUrduTextTheme(textTheme);
    TextStyle? withHeight(TextStyle? style) => style == null
        ? null
        : style.copyWith(height: style.height ?? _urduLineHeight(style.fontSize));

    return base.copyWith(
      displayLarge: withHeight(base.displayLarge),
      displayMedium: withHeight(base.displayMedium),
      displaySmall: withHeight(base.displaySmall),
      headlineLarge: withHeight(base.headlineLarge),
      headlineMedium: withHeight(base.headlineMedium),
      headlineSmall: withHeight(base.headlineSmall),
      titleLarge: withHeight(base.titleLarge),
      titleMedium: withHeight(base.titleMedium),
      titleSmall: withHeight(base.titleSmall),
      bodyLarge: withHeight(base.bodyLarge),
      bodyMedium: withHeight(base.bodyMedium),
      bodySmall: withHeight(base.bodySmall),
      labelLarge: withHeight(base.labelLarge),
      labelMedium: withHeight(base.labelMedium),
      labelSmall: withHeight(base.labelSmall),
    );
  }
}
