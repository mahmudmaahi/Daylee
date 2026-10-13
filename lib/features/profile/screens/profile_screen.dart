import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;

import '../../../common/widgets/app_bottom_nav.dart';
import '../../../common/widgets/app_card.dart';
import '../../../common/widgets/app_global_header.dart';
import '../../../common/widgets/app_logo.dart';
import '../../../core/app_info.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_appearance.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../data/services/location_service.dart';
import '../controllers/profile_controller.dart';

class ProfileScreen extends GetView<ProfileController> {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppGlobalHeader(showBottomDivider: true),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            _ProfileHero(controller: controller),
            const SizedBox(height: AppSpacing.lg),
            _StatsSection(controller: controller),
            const SizedBox(height: AppSpacing.lg),
            _PersonalizationSection(controller: controller),
            const SizedBox(height: AppSpacing.lg),
            _NotificationSection(controller: controller),
            const SizedBox(height: AppSpacing.lg),
            _LocationSection(controller: controller),
            const SizedBox(height: AppSpacing.lg),
            _FinancePreferencesSection(controller: controller),
            const SizedBox(height: AppSpacing.lg),
            _SecuritySection(controller: controller),
            const SizedBox(height: AppSpacing.lg),
            _DataAccountSection(controller: controller),
            const SizedBox(height: AppSpacing.lg),
            const _AboutSection(),
          ],
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageProvider = _imageProviderFromStoredPhoto(
      controller.profilePhotoBase64.value,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.2),
            theme.colorScheme.tertiary.withValues(alpha: 0.16),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: imageProvider,
                child: imageProvider == null
                    ? const AppLogo(size: 62, showName: false)
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.profileDisplayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (controller.displayName.value.trim().isNotEmpty)
                      Text(
                        '@${controller.displayName.value.trim().replaceAll(' ', '_').toLowerCase()}',
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Joined ${controller.joinDateLabel}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (controller.bio.value.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                controller.bio.value.trim(),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: controller.pickProfilePhoto,
                  icon: const Icon(Icons.photo_camera_back_outlined),
                  label: const Text('Photo'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditBottomSheet(context, controller),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit Profile'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ImageProvider<Object>? _imageProviderFromStoredPhoto(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;

    try {
      late Uint8List bytes;

      if (input.startsWith('data:')) {
        final uriData = Uri.parse(input).data;
        if (uriData != null) {
          bytes = uriData.contentAsBytes();
        } else {
          return null;
        }
      } else {
        bytes = base64Decode(input);
      }

      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return MemoryImage(bytes);
      }

      final baked = img.bakeOrientation(decoded);
      final normalizedBytes = Uint8List.fromList(
        img.encodeJpg(baked, quality: 90),
      );
      return MemoryImage(normalizedBytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> _showEditBottomSheet(
    BuildContext context,
    ProfileController controller,
  ) async {
    final firstCtrl = TextEditingController(text: controller.firstName.value);
    final lastCtrl = TextEditingController(text: controller.lastName.value);
    final userCtrl = TextEditingController(text: controller.displayName.value);
    final bioCtrl = TextEditingController(text: controller.bio.value);
    final phoneCtrl = TextEditingController(text: controller.phoneNumber.value);
    final emailCtrl = TextEditingController(text: controller.email.value);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstCtrl,
                  decoration: const InputDecoration(labelText: 'First name'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: lastCtrl,
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username / display name (optional)',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: bioCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Bio / short description',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final email = emailCtrl.text.trim();
                          if (email.isNotEmpty && !GetUtils.isEmail(email)) {
                            Get.snackbar('Profile', 'Invalid email format.');
                            return;
                          }

                          await controller.updateUserInfo(
                            first: firstCtrl.text,
                            last: lastCtrl.text,
                            userName: userCtrl.text,
                            shortBio: bioCtrl.text,
                            phone: phoneCtrl.text,
                            emailAddress: emailCtrl.text,
                          );

                          if (!sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop();
                          Get.snackbar('Profile', 'Profile updated.');
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    firstCtrl.dispose();
    lastCtrl.dispose();
    userCtrl.dispose();
    bioCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.statsReady.value) {
      return _Section(
        title: 'Usage Stats',
        child: const AppCard(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    return _Section(
      title: 'Usage Stats',
      child: AppCard(
        child: Column(
          children: [
            _statRow(
              context,
              icon: Icons.savings_rounded,
              label: 'Total Savings',
              value: CurrencyHelper.format(controller.totalSavings.value),
            ),
            const Divider(height: AppSpacing.lg),
            _statRow(
              context,
              icon: Icons.bar_chart_rounded,
              label: 'Monthly Spending Average',
              value: CurrencyHelper.format(
                controller.monthlySpendingAverage.value,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label)),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _PersonalizationSection extends StatelessWidget {
  const _PersonalizationSection({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Personalization',
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<AppThemePreference>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: AppThemePreference.light,
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: AppThemePreference.dark,
                  label: Text('Dark'),
                ),
                ButtonSegment(
                  value: AppThemePreference.system,
                  label: Text('System'),
                ),
              ],
              selected: {controller.themePreference.value},
              onSelectionChanged: (selection) {
                controller.setThemePreference(selection.first);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Accent Color',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: AppAppearance.accentPresets
                  .map((color) {
                    final selected =
                        controller.accentColorValue.value == color.toARGB32();
                    return GestureDetector(
                      onTap: () => controller.setAccentColor(color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Font size',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text('${(controller.fontScale.value * 100).round()}%'),
              ],
            ),
            Slider(
              value: controller.fontScale.value,
              min: 0.9,
              max: 1.2,
              divisions: 6,
              onChanged: controller.setFontScale,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'UI density',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<UiDensityPreference>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: UiDensityPreference.comfortable,
                  label: Text('Comfortable'),
                ),
                ButtonSegment(
                  value: UiDensityPreference.compact,
                  label: Text('Compact'),
                ),
              ],
              selected: {controller.uiDensityPreference.value},
              onSelectionChanged: (selection) {
                controller.setUiDensity(selection.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationSection extends StatelessWidget {
  const _NotificationSection({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Notifications',
      child: AppCard(
        child: Column(
          children: [
            _switchTile(
              context,
              title: 'Notifications',
              subtitle: 'Prayer, expense and budget reminders',
              value: controller.notificationsEnabled.value,
              onChanged: controller.setNotificationsEnabled,
            ),
            const Divider(height: AppSpacing.lg),
            _switchTile(
              context,
              title: 'Daily expense reminder',
              subtitle: 'An evening nudge to log what you spent today',
              value: controller.dailySummaryEnabled.value,
              onChanged: controller.setDailySummary,
            ),
            if (controller.dailySummaryEnabled.value &&
                controller.notificationsEnabled.value)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Reminder time'),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: controller.dailyReminderTime.value,
                    );
                    if (picked != null) {
                      await controller.setDailyReminderTime(picked);
                    }
                  },
                  child: Text(controller.dailyReminderTime.value.format(context)),
                ),
              ),
            const Divider(height: AppSpacing.lg),
            _switchTile(
              context,
              title: 'Budget alerts',
              subtitle: 'Warn me at 80% and 100% of the cycle budget',
              value: controller.budgetAlertsEnabled.value,
              onChanged: controller.setBudgetAlerts,
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Weather & location',
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Use my location',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Shows the weather on Home and calculates prayer times for where you are. Your location stays on this phone.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: controller.locationEnabled.value,
                  onChanged: (value) async {
                    final access = await controller.setLocationEnabled(value);
                    if (!value || access == LocationAccess.granted) return;
                    if (access == LocationAccess.deniedForever) {
                      await LocationService.openSettings();
                    } else if (access == LocationAccess.serviceDisabled) {
                      Get.snackbar(
                        'Location is off',
                        'Turn on location services and try again.',
                      );
                    } else {
                      Get.snackbar(
                        'Permission needed',
                        'Allow location access to use this feature.',
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancePreferencesSection extends StatelessWidget {
  const _FinancePreferencesSection({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Finance Preferences',
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Default currency',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: controller.currency.value,
                  onChanged: (next) {
                    if (next != null) controller.setCurrency(next);
                  },
                  items: const [
                    DropdownMenuItem(value: 'BDT (৳)', child: Text('BDT (৳)')),
                    DropdownMenuItem(
                      value: 'USD (\$)',
                      child: Text('USD (\$)'),
                    ),
                    DropdownMenuItem(value: 'EUR (€)', child: Text('EUR (€)')),
                  ],
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Monthly cycle start day'),
              subtitle: Text(
                'Current: day ${controller.cycleStartDay.value} (e.g. ${controller.cycleStartDay.value} -> next month ${controller.cycleStartDay.value - 1 <= 0 ? 28 : controller.cycleStartDay.value - 1})',
              ),
              trailing: FilledButton.tonal(
                onPressed: () => _showCycleSelector(context, controller),
                child: const Text('Edit'),
              ),
            ),
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Expense categories',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddCategory(context, controller),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: controller.transactionCategories
                  .map((category) {
                    final isDefault = controller.isDefaultCategory(category);
                    return Chip(
                      label: Text(controller.displayCategory(category)),
                      onDeleted: isDefault
                          ? null
                          : () => controller.deleteCustomCategory(category),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCycleSelector(
    BuildContext context,
    ProfileController controller,
  ) async {
    var selected = controller.cycleStartDay.value;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cycle starts on day $selected',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Range example: $selected to next month ${selected - 1 <= 0 ? 28 : selected - 1}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Slider(
                    value: selected.toDouble(),
                    min: 1,
                    max: 28,
                    divisions: 27,
                    label: '$selected',
                    onChanged: (value) {
                      setState(() => selected = value.round());
                    },
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        await controller.setCycleStartDay(selected);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddCategory(
    BuildContext context,
    ProfileController controller,
  ) async {
    final textCtrl = TextEditingController();

    final created = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category name',
                  hintText: 'e.g. Groceries',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(textCtrl.text),
                  child: const Text('Add Category'),
                ),
              ),
            ],
          ),
        );
      },
    );

    textCtrl.dispose();

    if (created == null) return;
    final result = await controller.addCustomCategory(created);
    if (result == null) {
      Get.snackbar('Category', 'Please enter a valid category name.');
      return;
    }
    Get.snackbar('Category', '${controller.displayCategory(result)} added.');
  }
}

class _SecuritySection extends StatelessWidget {
  const _SecuritySection({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Security',
      child: AppCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            controller.pinLockEnabled.value
                ? Icons.lock_rounded
                : Icons.lock_open_rounded,
          ),
          title: const Text('App Lock'),
          subtitle: Text(
            controller.pinLockEnabled.value
                ? 'Enabled • ${controller.lockDelayLabel}'
                : 'Disabled',
          ),
          trailing: FilledButton.tonal(
            onPressed: () => Get.toNamed(AppRoutes.securitySettings),
            child: const Text('Manage'),
          ),
        ),
      ),
    );
  }
}

class _DataAccountSection extends StatelessWidget {
  const _DataAccountSection({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final isSynced = controller.lastBackupAtMs.value > 0;

    return _Section(
      title: 'Data & Account',
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.full),
                color:
                    (isSynced
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error)
                        .withValues(alpha: 0.14),
              ),
              child: Text(
                'Sync status: ${controller.syncStatusLabel}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _actionTile(
              context,
              title: 'Export Data (CSV)',
              subtitle: 'Export current cycle finance report',
              onTap: controller.exportMonthlyExpensesCsv,
            ),
            const Divider(height: AppSpacing.lg),
            _actionTile(
              context,
              title: 'Backup & Restore',
              subtitle: 'Create or restore device backup files',
              onTap: () => _showBackupActions(context),
            ),
            const Divider(height: AppSpacing.lg),
            _actionTile(
              context,
              title: 'Reset all data',
              subtitle: 'Delete all app data and start fresh',
              onTap: () => _confirmReset(context),
              destructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: destructive ? Theme.of(context).colorScheme.error : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: destructive
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Future<void> _showBackupActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await controller.backupAllDataToDocuments();
                  },
                  icon: const Icon(Icons.backup_rounded),
                  label: const Text('Create Backup Now'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await controller.restoreDataFromBackupFile();
                  },
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Restore From Backup File'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset all data?'),
          content: const Text(
            'This will delete finance, prayer, and profile settings data from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (shouldReset != true) return;
    await controller.resetAllData();
    Get.snackbar('Reset', 'All data has been reset.');
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Section(
      title: 'About',
      child: AppCard(
        child: Column(
          children: [
            Row(
              children: [
                const AppLogo(size: 44, showName: false),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppInfo.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Version ${AppInfo.version} (build ${AppInfo.buildNumber})',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.xl),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: const Text('Open-source licenses'),
              subtitle: const Text('DayLee is released under the Apache License 2.0'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showLicensePage(
                context: context,
                applicationName: AppInfo.name,
                applicationVersion: AppInfo.versionLabel,
                applicationIcon: const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: AppLogo(size: 56, showName: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}
