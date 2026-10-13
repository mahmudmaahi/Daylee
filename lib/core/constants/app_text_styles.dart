import 'package:flutter/material.dart';

/// Typography scale for Daylee.
/// - Headings: Plus Jakarta Sans (geometric, modern)
/// - Body / UI: Inter (highly readable at small sizes)
class AppTextStyles {
  AppTextStyles._();

  // ── Display / Hero ─────────────────────────────────────────
  static TextStyle displayLarge(BuildContext context) =>
      Theme.of(context).textTheme.headlineLarge ??
      const TextStyle(fontSize: 34, fontWeight: FontWeight.w800);

  static TextStyle displayMedium(BuildContext context) =>
      Theme.of(context).textTheme.headlineMedium ??
      const TextStyle(fontSize: 28, fontWeight: FontWeight.w700);

  // ── Headings ───────────────────────────────────────────────
  static TextStyle h1(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge ??
      const TextStyle(fontSize: 20, fontWeight: FontWeight.w700);

  static TextStyle h2(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium ??
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  static TextStyle h3(BuildContext context) =>
      Theme.of(context).textTheme.titleSmall ??
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

  // ── Body ───────────────────────────────────────────────────
  static TextStyle bodyLarge(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge ??
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w400);

  static TextStyle bodyMedium(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium ??
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w400);

  static TextStyle bodySmall(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall ??
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w400);

  // ── Labels / Captions ─────────────────────────────────────
  static TextStyle label(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium ??
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

  static TextStyle caption(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall ??
      const TextStyle(fontSize: 11, fontWeight: FontWeight.w500);

  // ── Button Text ────────────────────────────────────────────
  static TextStyle button(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge ??
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w700);

  // ── Amount / Numbers (for Money Management) ────────────────
  static TextStyle amount(BuildContext context) =>
      Theme.of(context).textTheme.headlineLarge ??
      const TextStyle(fontSize: 34, fontWeight: FontWeight.w800);
}
