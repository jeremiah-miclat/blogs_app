import 'package:blogs_app/ext/snackbar_ext.dart';
import 'package:blogs_app/repository/blogs.dart';
import 'package:blogs_app/widgets/appbar.dart';

import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  List<Map<String, dynamic>> _blogs = [];
  final _blogRepo = BlogsRepository();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const Drawer(child: Center(child: Text('Drawer Menu'))),
      appBar: Appbar.build(
        context,
        title: 'Blog App',
        isHome: true,
        onProfileTap: () {
          Navigator.pushNamed(context, '/profile');
        },
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
                        final author = (blog['author_name'] ?? '').toString();
                        final content = (blog['content'] ?? '').toString();
                        final rawImages = blog['images_path'];

                        final List<String> images = rawImages is List
                            ? rawImages.map((e) => e.toString()).toList()
                            : rawImages is String
                            ? (rawImages
                                  .replaceAll('[', '')
                                  .replaceAll(']', '')
                                  .split(',')
                                  .map((s) => s.trim().replaceAll('"', ''))
                                  .where((s) => s.isNotEmpty)
                                  .toList())
                            : <String>[];

                        final thumbUrl = images.isNotEmpty
                            ? images.first
                            : null;

                        return InkWell(
                          onTap: () {
                            // Navigator.push(
                            //   context,
                            //   MaterialPageRoute(
                            //     builder: (_) =>
                            //         BlogDetailsPage(blogId: blog['id'].toString()),
                            //   ),
                            // );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    color: Colors.grey.shade300,
                                    child: thumbUrl != null
                                        ? Image.network(
                                            thumbUrl,
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
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        author,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.pushNamed(context, '/create');

          if (!mounted) return;
          if (created == null) return;

          debugPrint('created: $created');

          setState(() {
            _blogs.insert(0, created as Map<String, dynamic>);
          });
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
