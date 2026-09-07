import 'package:flutter/material.dart';
import 'package:curecordai/core/theme/app_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get screenTitle => AppFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 28,
        color: AppColors.primaryTeal,
      );

  static TextStyle get screenTitleDark => AppFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 28,
        color: AppColors.darkText,
      );

  static TextStyle get sectionTitle => AppFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 24,
        color: AppColors.darkText,
      );

  static TextStyle get subtitle => AppFonts.manrope(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: AppColors.secondaryText,
      );

  static TextStyle get buttonText => AppFonts.manrope(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: AppColors.white,
      );

  static TextStyle get buttonTextTeal => AppFonts.manrope(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: AppColors.primaryTeal,
      );

  static TextStyle get inputLabel => AppFonts.manrope(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        color: AppColors.darkText,
      );

  static TextStyle get inputPlaceholder => AppFonts.manrope(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: AppColors.placeholder,
      );

  static TextStyle get inputText => AppFonts.manrope(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: AppColors.darkText,
      );

  static TextStyle get caption => AppFonts.manrope(
        fontWeight: FontWeight.w400,
        fontSize: 12,
        color: AppColors.secondaryText,
      );

  static TextStyle get appNameSplash => AppFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 26,
        color: AppColors.primaryTeal,
      );

  static TextStyle get linkText => AppFonts.manrope(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: AppColors.primaryTeal,
      );

  static TextStyle get bodyText => AppFonts.manrope(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: AppColors.darkText,
      );

  static TextStyle get socialButtonText => AppFonts.manrope(
        fontWeight: FontWeight.w500,
        fontSize: 15,
        color: AppColors.darkText,
      );
}
