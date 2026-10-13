import 'package:get/get.dart';
import '../../common/widgets/exit_confirmation_wrapper.dart';
import '../../features/dashboard/bindings/dashboard_binding.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/tasks/screens/tasks_coming_soon_screen.dart';
import '../../features/money_management/bindings/money_binding.dart';
import '../../features/money_management/screens/money_screen.dart';
import '../../features/money_management/screens/add_transaction_screen.dart';
import '../../features/prayer_reminder/bindings/prayer_binding.dart';
import '../../features/prayer_reminder/screens/prayer_screen.dart';
import '../../features/profile/bindings/profile_binding.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/security/screens/app_lock_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/security/screens/security_settings_screen.dart';

/// Named route constants
class AppRoutes {
  AppRoutes._();
  static const String splash = '/splash';
  static const String dashboard = '/';
  static const String lock = '/lock';
  static const String tasks = '/tasks';
  static const String money = '/finance';
  static const String transfer = '/finance/transfers';
  static const String wallets = '/finance/wallets';
  static const String savings = '/finance/savings';
  static const String addTransaction = '/money/add';
  static const String budget = '/money/budget';
  static const String prayer = '/prayer';
  static const String profile = '/profile';
  static const String securitySettings = '/profile/security';
}

/// GetX page route definitions with lazy-loaded bindings.
final List<GetPage> appPages = [
  GetPage(
    name: AppRoutes.splash,
    page: () => const SplashScreen(),
    transition: Transition.fadeIn,
    transitionDuration: const Duration(milliseconds: 250),
  ),
  GetPage(
    name: AppRoutes.lock,
    page: () => const ExitConfirmationWrapper(child: AppLockScreen()),
    transition: Transition.fadeIn,
    transitionDuration: const Duration(milliseconds: 180),
  ),
  GetPage(
    name: AppRoutes.dashboard,
    page: () => const ExitConfirmationWrapper(child: DashboardScreen()),
    binding: DashboardBinding(),
    transition: Transition.fadeIn,
    transitionDuration: const Duration(milliseconds: 200),
  ),
  GetPage(
    name: AppRoutes.tasks,
    page: () => const ExitConfirmationWrapper(child: TasksComingSoonScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 250),
  ),
  GetPage(
    name: AppRoutes.money,
    page: () => const ExitConfirmationWrapper(
      child: MoneyScreen(initialPageIndex: 0, currentNavIndex: 2),
    ),
    binding: MoneyBinding(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 250),
  ),
  GetPage(
    name: AppRoutes.transfer,
    page: () => const ExitConfirmationWrapper(
      child: MoneyScreen(initialPageIndex: 2, currentNavIndex: 2),
    ),
    binding: MoneyBinding(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 250),
  ),
  GetPage(
    name: AppRoutes.wallets,
    page: () => const ExitConfirmationWrapper(
      child: MoneyScreen(initialPageIndex: 1, currentNavIndex: 2),
    ),
    binding: MoneyBinding(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 250),
  ),
  GetPage(
    name: AppRoutes.savings,
    page: () => const ExitConfirmationWrapper(
      child: MoneyScreen(initialPageIndex: 3, currentNavIndex: 2),
    ),
    binding: MoneyBinding(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 250),
  ),
  GetPage(
    name: AppRoutes.addTransaction,
    page: () => const AddTransactionScreen(),
    binding: MoneyBinding(),
    transition: Transition.downToUp,
    transitionDuration: const Duration(milliseconds: 250),
    fullscreenDialog: true,
  ),
  GetPage(
    name: AppRoutes.prayer,
    page: () => const ExitConfirmationWrapper(child: PrayerScreen()),
    binding: PrayerBinding(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 250),
  ),
  GetPage(
    name: AppRoutes.profile,
    page: () => const ExitConfirmationWrapper(child: ProfileScreen()),
    bindings: [ProfileBinding(), MoneyBinding(), PrayerBinding()],
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 250),
  ),
  GetPage(
    name: AppRoutes.securitySettings,
    page: () => const SecuritySettingsScreen(),
    binding: ProfileBinding(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 220),
  ),
];
