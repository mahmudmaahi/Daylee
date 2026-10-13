import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../common/widgets/app_card.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/security/app_lock_policy.dart';
import '../../profile/controllers/profile_controller.dart';

class SecuritySettingsScreen extends GetView<ProfileController> {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Lock Settings')),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppCard(
              child: Column(
                children: [
                  _toggleTile(
                    context,
                    icon: Icons.lock_rounded,
                    title: 'Enable App Lock',
                    subtitle: 'Protect app access when you leave the app',
                    value: controller.pinLockEnabled.value,
                    onChanged: controller.setPinLock,
                  ),
                  const Divider(height: AppSpacing.lg),
                  _dropdownTile(
                    context,
                    icon: Icons.timer_rounded,
                    title: 'Auto-lock timer',
                    subtitle: 'Lock after inactivity in background',
                    value: controller.lockDelaySeconds.value,
                    items: AppLockPolicy.supportedDelaySeconds,
                    itemLabel: AppLockPolicy.delayLabel,
                    onChanged: controller.setLockDelay,
                    enabled: controller.pinLockEnabled.value,
                  ),
                  const Divider(height: AppSpacing.lg),
                  _toggleTile(
                    context,
                    icon: Icons.fingerprint_rounded,
                    title: 'Use biometrics',
                    subtitle: 'Prefer fingerprint / face for faster unlock',
                    value: controller.useBiometrics.value,
                    onChanged: controller.setUseBiometrics,
                    enabled: controller.pinLockEnabled.value,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.password_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text('Change PIN'),
                subtitle: const Text(
                  'Opens your device security settings to update lock credentials.',
                ),
                trailing: FilledButton.tonal(
                  onPressed: controller.openDeviceSecuritySettings,
                  child: const Text('Open'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Switch.adaptive(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  Widget _dropdownTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required int value,
    required List<int> items,
    required String Function(int) itemLabel,
    required ValueChanged<int> onChanged,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            DropdownButton<int>(
              value: value,
              onChanged: (next) {
                if (next != null) onChanged(next);
              },
              items: items
                  .map(
                    (seconds) => DropdownMenuItem<int>(
                      value: seconds,
                      child: Text(itemLabel(seconds)),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}
