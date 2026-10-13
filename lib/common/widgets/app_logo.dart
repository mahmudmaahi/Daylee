import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';

/// The DayLee mark.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 28,
    this.showName = true,
    this.nameStyle,
  });

  final double size;
  final bool showName;
  final TextStyle? nameStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIconImage(size: size),
        if (showName) ...[
          const SizedBox(width: 8),
          Text(
            AppStrings.appName,
            style: nameStyle ?? Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ],
    );
  }
}

/// Rounded square with the DayLee logo.
class AppIconImage extends StatelessWidget {
  const AppIconImage({super.key, required this.size, this.radiusFactor = 0.26});

  final double size;
  final double radiusFactor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * radiusFactor),
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
