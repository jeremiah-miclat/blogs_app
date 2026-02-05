import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BlogsRepository {
  const BlogsRepository(this._supabaseClient);

  final SupabaseClient _supabaseClient;
  User? get currentUser => _supabaseClient.auth.currentUser;
  String? get authorName =>
      currentUser?.userMetadata?['display_name']?.toString();
  String? get userId => currentUser?.id.toString();

  Future<List<Map<String, dynamic>>> getBlogsByUserId(String userId) async {
    final result = await _supabaseClient
        .from('blogs')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return result;
  }

  Future<Map<String, dynamic>> getBlogById(String blogId) async {
    final response = await _supabaseClient
        .from('blogs')
        .select()
        .eq('id', blogId)
        .single();

    return response;
  }

  Future<Map<String, dynamic>> createBlog({
    required String title,
    required String content,
    required List<PlatformFile> files,
  }) async {
    final storage = _supabaseClient.storage.from('blogs-image');

    final inserted = await _supabaseClient
        .from('blogs')
        .insert({
          'title': title.trim(),
          'content': content.trim(),
          'author_name': authorName,
          'user_id': userId,
        })
        .select()
        .single();

    final blogId = inserted['id'].toString();

    final List<String> imagePaths = [];

    try {
      for (final file in files) {
        final bytes = file.bytes;
        if (bytes == null) continue;

        final safeName = '${_dtPrefix()}_${file.name}';

        final filePath = '$blogId/$safeName';

        await storage.uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

        imagePaths.add(filePath);
      }

      await _supabaseClient
          .from('blogs')
          .update({'images_path': imagePaths})
          .eq('id', blogId);

      final blog = await _supabaseClient
          .from('blogs')
          .select()
          .eq('id', blogId)
          .single();

      return Map<String, dynamic>.from(blog);
    } catch (e) {
      await _supabaseClient.from('blogs').delete().eq('id', blogId);
      rethrow;
    }
  }

  String _dtPrefix() {
    final now = DateTime.now().toUtc();
    return now
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .split('.')
        .first;
  }

  Future<List<Map<String, dynamic>>> getAllBlogs() async {
    final response = await _supabaseClient
        .from('blogs')
        .select()
        .order('created_at', ascending: false);

    return response;
  }

  Future<Map<String, dynamic>> updateBlog({
    required Map<String, dynamic> updatedBlog,
    required List<String> toRemoveImgUrls,
    required List<PlatformFile> newImgs,
  }) async {
    final storage = _supabaseClient.storage.from('blogs-image');

    final blogId = updatedBlog['id']?.toString();
    if (blogId == null || blogId.isEmpty) {
      throw Exception('updateBlog: missing updatedBlog["id"]');
    }

    final currentRow = await _supabaseClient
        .from('blogs')
        .select('images_path')
        .eq('id', blogId)
        .single();

    final currentImages = (currentRow['images_path'] as List? ?? [])
        .map((e) => e.toString())
        .toList();

    final removePaths = toRemoveImgUrls;

    if (removePaths.isNotEmpty) {
      await storage.remove(removePaths);
    }

    final keptImages = currentImages
        .where((p) => !removePaths.contains(p))
        .toList();

    final addedImages = <String>[];

    for (final file in newImgs) {
      final bytes = file.bytes;
      if (bytes == null) continue;

      final safeName = '${_dtPrefix()}_${file.name}';
      final filePath = '$blogId/$safeName';

      await storage.uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      addedImages.add(filePath);
    }

    final patch = <String, dynamic>{...updatedBlog}
      ..remove('images')
      ..remove('images_path');

    final nextImages = [...keptImages, ...addedImages];

    final updatedRow = await _supabaseClient
        .from('blogs')
        .update({...patch, 'images_path': nextImages})
        .eq('id', blogId)
        .select()
        .single();

    return Map<String, dynamic>.from(updatedRow);
  }

  Future<Map<String, dynamic>> deleteBlog(String id) async {
    final blogId = id.toString();

    final blogImagesBucket = _supabaseClient.storage.from('blogs-image');
    final commentImagesBucket = _supabaseClient.storage.from('comments-image');

    final blogFiles = await blogImagesBucket.list(path: blogId);
    final blogPaths = blogFiles.map((f) => '$blogId/${f.name}').toList();
    if (blogPaths.isNotEmpty) {
      await blogImagesBucket.remove(blogPaths);
    }

    final commentFolders = await commentImagesBucket.list(path: blogId);
    for (final folder in commentFolders) {
      final commentId = folder.name;

      final commentFiles = await commentImagesBucket.list(
        path: '$blogId/$commentId',
      );
      final commentPaths = commentFiles
          .map((f) => '$blogId/$commentId/${f.name}')
          .toList();

      if (commentPaths.isNotEmpty) {
        await commentImagesBucket.remove(commentPaths);
      }
    }

    final response = await _supabaseClient
        .from('blogs')
        .delete()
        .eq('id', blogId)
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  bool _isImgName(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.webp');
  }

  Future<List<Map<String, dynamic>>> getCommentsForBlog(String blogId) async {
    final rows = await _supabaseClient
        .from('comments')
        .select()
        .eq('blog_id', blogId)
        .order('created_at', ascending: false);

    final storage = _supabaseClient.storage.from('comments-image');

    final comments = <Map<String, dynamic>>[];

    for (final c in (rows as List)) {
      final comment = Map<String, dynamic>.from(c);
      final commentId = comment['id']?.toString() ?? '';

      if (commentId.isEmpty) {
        comments.add({...comment, 'images': <String>[]});
        continue;
      }

      final files = await storage.list(path: '$blogId/$commentId');

      final images = files
          .where((f) => _isImgName(f.name))
          .map((f) => '$blogId/$commentId/${f.name}')
          .toList();

      comments.add({...comment, 'images': images});
    }

    return comments;
  }

  Future<Map<String, dynamic>> createComment({
    required String blogId,
    required String content,
    required List<PlatformFile> files,
  }) async {
    if (userId == null) throw Exception('Not logged in');

    final row = await _supabaseClient
        .from('comments')
        .insert({
          'blog_id': blogId,
          'content': content,
          'user_id': userId,
          'author_name': authorName,
        })
        .select()
        .single();

    final comment = Map<String, dynamic>.from(row);
    final commentId = comment['id']?.toString();

    if (commentId == null || commentId.isEmpty) {
      return {...comment, 'images': <String>[]};
    }

    final storage = _supabaseClient.storage.from('comments-image');

    for (final f in files) {
      if (f.bytes == null) continue;

      final ext = (f.extension ?? '').toLowerCase();
      if (ext.isEmpty) continue;

      final safeName = '${_dtPrefix()}_${f.name}';
      final path = '$blogId/$commentId/$safeName';

      await storage.uploadBinary(
        path,
        f.bytes!,
        fileOptions: const FileOptions(upsert: true),
      );
    }

    final listed = await storage.list(path: '$blogId/$commentId');

    final images = listed
        .where((x) => _isImgName(x.name))
        .map((x) => '$blogId/$commentId/${x.name}')
        .toList();

    return {...comment, 'images': images};
  }

  Future<void> deleteComment({
    required String blogId,
    required String commentId,
  }) async {
    final storage = _supabaseClient.storage.from('comments-image');

    final files = await storage.list(path: '$blogId/$commentId');

    final paths = files.map((f) => '$blogId/$commentId/${f.name}').toList();
    if (paths.isNotEmpty) {
      await storage.remove(paths);
    }

    await _supabaseClient.from('comments').delete().eq('id', commentId);
  }
}
