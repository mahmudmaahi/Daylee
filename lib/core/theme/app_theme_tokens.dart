import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.backgroundPrimary,
    required this.surface,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.error,
    required this.primaryGradient,
    required this.cardGradient,
    required this.secondaryButtonSurface,
    required this.secondaryButtonBorder,
  });

  final Color backgroundPrimary;
  final Color surface;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color error;
  final LinearGradient primaryGradient;
  final LinearGradient cardGradient;
  final Color secondaryButtonSurface;
  final Color secondaryButtonBorder;

  static const AppThemeTokens dark = AppThemeTokens(
    backgroundPrimary: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    card: AppColors.darkCard,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    success: AppColors.success,
    error: AppColors.error,
    primaryGradient: AppColors.primaryGradient,
    cardGradient: AppColors.cardGradientDark,
    secondaryButtonSurface: AppColors.darkSurface,
    secondaryButtonBorder: AppColors.darkBorder,
  );

  static const AppThemeTokens light = AppThemeTokens(
    backgroundPrimary: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    card: AppColors.lightCard,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    success: AppColors.success,
    error: AppColors.error,
    primaryGradient: AppColors.primaryGradient,
    cardGradient: AppColors.cardGradientLight,
    secondaryButtonSurface: AppColors.lightSurface,
    secondaryButtonBorder: AppColors.lightBorder,
  );

  @override
  AppThemeTokens copyWith({
    Color? backgroundPrimary,
    Color? surface,
    Color? card,
    Color? textPrimary,
    Color? textSecondary,
    Color? success,
    Color? error,
    LinearGradient? primaryGradient,
    LinearGradient? cardGradient,
    Color? secondaryButtonSurface,
    Color? secondaryButtonBorder,
  }) {
    return AppThemeTokens(
      backgroundPrimary: backgroundPrimary ?? this.backgroundPrimary,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      success: success ?? this.success,
      error: error ?? this.error,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      cardGradient: cardGradient ?? this.cardGradient,
      secondaryButtonSurface:
          secondaryButtonSurface ?? this.secondaryButtonSurface,
      secondaryButtonBorder:
          secondaryButtonBorder ?? this.secondaryButtonBorder,
    );
  }

  @override
  AppThemeTokens lerp(
    covariant ThemeExtension<AppThemeTokens>? other,
    double t,
  ) {
    if (other is! AppThemeTokens) return this;

    return AppThemeTokens(
      backgroundPrimary:
          Color.lerp(backgroundPrimary, other.backgroundPrimary, t) ??
          backgroundPrimary,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      card: Color.lerp(card, other.card, t) ?? card,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      success: Color.lerp(success, other.success, t) ?? success,
      error: Color.lerp(error, other.error, t) ?? error,
      primaryGradient:
          LinearGradient.lerp(primaryGradient, other.primaryGradient, t) ??
          primaryGradient,
      cardGradient:
          LinearGradient.lerp(cardGradient, other.cardGradient, t) ??
          cardGradient,
      secondaryButtonSurface:
          Color.lerp(secondaryButtonSurface, other.secondaryButtonSurface, t) ??
          secondaryButtonSurface,
      secondaryButtonBorder:
          Color.lerp(secondaryButtonBorder, other.secondaryButtonBorder, t) ??
          secondaryButtonBorder,
    );
  }
}

extension AppThemeTokensX on BuildContext {
  AppThemeTokens get tokens {
    final ext = Theme.of(this).extension<AppThemeTokens>();
    return ext ?? AppThemeTokens.dark;
  }
}
