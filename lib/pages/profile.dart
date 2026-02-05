import 'package:blogs_app/ext/snackbar_ext.dart';
import 'package:blogs_app/widgets/appbar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  User? _user;
  bool _showPosts = false;
  bool _isUpdating = false;
  // final _blogsRepo = BlogsRepository(SupabaseService.client);

  String? _username;

  final _usernameCtrl = TextEditingController();

  PlatformFile? _pfImage;
  String? _imgUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
    });
    String? imgUrl;
    String? username;
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _user = null;
        });
      } else {
        _user = user;
        final userId = user.id;

        username = user.userMetadata?['display_name'].toString();
        // debugPrint('Userid: $userId');
        final img = await Supabase.instance.client.storage
            .from('profiles-image')
            .list(path: userId.toString());

        if (img.isNotEmpty) {
          final imgPath = img
              .map((img) => '$userId/${img.name}')
              .first
              .toString();
          imgUrl = Supabase.instance.client.storage
              .from('profiles-image')
              .getPublicUrl(imgPath);
          // debugPrint('ImgUrl: $imgUrl');
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnack(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _username = username;
          _imgUrl = imgUrl;
          _loading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _editProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Edit Profile',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: _pfImage != null
                              ? MemoryImage(_pfImage!.bytes!)
                              : (_imgUrl != null && _imgUrl!.isNotEmpty)
                              ? NetworkImage(_imgUrl!) as ImageProvider
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Color.fromARGB(255, 255, 255, 255),
                            ),
                            onPressed: () async {
                              final userPicked = await _imgPick();
                              if (userPicked) {
                                sheetSetState(() {
                                  _pfImage = _pfImage;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () async {
                      if (_loading) return;
                      try {
                        setState(() {
                          _loading = true;
                        });
                        final updateComplete = await _updateProfile();
                        if (updateComplete) {
                          _loadProfile();
                        }
                      } finally {
                        setState(() {
                          _loading = false;
                        });
                      }
                    },
                    child: const Text('Save'),
                  ),

                  const SizedBox(height: 8),

                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _imgPick() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);

    if (result == null) return false;

    final file = result.files.single;
    final ext = file.extension!;

    if (!_isValidExt(ext)) {
      if (mounted) {
        context.showSnack('Invalid file. Allowed files: png/jpg/jpeg/webp');
      }
      return false;
    } else {
      if (mounted) {
        setState(() {
          _pfImage = file;
        });
        return true;
      }
    }
    return false;
  }

  bool _isValidExt(String ext) {
    final e = ext.toString().toLowerCase().trim();
    if (e == 'png' || e == 'jpg' || e == 'jpeg' || e == 'webp') return true;
    return false;
  }

  Future<bool> _updateProfile() async {
    if (_isUpdating) return false;
    final displayName = _usernameCtrl.text.trim();
    final userId = _user?.id;
    String? uploadResult = 'Nothing to upload';
    String? updateResult = 'Nothing to update';
    // debugPrint('Display name: $displayName');
    // debugPrint('Image: $_pfImage');
    // debugPrint('UserId: $userId');
    if (userId == null) {
      return false;
    }
    if (displayName == '' && _pfImage == null) {
      if (mounted) {
        context.showSnack('Nothing to update');
        Navigator.pop(context);
        return false;
      }
    }
    try {
      setState(() {
        _isUpdating = true;
      });
      final supabaseClient = Supabase.instance.client;
      if (_pfImage != null) {
        final storage = supabaseClient.storage.from('profiles-image');
        final path = '$userId/${_pfImage!.name.toString()}';
        // debugPrint('path: $path');
        final imgList = await storage.list(path: userId);

        if (imgList.isNotEmpty) {
          final imgPaths = imgList.map((img) => '$userId/${img.name}').toList();
          await storage.remove(imgPaths);
          final uploadRes = await storage.uploadBinary(path, _pfImage!.bytes!);
          if (uploadRes != '') {
            uploadResult = 'Image updated';
          }
        }
      }

      if (displayName != '') {
        final userData = UserAttributes(data: {'display_name': displayName});
        final updateUserData = await supabaseClient.auth.updateUser(userData);
        if (updateUserData.user != null) {
          updateResult = 'Display name updated';
        }
      }
      if (mounted) {
        context.showSnack('$uploadResult and $updateResult.');
      }
    } catch (e) {
      if (mounted) {
        context.showSnack(e.toString());
      }
    } finally {
      if (mounted) {
        _isUpdating = false;
        Navigator.pop(context);
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    final blogs = (args?['blogs'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final avatar = CircleAvatar(
      radius: 52,
      backgroundImage: _pfImage != null
          ? MemoryImage(_pfImage!.bytes!)
          : (_imgUrl != null && _imgUrl!.isNotEmpty)
          ? NetworkImage(_imgUrl!) as ImageProvider
          : null,
    );

    return Scaffold(
      appBar: Appbar.build(context, title: 'Profile Page'),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: avatar),
            const SizedBox(height: 12),

            Center(
              child: Text(
                _username != null ? _username! : 'Not set',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),

            Center(
              child: Text(
                user?.email != null ? '@${user!.email}' : '@user',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),

            const SizedBox(height: 16),

            OutlinedButton(
              onPressed: _editProfile,
              child: const Text('Edit Profile'),
            ),
            const SizedBox(height: 8),

            OutlinedButton(
              onPressed: _loading ? null : _logout,
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Log Out'),
            ),

            const SizedBox(height: 12),

            if (blogs.isNotEmpty)
              OutlinedButton(
                onPressed: () {
                  setState(() => _showPosts = !_showPosts);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_showPosts ? "Hide Blog Posts" : "Show Blog Posts"),
                    const SizedBox(width: 8),
                    Icon(_showPosts ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            if (_showPosts)
              Expanded(
                child: ListView.separated(
                  itemCount: blogs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final blog = blogs[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),

                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: blog['image_path'] != null
                            ? Image.network(
                                blog['image_path'],
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.article),
                      ),

                      title: Text(
                        blog['title']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),

                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            blog['content']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'by ${blog['author_name']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),

                      trailing: const Icon(Icons.chevron_right),

                      onTap: () {},
                    );
                  },
                ),
              )
            else
              const Spacer(),
          ],
        ),
      ),
    );
  }
}
