import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_appearance.dart';
import '../../data/services/storage_service.dart';
import 'app_logo.dart';

class AppGlobalHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppGlobalHeader({super.key, this.showBottomDivider = false});

  final bool showBottomDivider;

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: AppSpacing.lg,
      title: const AppLogo(size: 30),
      actions: [
        IconButton(
          tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
          onPressed: () => _toggleTheme(isDark),
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
      bottom: showBottomDivider
          ? PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outline.withValues(alpha: 0.25),
              ),
            )
          : null,
    );
  }

  Future<void> _toggleTheme(bool currentlyDark) async {
    final nextPreference = currentlyDark
        ? AppThemePreference.light
        : AppThemePreference.dark;

    await StorageService.setString(
      AppAppearance.themeModeKey,
      AppAppearance.encodeThemePreference(nextPreference),
    );
    await StorageService.setDarkMode(nextPreference == AppThemePreference.dark);

    AppAppearance.notifyAppearanceChanged();
    Get.forceAppUpdate();
  }
}
