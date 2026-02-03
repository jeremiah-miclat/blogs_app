import 'package:flutter/material.dart';

class Appbar {
  static PreferredSizeWidget build(
    BuildContext context, {
    required String title,
    bool isHome = false,
    VoidCallback? onProfileTap,
  }) {
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
          ? [IconButton(onPressed: onProfileTap, icon: Icon(Icons.person))]
          : null,
    );
  }
}
