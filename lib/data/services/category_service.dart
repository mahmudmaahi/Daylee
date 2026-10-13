import 'dart:convert';

import 'package:flutter/material.dart';

import 'storage_service.dart';

/// Single source of truth for transaction categories (used by the finance
/// screens and by settings).
class CategoryService {
  CategoryService._();

  static const String _customKey = 'money_custom_categories_v1';

  static const List<String> defaultExpense = [
    'food',
    'transport',
    'bills',
    'shopping',
    'entertainment',
    'health',
    'education',
    'other',
  ];

  static const List<String> incomeCategories = [
    'allowance',
    'gift',
    'salary',
    'refund',
    'other',
  ];

  static bool isDefault(String category) => defaultExpense.contains(category);

  static String normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Default + custom expense categories, "food" first and "other" last.
  static List<String> expenseCategories() {
    final set = <String>{...defaultExpense};
    final raw = StorageService.getString(_customKey);
    if (raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            final n = normalize(item.toString());
            if (n.isNotEmpty) set.add(n);
          }
        }
      } catch (_) {
        // Malformed payload: fall back to defaults.
      }
    }
    final list = set.toList()..sort(_compare);
    return list;
  }

  static int _compare(String a, String b) {
    if (a == 'food') return -1;
    if (b == 'food') return 1;
    if (a == 'other') return 1;
    if (b == 'other') return -1;
    return a.compareTo(b);
  }

  /// Returns the normalized name, or null when [input] is empty.
  static Future<String?> addCustom(String input) async {
    final n = normalize(input);
    if (n.isEmpty) return null;
    final all = expenseCategories();
    if (all.contains(n)) return n;
    await _persist([...all, n]);
    return n;
  }

  static Future<bool> removeCustom(String category) async {
    final n = normalize(category);
    if (n.isEmpty || isDefault(n)) return false;
    final all = expenseCategories()..remove(n);
    await _persist(all);
    return true;
  }

  static Future<void> _persist(List<String> all) {
    final custom = all.where((c) => !isDefault(c)).toList(growable: false);
    return StorageService.setString(_customKey, jsonEncode(custom));
  }

  static String label(String value) {
    if (value.isEmpty) return value;
    return value
        .split(' ')
        .map(
          (w) => w.isEmpty
              ? w
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  static IconData icon(String category) {
    switch (category) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'transport':
        return Icons.directions_bus_rounded;
      case 'bills':
        return Icons.receipt_long_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'health':
        return Icons.favorite_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'allowance':
        return Icons.volunteer_activism_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'salary':
        return Icons.payments_rounded;
      case 'refund':
        return Icons.undo_rounded;
      case 'adjustment':
        return Icons.tune_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  static const List<Color> _palette = [
    Color(0xFF8B5CF6),
    Color(0xFF38BDF8),
    Color(0xFFF59E0B),
    Color(0xFF22C55E),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFEF4444),
    Color(0xFF94A3B8),
  ];

  static Color color(String category) {
    const known = ['food', 'transport', 'bills', 'shopping', 'entertainment', 'health', 'education'];
    final i = known.indexOf(category);
    if (i >= 0) return _palette[i];
    if (category == 'other') return _palette[7];
    return _palette[(category.hashCode.abs() % 7)];
  }
}
