import 'package:flutter/material.dart';
import 'package:curecordai/core/theme/app_fonts.dart';
import '../constants/app_colors.dart';

/// App-wide color tokens. These are runtime-switchable (not `const`) so the whole app can
/// re-theme instantly when the user flips the Settings dark-mode toggle - see [setDark] and
/// `app.dart`, which calls it every time `themeModeProvider` changes and remounts the tree via
/// a `ValueKey` so every screen re-reads these getters with the new palette.
class AppTheme {
  AppTheme._();

  static bool _isDark = false;

  /// Called once per rebuild from `app.dart` whenever the theme preference changes.
  static void setDark(bool value) => _isDark = value;

  // ── Light palette (existing design) ────────────────────────────────────────
  static const Color _lightPrimary = Color(0xFF0F9B8E);
  static const Color _lightPrimaryDark = Color(0xFF0A7A6E);
  static const Color _lightBackground = Color(0xFFF0FAF9);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceVariant = Color(0xFFE0F5F3);
  static const Color _lightCard = Color(0xFFFFFFFF);
  static const Color _lightCardBorder = Color(0xFFE5E7EB);
  static const Color _lightTextPrimary = Color(0xFF1A1A2E);
  static const Color _lightTextSecondary = Color(0xFF6B7280);
  static const Color _lightTextMuted = Color(0xFF9CA3AF);
  static const Color _lightError = Color(0xFFEF4444);
  static const Color _lightWarning = Color(0xFFF59E0B);
  static const Color _lightWarningBg = Color(0xFFFFF8E6);
  static const Color _lightWarningDark = Color(0xFF8A6100);
  static const Color _lightSuccess = Color(0xFF10B981);
  static const Color _lightInfo = Color(0xFF3B82F6);
  static const Color _lightInputBorder = Color(0xFFE5E7EB);
  static const Color _lightSelectedBorder = Color(0xFF0F9B8E);

  // ── Dark palette ─────────────────────────────────────────────────────────
  // Kept in sync with the marketing site's dark palette
  // (web/app/globals.css `:root`) so web and mobile read as one product.
  static const Color _darkPrimary = Color(0xFF2DBFAF);
  static const Color _darkPrimaryDark = Color(0xFF0F9B8E);
  static const Color _darkPrimaryLight = Color(0xFF6FD9CC);
  static const Color _darkBackground = Color(0xFF0D1413);
  static const Color _darkSurface = Color(0xFF0D1413);
  static const Color _darkSurfaceVariant = Color(0xFF1C2826); // Elevated
  static const Color _darkCard = Color(0xFF16201F);
  static const Color _darkCardBorder = Color(0xFF2A3735); // Default Border
  static const Color _darkTextPrimary = Color(0xFFF2F7F6);
  static const Color _darkTextSecondary = Color(0xFFA8B5B2);
  static const Color _darkTextMuted = Color(0xFF6F7C79); // Icon
  static const Color _darkError = Color(0xFFF87171);
  static const Color _darkWarning = Color(0xFFFBBF24);
  static const Color _darkWarningBg = Color(0xFF332912);
  static const Color _darkWarningDark = Color(0xFFFBBF24);
  static const Color _darkSuccess = Color(0xFF34D399);
  static const Color _darkInfo = Color(0xFF60A5FA);
  static const Color _darkInputBorder = Color(0xFF2A3735);
  static const Color _darkSelectedBorder =
      Color(0x8017E390); // Selected Border, alpha 0x80
  static const Color _darkAccentOrange = Color(0xFFC88A3A);

  // ── Public tokens - every one referenced anywhere in fe/lib/features ───────
  static Color get primary => _isDark ? _darkPrimary : _lightPrimary;
  static Color get primaryDark =>
      _isDark ? _darkPrimaryDark : _lightPrimaryDark;
  static Color get background => _isDark ? _darkBackground : _lightBackground;
  static Color get surface => _isDark ? _darkSurface : _lightSurface;
  static Color get surfaceVariant =>
      _isDark ? _darkSurfaceVariant : _lightSurfaceVariant;
  static Color get card => _isDark ? _darkCard : _lightCard;
  static Color get cardBorder => _isDark ? _darkCardBorder : _lightCardBorder;
  static Color get textPrimary =>
      _isDark ? _darkTextPrimary : _lightTextPrimary;
  static Color get textSecondary =>
      _isDark ? _darkTextSecondary : _lightTextSecondary;
  static Color get textMuted => _isDark ? _darkTextMuted : _lightTextMuted;
  static Color get error => _isDark ? _darkError : _lightError;
  static Color get warning => _isDark ? _darkWarning : _lightWarning;
  static Color get warningBg => _isDark ? _darkWarningBg : _lightWarningBg;
  static Color get warningDark => _isDark ? _darkWarningDark : _lightWarningDark;
  static Color get success => _isDark ? _darkSuccess : _lightSuccess;
  static Color get info => _isDark ? _darkInfo : _lightInfo;

  // Not yet wired onto any existing call site - available for InputDecorationTheme / any
  // future "selected" affordance that wants the palette's dedicated tones.
  static Color get inputBorder =>
      _isDark ? _darkInputBorder : _lightInputBorder;
  static Color get selectedBorder =>
      _isDark ? _darkSelectedBorder : _lightSelectedBorder;
  static Color get accentOrange => _isDark ? _darkAccentOrange : _lightPrimary;

  /// Resolves an asset path to its dark-mode variant (under `assets/images/dark/`) when dark
  /// mode is active and a variant exists there, else the original light-mode path.
  static String imagePath(String fileName) =>
      _isDark ? 'assets/images/dark/$fileName' : 'assets/images/$fileName';

  static ThemeData get lightTheme => _buildTheme(
        brightness: Brightness.light,
        primary: _lightPrimary,
        background: _lightBackground,
        surface: _lightSurface,
        textPrimary: _lightTextPrimary,
        inputBorder: _lightInputBorder,
        error: _lightError,
      );

  static ThemeData get darkTheme => _buildTheme(
        brightness: Brightness.dark,
        primary: _darkPrimary,
        background: _darkBackground,
        surface: _darkSurface,
        textPrimary: _darkTextPrimary,
        inputBorder: _darkInputBorder,
        error: _darkError,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color background,
    required Color surface,
    required Color textPrimary,
    required Color inputBorder,
    required Color error,
  }) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: isDark ? Colors.black : AppColors.white,
        secondary: isDark ? _darkSurfaceVariant : AppColors.primaryTealLight,
        onSecondary: primary,
        surface: surface,
        onSurface: textPrimary,
        error: error,
        onError: AppColors.white,
      ),
      scaffoldBackgroundColor: background,
      textTheme: AppFonts.textTheme(
        TextTheme(
          headlineLarge: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary),
          headlineMedium: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
          headlineSmall: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
          titleLarge: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
          bodyLarge: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary),
          bodyMedium: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary),
          bodySmall: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w400, color: textPrimary),
          labelLarge: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _darkSurfaceVariant : AppColors.inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: error, width: 1.5),
        ),
        hintStyle: AppFonts.manrope(
          fontSize: 14,
          color: isDark ? _darkTextMuted : AppColors.placeholder,
        ),
        errorStyle: AppFonts.manrope(fontSize: 12, color: error),
        constraints: const BoxConstraints(minHeight: 56),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? Colors.black : AppColors.white,
          minimumSize: const Size(double.infinity, 56),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle:
              AppFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor:
              isDark ? _darkSurfaceVariant : AppColors.primaryTealLight,
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, 56),
          side: BorderSide(color: primary, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle:
              AppFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? _darkSurfaceVariant : AppColors.darkText,
        contentTextStyle: AppFonts.manrope(
          color: isDark ? _darkTextPrimary : AppColors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
      ),
    );
  }
}
