import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BlogsRepository {
  final SupabaseClient _supabaseClient = Supabase.instance.client;
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
    required List<dynamic> files,
  }) async {
    final storage = _supabaseClient.storage.from('blogs-image');

    final blogData = {
      'title': title,
      'content': content,
      'author_name': authorName,
      'user_id': userId,
      'images_path': <String>[],
    };

    final response = await _supabaseClient
        .from('blogs')
        .insert(blogData)
        .select()
        .single();

    final blogId = response['id'].toString();
    debugPrint('New blog ID: $blogId');

    for (final file in files) {
      if (file.bytes == null) continue;

      final safeName = '${_dtPrefix()}_${file.name}';
      final filePath = '$blogId/$safeName';

      await storage.uploadBinary(
        filePath,
        file.bytes!,
        fileOptions: const FileOptions(upsert: true),
      );
    }

    final uploadedFiles = await storage.list(path: blogId);

    final imageUrls = uploadedFiles
        .where(
          (f) =>
              f.name.endsWith('.png') ||
              f.name.endsWith('.jpg') ||
              f.name.endsWith('.jpeg') ||
              f.name.endsWith('.webp'),
        )
        .map((f) {
          final path = '$blogId/${f.name}';
          return storage.getPublicUrl(path);
        })
        .toList();

    await _supabaseClient
        .from('blogs')
        .update({'images_path': imageUrls})
        .eq('id', blogId);

    return getBlogById(blogId);
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
}
