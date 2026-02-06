import 'dart:async';

import 'package:blogs_app/ext/snackbar_ext.dart';
import 'package:blogs_app/pages/blog_page.dart';
import 'package:blogs_app/repository/blogs.dart';
import 'package:blogs_app/services/db_realtime_service.dart';
import 'package:blogs_app/services/supabase_service.dart';
import 'package:blogs_app/widgets/appbar.dart';
import 'package:blogs_app/widgets/drawer.dart';
import 'package:blogs_app/widgets/profile_avatar.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  List<Map<String, dynamic>> _blogs = [];
  final _blogRepo = BlogsRepository(SupabaseService.client);
  String? _userAvatar;
  StreamSubscription? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    SupabaseRealtimeService.instance.start();

    _realtimeSub = SupabaseRealtimeService.instance.stream.listen((
      event,
    ) async {
      // if (!mounted) return;

      if (event['table'] == 'blogs' && event['event'] == 'INSERT') {
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;

        final newRow = event['new'];
        final newUserId = (newRow is Map)
            ? newRow['user_id']?.toString()
            : null;

        if (currentUserId != null && newUserId == currentUserId) {
          return;
        }
        debugPrint('Inserted: ${event['new']}');
        await Future.delayed(const Duration(seconds: 5));
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('New blog posted. Tap to reload.'),
              action: SnackBarAction(
                label: 'Reload',
                onPressed: () {
                  _loadData();
                },
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }

      if (event['table'] == 'blogs' && event['event'] == 'UPDATE') {
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;

        final newRow = event['new'];
        final newUserId = (newRow is Map)
            ? newRow['user_id']?.toString()
            : null;
        if (currentUserId != null && newUserId == currentUserId) {
          return;
        }
        if (newRow == null) return;
        final blogId = newRow['id'];
        try {
          await Future.delayed(const Duration(seconds: 5));
          final fetchedBlog = await _blogRepo.getBlogById(blogId);

          final fetchedId = fetchedBlog['id'];
          final index = _blogs.indexWhere((b) => b['id'] == fetchedId);
          debugPrint('update: $fetchedBlog');
          if (index != -1) {
            setState(() {
              _blogs[index] = fetchedBlog;
            });
          }
        } catch (e) {
          debugPrint(e.toString());
        }
      }

      if (event['table'] == 'blogs' && event['event'] == 'DELETE') {
        final oldRow = event['old'];
        if (oldRow == null) return;
        final blogId = oldRow['id'];
        try {
          setState(() {
            _blogs.removeWhere((b) => b['id'] == blogId);
          });
        } catch (e) {
          debugPrint(e.toString());
        }
      }
    });
  }

  Future<void> _loadData() async {
    debugPrint('Home page loads data');
    if (_blogRepo.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.showSnack('You are not logged in');
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final blogs = await _blogRepo.getAllBlogs();
      final userId = _blogRepo.currentUser?.id;
      if (userId == null) return;
      final img = await Supabase.instance.client.storage
          .from('profiles-image')
          .list(path: _blogRepo.currentUser?.id.toString());

      if (img.isNotEmpty) {
        final imgPath = img
            .map((img) => '$userId/${img.name}')
            .first
            .toString();
        final imgUrl = Supabase.instance.client.storage
            .from('profiles-image')
            .getPublicUrl(imgPath);
        if (mounted) {
          _userAvatar = imgUrl;
        }
        // debugPrint('ImgUrl: $imgUrl');
      }
      // debugPrint('Blogs: $blogs');
      if (!mounted) return;
      setState(() {
        _blogs = blogs;
      });
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.showSnack(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _realtimeSub?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final storage = Supabase.instance.client.storage.from('blogs-image');

    return Scaffold(
      drawer: DrawerCustom(blogs: _blogs),
      appBar: Appbar.build(
        context,
        title: 'Blog App',
        isHome: true,
        onProfileTap: () async {
          final result = await Navigator.pushNamed(
            context,
            '/profile',
            arguments: {'blogs': _blogs},
          );
          if (!mounted) return;

          if (result == true) {
            _loadData();
          }

          if (result is Map<String, dynamic>) {
            final index = _blogs.indexWhere((b) => b['id'] == result['id']);
            if (index != -1) {
              setState(() {
                _blogs[index] = result;
              });
            } else {
              setState(() {
                _blogs.insert(0, result);
              });
            }
          }
        },
        user: SupabaseService.user,
        avatarurl: _userAvatar,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_blogs.isEmpty
                ? const Center(child: Text('No blogs yet'))
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: ListView.separated(
                      itemCount: _blogs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final blog = _blogs[index];

                        final title = (blog['title'] ?? '').toString();
                        final author = ('${blog['author_name']}').toString();
                        final content = (blog['content'] ?? '').toString();
                        final authorId = ('${blog['user_id']}').toString();
                        final imgs =
                            (blog['images_path'] as List?)?.cast<String>() ??
                            [];

                        final thumbUrl = imgs.isNotEmpty ? imgs.first : null;

                        return InkWell(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlogPage(blog: blog),
                              ),
                            );

                            if (!mounted || result == null) return;

                            if (result is Map<String, dynamic>) {
                              final index = _blogs.indexWhere(
                                (b) => b['id'] == result['id'],
                              );
                              if (index != -1) {
                                setState(() {
                                  _blogs[index] = result;
                                });
                              }
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey.shade300,
                                    child: thumbUrl != null
                                        ? Image.network(
                                            storage.getPublicUrl(thumbUrl),
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(Icons.article),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          ProfileAvatar(
                                            supabaseClient:
                                                SupabaseService.client,
                                            userId: authorId,
                                            authorName: author,
                                            radius: 12,
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            author,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),

                                      const SizedBox(height: 4),
                                      Text(
                                        content,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 32, bottom: 32),
        child: FloatingActionButton(
          onPressed: () async {
            final created = await Navigator.pushNamed(context, '/create');

            if (!mounted) return;
            if (created == null) return;

            // debugPrint('created: $created');

            setState(() {
              _blogs.insert(0, created as Map<String, dynamic>);
            });
          },
          child: const Icon(Icons.add),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
