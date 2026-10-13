import 'package:intl/intl.dart';

/// Date formatting helpers used across the app.
class DateHelper {
  DateHelper._();

  /// e.g. "Saturday, Apr 12"
  static String fullDate(DateTime date) =>
      DateFormat('EEEE, MMM d').format(date);

  /// e.g. "Apr 12, 2026"
  static String shortDate(DateTime date) =>
      DateFormat('MMM d, yyyy').format(date);

  /// e.g. "6:30 PM"
  static String time(DateTime date) => DateFormat('h:mm a').format(date);

  /// e.g. "Today", "Yesterday", or "Apr 10"
  static String relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMM d').format(date);
  }

  /// Returns greeting based on hour
  static String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}
