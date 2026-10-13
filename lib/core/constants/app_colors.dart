import 'package:flutter/material.dart';

/// Central color palette for Daylee.
/// All colors used across the app must come from here — no hardcoded colors.
class AppColors {
  AppColors._();

  // ── Core Brand / Gradient ──────────────────────────────────
  static const Color primary = Color(0xFF6C2BD9);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color primaryLight = Color(0xFF8B5CF6);
  static const Color primaryDark = Color(0xFF5B21B6);
  static const Color secondary = accentPink;
  static const Color tertiary = Color(0xFF94A3B8);

  // ── Requested Background System ────────────────────────────
  static const Color darkBackground = Color(0xFF0B0F1A);
  static const Color darkSurface = Color(0xFF121826);
  static const Color darkCard = Color(0xFF1A1F2E);

  // ── Light Surface System (for light mode compatibility) ───
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF1F5F9);

  // ── Text System ────────────────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextHint = Color(0xFF64748B);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextHint = Color(0xFF64748B);

  // ── Borders ────────────────────────────────────────────────
  static const Color darkBorder = Color(0xFF273245);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // ── Semantic / Status ──────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF60A5FA);

  // ── Reusable Gradients ─────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, accentPink],
  );

  static const LinearGradient cardGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F2435), Color(0xFF151C2A)],
  );

  static const LinearGradient cardGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8FAFC), Color(0xFFEFF4FF)],
  );

  // ── Premium Balance Gradient ───────────────────────────────
  // Refined, subtle gradient for the primary balance display —
  // maintains brand presence without visual aggression.
  static const LinearGradient balanceRefinedGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF7C3AED), Color(0xFFD946EF)],
  );

  // ── Finance Chart Palette ─────────────────────────────────
  static const Color chartPrimaryPurple = Color(0xFF8B5CF6);
  static const Color chartSoftBlue = Color(0xFF7DA7D9);
  static const Color chartWarmYellow = Color(0xFFD4A860);
  static const Color chartSoftGreen = Color(0xFF6BBF98);

  // ── Compatibility aliases for legacy feature references ───
  static const Color incomeGreen = success;
  static const Color expenseViolet = primary;
  static const Color savingBlue = info;
  static const Color prayerDawnTop = Color(0xFF0B2B45);
  static const Color prayerDawnBottom = Color(0xFF154E6B);
  static const Color prayerNightTop = Color(0xFF0A162D);
  static const Color prayerNightBottom = Color(0xFF0F2A3D);
  static const Color prayerAccent = Color(0xFF42D1A8);
  static const Color prayerGlow = Color(0xFFF3D27B);
  static const Color prayerMoon = Color(0xFFFFF2CC);
}
