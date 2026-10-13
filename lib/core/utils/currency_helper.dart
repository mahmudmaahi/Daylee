import 'package:intl/intl.dart';
import '../../data/services/storage_service.dart';

/// Currency formatting helpers for Money Management.
class CurrencyHelper {
  CurrencyHelper._();

  static final _formatter = NumberFormat('#,##0.00', 'en_US');
  static final _compact = NumberFormat.compact();

  /// Extracts the symbol from format like 'BDT (৳)' or 'USD ($)'
  static String get symbol {
    final cur = StorageService.getString('currency', fallback: 'BDT (৳)');
    final start = cur.indexOf('(');
    final end = cur.indexOf(')');
    if (start != -1 && end != -1 && end > start) {
      return cur.substring(start + 1, end);
    }
    return '৳';
  }

  /// e.g. "৳ 1,250.00" — changing dynamically based on settings
  static String format(double amount) {
    final v = amount.abs() < 0.005 ? 0.0 : amount;
    return v < 0
        ? '-$symbol ${_formatter.format(-v)}'
        : '$symbol ${_formatter.format(v)}';
  }

  /// Like [format] but drops the decimals for whole numbers ("৳ 1,250").
  static String formatShort(double amount) {
    final whole = (amount - amount.roundToDouble()).abs() < 0.005;
    if (!whole) return format(amount);
    final v = amount.roundToDouble();
    final body = NumberFormat('#,##0', 'en_US').format(v.abs());
    return v < 0 ? '-$symbol $body' : '$symbol $body';
  }

  /// Whole-number amount for derived figures such as "per day".
  static String formatRounded(double amount) {
    final v = amount.roundToDouble();
    final body = NumberFormat('#,##0', 'en_US').format(v.abs());
    return v < 0 ? '-$symbol $body' : '$symbol $body';
  }

  /// e.g. "1.2K", "3.5M" — for charts and summaries
  static String compact(double amount) => _compact.format(amount);

  /// Parses user input such as "1,250.50" or "৳ 90". Returns 0 when invalid.
  static double parse(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return 0;
    var n = raw.replaceAll(RegExp(r"[^0-9,.]"), "");
    if (n.contains(",") && n.contains(".")) {
      n = n.replaceAll(",", "");
    } else if (n.contains(",")) {
      final parts = n.split(",");
      final looksLikeThousands = parts.length > 1 && parts.skip(1).every((p) => p.length == 3);
      n = looksLikeThousands ? n.replaceAll(",", "") : n.replaceAll(",", ".");
    }
    final value2 = double.tryParse(n) ?? 0;
    return value2.isFinite && value2 > 0 ? value2 : 0;
  }

  /// Plain editable text for an amount (no symbol, no trailing .00).
  static String input(double value) {
    if (value == 0) return "";
    final fixed = value.toStringAsFixed(2);
    return fixed.endsWith(".00") ? fixed.substring(0, fixed.length - 3) : fixed;
  }

  /// Returns positive prefix "+" or negative "-"
  static String sign(double amount) => amount >= 0 ? '+' : '';
}
