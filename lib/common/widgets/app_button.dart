import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme_tokens.dart';

enum AppButtonVariant { primary, secondary }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
    this.variant = AppButtonVariant.primary,
    this.minHeight = 50,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final AppButtonVariant variant;
  final double minHeight;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final isPrimary = widget.variant == AppButtonVariant.primary;
    final hasCustomBackground = widget.backgroundColor != null;
    final foregroundColor =
        widget.foregroundColor ??
        (isPrimary ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface);

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: foregroundColor),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: theme.textTheme.labelLarge?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    final button = AnimatedScale(
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      scale: _pressed ? 0.97 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: hasCustomBackground
                ? null
                : (isPrimary ? tokens.primaryGradient : null),
            color: hasCustomBackground
                ? widget.backgroundColor
                : (isPrimary ? null : tokens.secondaryButtonSurface),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: hasCustomBackground || isPrimary
                ? null
                : Border.all(color: tokens.secondaryButtonBorder),
          ),
          child: InkWell(
            onTap: widget.onPressed,
            onHighlightChanged: (value) {
              setState(() => _pressed = value);
            },
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: widget.minHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );

    if (!widget.expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
