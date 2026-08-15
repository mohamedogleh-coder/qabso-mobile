import 'package:flutter/material.dart';

import 'app_constants.dart';

class AppBrandWidget extends StatelessWidget {
  final double iconSize;

  const AppBrandWidget({super.key, this.iconSize = 30});

  static const _iconAsset = 'assets/app-icon-1024.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(iconSize * 0.28),
          child: Image.asset(
            _iconAsset,
            height: iconSize,
            width: iconSize,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            AppConstants.appName,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
