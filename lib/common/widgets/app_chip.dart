import 'package:flutter/material.dart';

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      avatar: leading,
      selected: selected,
      onSelected: (_) => onTap?.call(),
      selectedColor: colorScheme.primary.withValues(alpha: 0.18),
      side: BorderSide(
        color: selected ? colorScheme.primary : colorScheme.outline,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: selected ? colorScheme.primary : colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
