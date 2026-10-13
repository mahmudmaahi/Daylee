import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';

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
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.26),
          child: Image.asset(
            'assets/images/logo.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            matchTextDirection: false,
            colorBlendMode: BlendMode.srcOver,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
          ),
        ),
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
