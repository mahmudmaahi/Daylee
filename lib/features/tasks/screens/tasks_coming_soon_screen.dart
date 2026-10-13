import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../common/widgets/app_bottom_nav.dart';
import '../../../common/widgets/app_card.dart';
import '../../../common/widgets/app_global_header.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';

class TasksComingSoonScreen extends StatelessWidget {
  const TasksComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppGlobalHeader(showBottomDivider: true),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.upcoming_rounded,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Tasks Coming Soon',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'The task planner is being rebuilt. This section will return in a future update.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: () => Get.offAllNamed(AppRoutes.dashboard),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Go to Home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
