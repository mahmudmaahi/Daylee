import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../common/widgets/app_logo.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/security/app_lock_policy.dart';
import '../../../core/router/app_router.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/storage_service.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  bool _isAuthenticating = false;
  bool _hasFailed = false;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _unlock(preferPin: false);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _unlock({required bool preferPin}) async {
    if (_isAuthenticating) return;

    if (!StorageService.getBool(AppLockPolicy.enabledKey)) {
      _resumeToLastRoute();
      return;
    }

    final isSupported = await AuthService.isDeviceAuthenticationAvailable();
    if (!isSupported) {
      await StorageService.setBool(AppLockPolicy.enabledKey, false);
      if (!mounted) return;
      Get.snackbar('Security', 'Device authentication is not available.');
      _resumeToLastRoute();
      return;
    }

    final biometricAllowed = StorageService.getBool(
      AppLockPolicy.useBiometricsKey,
      fallback: true,
    );

    final canCheckBiometrics = await AuthService.hasBiometrics();
    final biometricOnly = biometricAllowed && canCheckBiometrics && !preferPin;

    setState(() {
      _isAuthenticating = true;
      _hasFailed = false;
    });

    final success = await AuthService.authenticate(
      localizedReason: 'Authenticate to unlock DayLee',
      biometricOnly: biometricOnly,
    );

    if (!mounted) return;

    setState(() {
      _isAuthenticating = false;
      _hasFailed = !success;
    });

    if (!success) return;

    await StorageService.setInt(
      AppLockPolicy.lastUnlockMsKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    _resumeToLastRoute();
  }

  void _resumeToLastRoute() {
    final previous = Get.previousRoute;
    if (previous.isNotEmpty && previous != AppRoutes.lock) {
      Get.back();
      return;
    }

    final saved = StorageService.getString(
      AppLockPolicy.lastRouteKey,
      fallback: AppRoutes.dashboard,
    );
    final target = saved == AppRoutes.lock || saved.isEmpty
        ? AppRoutes.dashboard
        : saved;

    Get.offAllNamed(target);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.primary.withValues(alpha: 0.16),
                  theme.colorScheme.tertiary.withValues(alpha: 0.14),
                ],
              ),
            ),
          ),
          Positioned(
            top: -90,
            right: -80,
            child: _orb(theme.colorScheme.primary.withValues(alpha: 0.25), 240),
          ),
          Positioned(
            bottom: -70,
            left: -70,
            child: _orb(theme.colorScheme.tertiary.withValues(alpha: 0.2), 220),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: const SizedBox.expand(),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _animController,
                  curve: Curves.easeOutCubic,
                ),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1).animate(
                    CurvedAnimation(
                      parent: _animController,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(
                          alpha: 0.72,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppLogo(size: 88, showName: false),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'App Locked',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Unlock with biometrics or your device PIN to continue exactly where you left off.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isAuthenticating
                                  ? null
                                  : () => _unlock(preferPin: false),
                              icon: const Icon(Icons.fingerprint_rounded),
                              label: Text(
                                _isAuthenticating
                                    ? 'Authenticating...'
                                    : 'Unlock',
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextButton.icon(
                            onPressed: _isAuthenticating
                                ? null
                                : () => _unlock(preferPin: true),
                            icon: const Icon(Icons.pin_rounded),
                            label: const Text('Use PIN instead'),
                          ),
                          if (_hasFailed) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Authentication failed. Please try again.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
