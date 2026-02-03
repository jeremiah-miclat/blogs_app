import 'package:supabase_flutter/supabase_flutter.dart';

class BlogsRepository {
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getBlogsByUserId(String userId) async {
    final result = await _supabaseClient
        .from('blogs')
        .select()
        .eq('user_id', userId);
    return result;
  }
}
