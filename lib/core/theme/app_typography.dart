import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

TextTheme buildAppTextTheme({required bool isDark}) {
  final primaryText = isDark
      ? AppColors.darkTextPrimary
      : AppColors.lightTextPrimary;
  final secondaryText = isDark
      ? AppColors.darkTextSecondary
      : AppColors.lightTextSecondary;

  final base = GoogleFonts.interTextTheme(
    TextTheme(
      headlineLarge: const TextStyle(
        fontSize: 34,
        height: 1.2,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: const TextStyle(
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: const TextStyle(
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: const TextStyle(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: const TextStyle(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: const TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  return base.copyWith(
    headlineLarge: GoogleFonts.plusJakartaSans(
      fontSize: 34,
      height: 1.2,
      fontWeight: FontWeight.w800,
      color: primaryText,
    ),
    headlineMedium: GoogleFonts.plusJakartaSans(
      fontSize: 28,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: primaryText,
    ),
    headlineSmall: GoogleFonts.plusJakartaSans(
      fontSize: 24,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: primaryText,
    ),
    titleLarge: GoogleFonts.plusJakartaSans(
      fontSize: 20,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: primaryText,
    ),
    titleMedium: GoogleFonts.plusJakartaSans(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: primaryText,
    ),
    titleSmall: GoogleFonts.plusJakartaSans(
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: primaryText,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: primaryText,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: primaryText,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: secondaryText,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: primaryText,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: secondaryText,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w500,
      color: secondaryText,
    ),
  );
}
