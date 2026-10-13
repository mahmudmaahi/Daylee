import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/router/app_router.dart';
import '../../features/dashboard/bindings/dashboard_binding.dart';
import '../../features/dashboard/controllers/dashboard_controller.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/money_management/bindings/money_binding.dart';
import '../../features/money_management/controllers/money_controller.dart';
import '../../features/money_management/screens/money_screen.dart';
import '../../features/prayer_reminder/bindings/prayer_binding.dart';
import '../../features/prayer_reminder/controllers/prayer_controller.dart';
import '../../features/prayer_reminder/screens/prayer_screen.dart';
import '../../features/profile/bindings/profile_binding.dart';
import '../../features/profile/controllers/profile_controller.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/tasks/screens/tasks_coming_soon_screen.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const List<String> _routes = [
    AppRoutes.dashboard,
    AppRoutes.tasks,
    AppRoutes.money,
    AppRoutes.prayer,
    AppRoutes.profile,
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        if (index == currentIndex) return;
        final transition = index > currentIndex
            ? Transition.rightToLeft
            : Transition.leftToRight;

        _ensureBindings(index);

        Get.off(
          () => _pageForIndex(index),
          routeName: _routes[index],
          transition: transition,
          duration: const Duration(milliseconds: 250),
        );
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.checklist_rtl_outlined),
          selectedIcon: Icon(Icons.checklist_rtl_rounded),
          label: 'Tasks',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet_rounded),
          label: 'Finance',
        ),
        NavigationDestination(
          icon: Icon(Icons.mosque_outlined),
          selectedIcon: Icon(Icons.mosque_rounded),
          label: 'Prayers',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    );
  }

  void _ensureBindings(int index) {
    if (index == 0 && !Get.isRegistered<DashboardController>()) {
      DashboardBinding().dependencies();
      return;
    }

    if (index == 2 && !Get.isRegistered<MoneyController>()) {
      MoneyBinding().dependencies();
      return;
    }

    if (index == 3 && !Get.isRegistered<PrayerController>()) {
      PrayerBinding().dependencies();
      return;
    }

    if (index == 4) {
      if (!Get.isRegistered<ProfileController>()) {
        ProfileBinding().dependencies();
      }
      if (!Get.isRegistered<MoneyController>()) {
        MoneyBinding().dependencies();
      }
    }
  }

  Widget _pageForIndex(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const TasksComingSoonScreen();
      case 2:
        return const MoneyScreen(initialPageIndex: 0, currentNavIndex: 2);
      case 3:
        return const PrayerScreen();
      default:
        return const ProfileScreen();
    }
  }
}
