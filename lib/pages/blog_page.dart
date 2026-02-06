import 'dart:async';

import 'package:blogs_app/pages/blog_delete_page.dart';
import 'package:blogs_app/pages/blog_edit_page.dart';
import 'package:blogs_app/pages/public_profile_page';
import 'package:blogs_app/repository/blogs.dart';
import 'package:blogs_app/services/db_realtime_service.dart';
import 'package:blogs_app/services/supabase_service.dart';
import 'package:blogs_app/widgets/edit_comment.dart';
import 'package:blogs_app/widgets/image_preview.dart';
import 'package:blogs_app/widgets/images_listview.dart';
import 'package:blogs_app/widgets/profile_avatar.dart';
import 'package:carousel_slider/carousel_options.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class BlogPage extends StatefulWidget {
  final Map<String, dynamic> blog;

  const BlogPage({super.key, required this.blog});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  bool _loading = true;
  bool _isOwner = false;
  String? _ownerAvatar;
  String? _ownerName;
  Map<String, dynamic>? _blog;

  final _blogRepo = BlogsRepository(Supabase.instance.client);

  bool _showComments = true;
  bool _commentsLoading = false;
  bool _commentSubmitting = false;
  bool _commentsLoadedOnce = false;
  bool _deleted = false;
  final _commentCtrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];

  final List<PlatformFile> _commentImgs = [];
  static const Set<String> _allowedExt = {'jpg', 'jpeg', 'png', 'webp'};

  StreamSubscription? _rtSub;
  final Set<String> _knownCommentIds = {};

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _isAllowedImg(PlatformFile f) {
    final ext = (f.extension ?? '').toLowerCase();
    return _allowedExt.contains(ext);
  }

  Future<void> _pickCommentImages() async {
    if (_commentSubmitting) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExt.toList(),
        allowMultiple: true,
        withData: true,
      );
      if (result == null) return;

      final picked = result.files.where(_isAllowedImg).toList();
      if (picked.isEmpty) return;

      setState(() => _commentImgs.addAll(picked));
    } catch (e) {
      _toast('Pick images failed: $e');
    }
  }

  void _removeCommentImgAt(int i) {
    setState(() => _commentImgs.removeAt(i));
  }

  Future<void> _submitComment() async {
    if (_deleted) {
      _toast('This blog was deleted');
      return;
    }
    final blogId = _blog?['id']?.toString();
    if (blogId == null || blogId.isEmpty) return;

    final text = _commentCtrl.text.trim();
    if (text.isEmpty && _commentImgs.isEmpty) return;

    setState(() => _commentSubmitting = true);
    FocusScope.of(context).unfocus();

    try {
      await _blogRepo.createComment(
        blogId: blogId,
        content: text,
        files: List<PlatformFile>.from(_commentImgs),
      );

      if (!mounted) return;

      setState(() => _commentImgs.clear());
      _commentCtrl.clear();

      await _reloadComments();
    } catch (e) {
      _toast('Failed to comment: $e');
    } finally {
      if (mounted) setState(() => _commentSubmitting = false);
    }
  }

  @override
  void dispose() {
    _rtSub?.cancel();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _blog = widget.blog;
    _loadOwner();
    _ownerName = widget.blog['author_name'] ?? 'Not set';
    SupabaseRealtimeService.instance.start();
    _startRealtime();
    _reloadComments();
  }

  void _startRealtime() {
    _rtSub?.cancel();

    final blogId = _blog?['id']?.toString();
    if (blogId == null || blogId.isEmpty) return;

    _rtSub = SupabaseRealtimeService.instance.stream.listen((event) async {
      if (!mounted) return;

      if (event['table'] == 'blogs') {
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        final type = event['event']?.toString();

        if (type == 'UPDATE') {
          final blogId = _blog!['id'].toString();
          final newRow = event['new'];

          if (newRow == null) return;
          final newUserId = (newRow is Map)
              ? newRow['user_id']?.toString()
              : null;
          if (currentUserId != null && newUserId == currentUserId) {
            return;
          }
          if (blogId != newRow['id']?.toString()) return;
          setState(() {
            _loading = true;
          });
          try {
            await Future.delayed(const Duration(seconds: 5));
            final result = await _blogRepo.getBlogById(blogId);
            debugPrint('Update result: $result');
            setState(() {
              _blog = result;
            });
          } catch (_) {
          } finally {
            if (mounted) {
              setState(() {
                _loading = false;
              });
            }
          }
        }

        if (type == 'DELETE') {
          final oldRow = event['old'];
          if (oldRow == null || _blog == null) return;
          final delBlogId = oldRow['id'];
          if (_blog?['id'].toString() == delBlogId.toString()) {
            debugPrint('Blog on view was deleted');
            setState(() {
              _deleted = true;
              if (_blog?['user_id'] == currentUserId) return;
              _toast("This blog was deleted");
            });
          }
        }
      }

      if (event['table'] == 'comments') {
        final type = event['event']?.toString();

        if (type == 'INSERT') {
          final newRow = (event['new'] as Map?)?.cast<String, dynamic>();
          if (newRow == null) return;
          if (!_commentsLoadedOnce) return;

          if (newRow['blog_id']?.toString() != blogId) return;
          final userName = _blogRepo.currentUser?.userMetadata?['display_name']
              .toString();
          final commentAuthorName = newRow['author_name']?.toString();
          // debugPrint('User: $userName, Commenter: $commentAuthorName');
          if (userName == commentAuthorName) {
            return;
          }
          final newId = newRow['id']?.toString();
          if (newId == null || newId.isEmpty) return;

          if (_knownCommentIds.contains(newId)) return;
          await Future.delayed(const Duration(seconds: 5));
          await _reloadComments();

          for (final c in _comments) {
            final id = c['id']?.toString();
            if (id != null) _knownCommentIds.add(id);
          }
        }

        if (type == 'UPDATE') {
          final newRow = (event['new'] as Map?)?.cast<String, dynamic>();
          if (newRow == null) return;
          if (newRow['blog_id']?.toString() != blogId) return;
          if (!_commentsLoadedOnce) return;
          final userName = _blogRepo.currentUser?.userMetadata?['display_name']
              .toString();
          final commentAuthorName = newRow['author_name']?.toString();
          if (userName == commentAuthorName) {
            return;
          }
          await Future.delayed(const Duration(seconds: 5));
          await _reloadComments();
          return;
        }

        if (type == 'DELETE') {
          final oldRow = (event['old'] as Map?)?.cast<String, dynamic>();
          if (oldRow == null) return;

          final deletedId = oldRow['id']?.toString();
          if (deletedId == null || deletedId.isEmpty) return;

          if (!_commentsLoadedOnce) return;

          setState(() {
            _comments.removeWhere((c) => c['id']?.toString() == deletedId);
            _knownCommentIds.remove(deletedId);
          });

          return;
        }
      }
    });
  }

  Future<bool> _confirmDeleteComment() async {
    return (await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete comment?'),
            content: const Text('This will permanently delete your comment.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _loadOwner() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final userId = currentUser?.id;
      final ownerId = _blog!['user_id'];
      if (!mounted) return;
      final img = await Supabase.instance.client.storage
          .from('profiles-image')
          .list(path: ownerId.toString());

      if (img.isNotEmpty) {
        final imgPath = img
            .map((img) => '$ownerId/${img.name}')
            .first
            .toString();

        final ownerAvatar = Supabase.instance.client.storage
            .from('profiles-image')
            .getPublicUrl(imgPath);
        setState(() {
          _ownerAvatar = ownerAvatar;
        });
      }
      setState(() {
        _isOwner = ownerId == userId;

        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load blog extras: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadComments() async {
    final blogId = _blog?['id']?.toString();
    if (blogId == null || blogId.isEmpty) return;

    setState(() => _commentsLoading = true);
    try {
      final fresh = await _blogRepo.getCommentsForBlog(blogId);
      if (!mounted) return;
      setState(() {
        _comments = fresh;
        _commentsLoadedOnce = true;
        _knownCommentIds
          ..clear()
          ..addAll(
            _comments.map((c) => c['id']?.toString()).whereType<String>(),
          );
      });
    } catch (e) {
      _toast('Failed to load comments: $e');
    } finally {
      if (mounted) setState(() => _commentsLoading = false);
    }
  }

  Future<void> _toggleComments() async {
    if (_deleted) {
      _toast('This blog was deleted');
      return;
    }
    final blogId = _blog?['id']?.toString();
    if (blogId == null || blogId.isEmpty) return;

    final next = !_showComments;
    setState(() => _showComments = next);

    if (next) {
      // debugPrint('commentsLoadedOnce: $_commentsLoadedOnce');
      if (!_commentsLoadedOnce) {
        // debugPrint('commentsLoadedOnce: $_commentsLoadedOnce');
        await _reloadComments();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorId = _blog!['user_id']?.toString();
    final authorName = (_blog!['author_name'] ?? 'Unknown').toString();
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_blog == null) {
      return const Scaffold(body: Center(child: Text('Blog not found')));
    }
    final storage = SupabaseService.client.storage.from('blogs-image');

    final imgs = (_blog?['images_path'] as List? ?? []).cast<String>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        Navigator.of(context).pop(_blog);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Blog View Page'),
          leading: BackButton(
            onPressed: () {
              Navigator.pop(context, _blog);
            },
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isOwner) ...[
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    onPressed: () async {
                      final nav = Navigator.of(context);

                      final updated = await nav.push(
                        MaterialPageRoute(
                          builder: (_) => BlogEditPage(blog: _blog!),
                        ),
                      );

                      if (!mounted || updated == null) return;

                      setState(() {
                        _blog = Map<String, dynamic>.from(updated);
                      });

                      // nav.pop(updated);
                    },
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    onPressed: () async {
                      final nav = Navigator.of(context);

                      final deleted = await nav.push<bool>(
                        MaterialPageRoute(
                          builder: (_) => BlogDeletePage(blog: _blog!),
                        ),
                      );

                      if (!mounted || deleted != true) return;

                      nav.pop({'deleted': true, 'id': _blog!['id']});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Text(
            //   _blog!['title'] ?? '',
            //   style: Theme.of(context).textTheme.headlineSmall,
            // ),
            // const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(48),
                  onTap: authorId == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PublicProfilePage(
                                userId: authorId,
                                authorName: authorName,
                              ),
                            ),
                          );
                        },
                  child: ProfileAvatar(
                    supabaseClient: SupabaseService.client,
                    userId: authorId!,
                    authorName: authorName,
                    radius: 20,
                  ),
                ),

                const SizedBox(width: 8),

                InkWell(
                  onTap: authorId == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PublicProfilePage(
                                userId: authorId,
                                authorName: authorName,
                              ),
                            ),
                          );
                        },
                  child: Text(
                    authorName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Text(
              _blog!['title'] ?? '',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Text(
              _blog!['content'] ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: 24),

            if (imgs.length < 2 && imgs.isNotEmpty) ...[
              // Text('Images', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final img in imgs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: Image.network(
                      storage.getPublicUrl(img),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
            ],

            if (imgs.length > 1) ...[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: SizedBox(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: imgs.length,
                      itemBuilder: (BuildContext context, int i) {
                        return
                        // InteractiveViewer(child:
                        SizedBox(
                          height: 250,
                          width: double.infinity,

                          child: Image.network(
                            storage.getPublicUrl(imgs[i]),
                            fit: BoxFit.cover,
                          ),
                        );
                        // );
                      },

                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            Row(
              children: [
                ElevatedButton.icon(
                  icon: Icon(_showComments ? Icons.expand_less : Icons.comment),
                  label: Text(
                    _showComments ? 'Hide comments' : 'Show comments',
                  ),
                  onPressed: _toggleComments,
                ),
                const SizedBox(width: 12),
                if (_commentsLoadedOnce) Text('${_comments.length}'),
              ],
            ),

            if (_showComments) ...[
              const SizedBox(height: 12),

              if (_commentImgs.isNotEmpty) ...[
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ImagePreview(
                    images: _commentImgs,
                    disabled: _commentSubmitting,
                    onRemove: _removeCommentImgAt,
                  ),
                ),
                const SizedBox(height: 10),
              ],

              TextField(
                controller: _commentCtrl,
                enabled: !_commentSubmitting,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Write a comment',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _commentSubmitting ? null : _pickCommentImages,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Add images'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _commentSubmitting ? null : _submitComment,
                      icon: _commentSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: const Text('Post'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_commentsLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No comments yet.'),
                )
              else
                Column(
                  children: [
                    for (final c in _comments)
                      _CommentTile(
                        comment: c,
                        currentUserId:
                            Supabase.instance.client.auth.currentUser?.id,

                        onEdit: () async {
                          final blogId = _blog?['id']?.toString();
                          final commentId = c['id']?.toString();
                          if (blogId == null || commentId == null) return;

                          final updated =
                              await showDialog<Map<String, dynamic>>(
                                context: context,
                                builder: (_) => EditCommentDialog(
                                  blogId: blogId,
                                  comment: c,
                                  blogRepo: _blogRepo,
                                ),
                              );

                          if (!mounted || updated == null) return;

                          await _reloadComments();
                          _toast('Comment updated');
                        },
                        onDelete: () async {
                          final blogId = _blog?['id']?.toString();
                          final commentId = c['id']?.toString();
                          if (blogId == null || commentId == null) return;

                          final ok = await _confirmDeleteComment();
                          if (!ok) return;

                          try {
                            await _blogRepo.deleteComment(
                              blogId: blogId,
                              commentId: commentId,
                            );

                            if (!mounted) return;

                            _toast('Comment deleted');
                            await _reloadComments();
                          } catch (e) {
                            _toast('Delete failed: $e');
                          }
                        },
                      ),
                  ],
                ),

              const SizedBox(height: 12),

              // const Divider(),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final String? currentUserId;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const _CommentTile({
    required this.comment,
    required this.currentUserId,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final imgs = (comment['images'] is List)
        ? (comment['images'] as List)
        : <dynamic>[];
    final storage = Supabase.instance.client.storage.from('comments-image');

    final commentUserId = comment['user_id']?.toString();
    final safeUserId = commentUserId ?? '';
    final commenterName = comment['author_name']?.toString();
    final isOwner =
        currentUserId != null &&
        commentUserId != null &&
        currentUserId == commentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    ProfileAvatar(
                      supabaseClient: SupabaseService.client,
                      userId: safeUserId,
                      authorName: commenterName ?? 'Not set',
                      radius: 10,
                    ),
                    SizedBox(width: 5),
                    Text(
                      (comment['author_name'] ?? 'Unknown').toString(),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
              if (isOwner)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit!();
                    } else if (value == 'delete') {
                      onDelete!();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(
                          Icons.edit_outlined,
                          // color: Color.fromARGB(213, 3, 39, 245),
                        ),
                        title: Text('Edit'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_outline,
                          color: Color.fromARGB(255, 245, 3, 43),
                        ),
                        title: Text('Delete'),
                        textColor: Color.fromARGB(255, 245, 3, 43),
                      ),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text((comment['content'] ?? '').toString()),

          if (imgs.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ImagesListView(images: imgs, storage: storage),
            ),
          ],
        ],
      ),
    );
  }
}
