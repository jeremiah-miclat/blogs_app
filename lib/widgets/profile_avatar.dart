import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.supabaseClient,
    required this.userId,
    required this.authorName,
    this.radius = 48,
    this.bucket = 'profiles-image',
    this.showLoader = true,
  });

  final SupabaseClient supabaseClient;
  final String userId;
  final String authorName;

  final double radius;
  final String bucket;
  final bool showLoader;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool _loading = true;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If profile changed, reload avatar
    if (oldWidget.userId != widget.userId ||
        oldWidget.bucket != widget.bucket) {
      _loading = true;
      _avatarUrl = null;
      _loadAvatar();
    }
  }

  Future<void> _loadAvatar() async {
    try {
      final storage = widget.supabaseClient.storage.from(widget.bucket);

      final files = await storage.list(path: widget.userId);

      if (!mounted) return;

      if (files.isNotEmpty) {
        // Pick first file; optionally you can prefer newest, or match a specific filename.
        final file = files.first;
        final path = '${widget.userId}/${file.name}';
        _avatarUrl = storage.getPublicUrl(path);
      }
    } catch (_) {
      // ignore: keep fallback initial
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallbackLetter = widget.authorName.isNotEmpty
        ? widget.authorName[0].toUpperCase()
        : '?';

    if (_loading && widget.showLoader) {
      return SizedBox(
        width: widget.radius * 2,
        height: widget.radius * 2,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
      child: _avatarUrl == null
          ? Text(
              fallbackLetter,
              style: TextStyle(fontSize: widget.radius * 0.58),
            )
          : null,
    );
  }
}
