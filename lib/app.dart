import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/bootstrap.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/security/app_lock_policy.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_appearance.dart';
import 'bindings/app_binding.dart';
import 'data/services/storage_service.dart';

class DayleeApp extends StatefulWidget {
  const DayleeApp({super.key});

  @override
  State<DayleeApp> createState() => _DayleeAppState();
}

class _DayleeAppState extends State<DayleeApp> with WidgetsBindingObserver {
  bool _didLeaveForeground = false;
  bool _isLockVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Keep scheduled prayer/finance reminders rolling forward and pick up
      // permission changes made in system settings.
      AppBootstrap.resync();
    }

    final onLockScreen = Get.currentRoute == AppRoutes.lock;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _didLeaveForeground = !onLockScreen;
      _rememberLastRoute();
      StorageService.setInt(
        AppLockPolicy.lastActiveAtMsKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      return;
    }

    if (state == AppLifecycleState.resumed && _didLeaveForeground) {
      _didLeaveForeground = false;

      if (Get.currentRoute == AppRoutes.lock || _isLockVisible) return;
      if (!StorageService.getBool(AppLockPolicy.enabledKey)) return;

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final lastActiveMs = StorageService.getInt(
        AppLockPolicy.lastActiveAtMsKey,
      );
      final delaySeconds = AppLockPolicy.sanitizeDelay(
        StorageService.getInt(AppLockPolicy.delaySecondsKey, fallback: 60),
      );
      final elapsedMs = nowMs - lastActiveMs;
      final shouldLock = delaySeconds == 0
          ? true
          : elapsedMs >= (delaySeconds * 1000);

      if (!shouldLock) return;

      _isLockVisible = true;
      Future.microtask(() {
        Get.toNamed(AppRoutes.lock, preventDuplicates: false)?.whenComplete(() {
          _isLockVisible = false;
        });
      });
    }
  }

  void _rememberLastRoute() {
    final route = Get.currentRoute;
    if (route.isEmpty ||
        route == AppRoutes.lock ||
        route == AppRoutes.splash) {
      return;
    }
    StorageService.setString(AppLockPolicy.lastRouteKey, route);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppAppearance.appearanceListenable,
      builder: (context, _, _) {
        final accentColor = Color(
          StorageService.getInt(
            AppAppearance.accentColorKey,
            fallback: AppColors.primary.toARGB32(),
          ),
        );
        final fontScale = StorageService.getDouble(
          AppAppearance.fontScaleKey,
          fallback: 1.0,
        ).clamp(0.9, 1.2);
        final density = AppAppearance.parseUiDensity(
          StorageService.getString(
            AppAppearance.uiDensityKey,
            fallback: AppAppearance.encodeUiDensity(
              UiDensityPreference.comfortable,
            ),
          ),
        );
        final themePreference = AppAppearance.parseThemePreference(
          StorageService.getString(
            AppAppearance.themeModeKey,
            fallback: AppAppearance.encodeThemePreference(
              AppThemePreference.system,
            ),
          ),
        );

        return GetMaterialApp(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.noScaling),
              child: child ?? const SizedBox.shrink(),
            );
          },

          // ── Theme ─────────────────────────────────────────────
          theme: AppAppearance.buildTheme(
            isDark: false,
            accent: accentColor,
            fontScale: fontScale,
            density: density,
          ),
          darkTheme: AppAppearance.buildTheme(
            isDark: true,
            accent: accentColor,
            fontScale: fontScale,
            density: density,
          ),
          themeMode: AppAppearance.toThemeMode(themePreference),

          // ── Routing ───────────────────────────────────────────
          // Cold start: splash first, then the lock screen or Home.
          initialRoute: AppRoutes.splash,
          getPages: appPages,
          routingCallback: (routing) {
            final current = routing?.current ?? Get.currentRoute;
            if (current.isEmpty ||
              current == AppRoutes.lock ||
              current == AppRoutes.splash) {
            return;
          }
            StorageService.setString(AppLockPolicy.lastRouteKey, current);
          },

          // ── Global Binding ────────────────────────────────────
          initialBinding: AppBinding(),
        );
      },
    );
  }
}
