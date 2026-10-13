import 'dart:ui';

import 'package:flutter/material.dart';

import '../../data/services/storage_service.dart';
import '../constants/app_colors.dart';
import 'app_theme_tokens.dart';
import 'app_theme.dart';
import 'dark_theme.dart';

enum AppThemePreference { system, light, dark }

enum UiDensityPreference { comfortable, compact }

class AppAppearance {
  AppAppearance._();

  static final ValueNotifier<int> _appearanceVersion = ValueNotifier<int>(0);

  static const String themeModeKey = 'theme_mode';
  static const String accentColorKey = 'accent_color';
  static const String fontScaleKey = 'font_scale';
  static const String uiDensityKey = 'ui_density';

  static ValueNotifier<int> get appearanceListenable => _appearanceVersion;

  static void notifyAppearanceChanged() {
    _appearanceVersion.value++;
  }

  static const List<Color> accentPresets = <Color>[
    AppColors.primary,
    Color(0xFF1D9BF0),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFE11D48),
  ];

  static AppThemePreference parseThemePreference(String raw) {
    switch (raw) {
      case 'light':
        return AppThemePreference.light;
      case 'dark':
        return AppThemePreference.dark;
      default:
        return AppThemePreference.system;
    }
  }

  static String encodeThemePreference(AppThemePreference value) {
    switch (value) {
      case AppThemePreference.light:
        return 'light';
      case AppThemePreference.dark:
        return 'dark';
      case AppThemePreference.system:
        return 'system';
    }
  }

  static ThemeMode toThemeMode(AppThemePreference value) {
    switch (value) {
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference.system:
        return ThemeMode.system;
    }
  }

  static UiDensityPreference parseUiDensity(String raw) {
    if (raw == 'compact') return UiDensityPreference.compact;
    return UiDensityPreference.comfortable;
  }

  static String encodeUiDensity(UiDensityPreference value) {
    return value == UiDensityPreference.compact ? 'compact' : 'comfortable';
  }

  static ThemeData buildTheme({
    required bool isDark,
    required Color accent,
    required double fontScale,
    required UiDensityPreference density,
  }) {
    final base = isDark ? darkTheme : lightTheme;
    final tokens = isDark ? AppThemeTokens.dark : AppThemeTokens.light;
    final brightness = isDark ? Brightness.dark : Brightness.light;

    // Material's tonal palette washes the accent out (a vivid purple becomes
    // a dusty one), so use the accent itself as the primary colour and keep
    // the generated palette only for the secondary roles.
    final vivid = isDark
        ? Color.lerp(accent, Colors.white, 0.18)!
        : accent;
    final onVivid = ThemeData.estimateBrightnessForColor(vivid) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1A1A2E);
    final seededScheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
          surface: base.colorScheme.surface,
          onSurface: base.colorScheme.onSurface,
        ).copyWith(
          primary: vivid,
          onPrimary: onVivid,
          primaryContainer: Color.lerp(
            vivid,
            isDark ? AppColors.darkSurface : Colors.white,
            0.78,
          ),
          onPrimaryContainer: isDark ? Colors.white : vivid,
          surfaceTint: Colors.transparent,
        );

    final textTheme = _scaleTextTheme(base.textTheme, fontScale);
    final visualDensity = density == UiDensityPreference.compact
        ? const VisualDensity(horizontal: -1, vertical: -1)
        : VisualDensity.standard;

    final navIconTheme = WidgetStateProperty.resolveWith<IconThemeData>((
      states,
    ) {
      final selected = states.contains(WidgetState.selected);
      final color = selected
          ? seededScheme.primary.withValues(alpha: 0.92)
          : (isDark ? AppColors.darkTextHint : AppColors.lightTextHint);
      return IconThemeData(color: color);
    });

    final navLabelTheme = WidgetStateProperty.resolveWith<TextStyle>((states) {
      final selected = states.contains(WidgetState.selected);
      return (textTheme.labelSmall ?? const TextStyle(fontSize: 12)).copyWith(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected
            ? seededScheme.primary.withValues(alpha: 0.9)
            : (isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
      );
    });

    return base.copyWith(
      colorScheme: seededScheme,
      textTheme: textTheme,
      extensions: [tokens],
      visualDensity: visualDensity,
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
          color: seededScheme.onSurface,
        ),
        iconTheme: IconThemeData(color: seededScheme.onSurface),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: seededScheme.primary,
        foregroundColor: seededScheme.onPrimary,
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        indicatorColor: seededScheme.primary.withValues(alpha: 0.12),
        iconTheme: navIconTheme,
        labelTextStyle: navLabelTheme,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: seededScheme.primary,
        thumbColor: seededScheme.primary,
      ),
      switchTheme: base.switchTheme.copyWith(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return seededScheme.onPrimary;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return seededScheme.primary;
          }
          return null;
        }),
      ),
    );
  }

  static bool systemIsDark() {
    return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  }

  static TextTheme _scaleTextTheme(TextTheme input, double factor) {
    if ((factor - 1.0).abs() < 0.0001) {
      return input;
    }

    return TextTheme(
      displayLarge: _scaleStyle(input.displayLarge, factor, 57),
      displayMedium: _scaleStyle(input.displayMedium, factor, 45),
      displaySmall: _scaleStyle(input.displaySmall, factor, 36),
      headlineLarge: _scaleStyle(input.headlineLarge, factor, 32),
      headlineMedium: _scaleStyle(input.headlineMedium, factor, 28),
      headlineSmall: _scaleStyle(input.headlineSmall, factor, 24),
      titleLarge: _scaleStyle(input.titleLarge, factor, 20),
      titleMedium: _scaleStyle(input.titleMedium, factor, 16),
      titleSmall: _scaleStyle(input.titleSmall, factor, 14),
      bodyLarge: _scaleStyle(input.bodyLarge, factor, 16),
      bodyMedium: _scaleStyle(input.bodyMedium, factor, 14),
      bodySmall: _scaleStyle(input.bodySmall, factor, 12),
      labelLarge: _scaleStyle(input.labelLarge, factor, 14),
      labelMedium: _scaleStyle(input.labelMedium, factor, 12),
      labelSmall: _scaleStyle(input.labelSmall, factor, 11),
    );
  }

  static TextStyle _scaleStyle(
    TextStyle? style,
    double factor,
    double fallback,
  ) {
    if (style == null) {
      return TextStyle(fontSize: fallback * factor);
    }

    final baseSize = style.fontSize ?? fallback;
    return style.copyWith(fontSize: baseSize * factor);
  }
}

extension AppGradientX on BuildContext {
  /// Brand gradient that follows the user's chosen accent colour.
  LinearGradient get heroGradient {
    final stored = StorageService.getInt(
      AppAppearance.accentColorKey,
      fallback: AppColors.primary.toARGB32(),
    );
    if (stored == AppColors.primary.toARGB32()) {
      return AppColors.balanceRefinedGradient;
    }
    final accent = Color(stored);
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [accent, Color.lerp(accent, AppColors.accentPink, 0.6)!],
    );
  }
}
