import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Appbar {
  static PreferredSizeWidget build(
    BuildContext context, {
    required String title,
    bool isHome = false,
    VoidCallback? onProfileTap,
    User? user,
    String? avatarurl,
  }) {
    final displayName = (user?.userMetadata?['display_name'] as String?)
        ?.trim();
    return AppBar(
      title: Text(title),
      centerTitle: false,

      leading: isHome
          ? Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu),
              ),
            )
          : null,

      actions: isHome
          ? [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: onProfileTap,
                  child: CircleAvatar(
                    radius: 24,
                    backgroundImage: avatarurl != null
                        ? NetworkImage(avatarurl)
                        : null,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: avatarurl == null
                        ? Text(
                            (displayName != null && displayName.isNotEmpty)
                                ? displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ]
          : null,
    );
  }
}
