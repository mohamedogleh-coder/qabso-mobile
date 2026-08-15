import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'app_user_model.dart';
import 'app_user_notifer.dart';

class UserAvatarWidget extends ConsumerWidget {
  final double radius;
  final VoidCallback? onTap;

  const UserAvatarWidget({super.key, this.radius = 18, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserNotifierProvider).value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Semantics(
          label: user?.fullName ?? "Account",
          button: onTap != null,
          child: _buildAvatar(context, user),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, AppUserModel? user) {
    final theme = Theme.of(context);
    final photo = user?.profile;
    final initials = _initialsOf(user?.fullName);

    final picture = photo == null || photo.isEmpty ? null : NetworkImage(photo);

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.transparent,
      foregroundImage: picture,
      // CircleAvatar refuses an error handler with no image to handle, so the
      // handler goes only where there is a picture that can fail.
      onForegroundImageError: picture == null ? null : (_, _) {},
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.30),
              theme.colorScheme.primary.withValues(alpha: 0.12),
            ],
          ),
        ),
        alignment: Alignment.center,
        child: initials == null
            ? Icon(
                Symbols.person,
                fill: 1,
                color: theme.colorScheme.primary,
                size: radius,
              )
            : Text(
                initials,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  static String? _initialsOf(String? fullName) {
    final words = (fullName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return null;

    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }
}
