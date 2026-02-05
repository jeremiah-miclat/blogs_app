import 'package:blogs_app/repository/blogs.dart';
import 'package:blogs_app/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BlogDeletePage extends StatefulWidget {
  final Map<String, dynamic> blog;

  const BlogDeletePage({super.key, required this.blog});

  @override
  State<BlogDeletePage> createState() => _BlogDeletePageState();
}

class _BlogDeletePageState extends State<BlogDeletePage> {
  final _blogRepo = BlogsRepository(SupabaseService.client);

  bool _deleting = false;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirmDelete() async {
    return (await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete this blog?'),
            content: const Text(
              'This will permanently delete the blog and its images. '
              'This action cannot be undone.',
            ),
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

  Future<void> _deleteNow() async {
    if (_deleting) return;

    final ok = await _confirmDelete();
    if (!ok) return;

    setState(() => _deleting = true);

    try {
      final blogId = widget.blog['id'].toString();

      await _blogRepo.deleteBlog(blogId);

      if (!mounted) return;
      _toast('Blog deleted');
      Navigator.pop(context, true);
    } catch (e) {
      _toast('Delete failed: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blog = widget.blog;
    final images = (blog['images'] is List)
        ? (blog['images'] as List)
        : <dynamic>[];
    final storage = Supabase.instance.client.storage.from('blogs-image');

    return Scaffold(
      appBar: AppBar(title: const Text('Delete Blog Page')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              blog['title']?.toString() ?? 'Untitled Blog',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'By ${blog['author_name']?.toString() ?? 'Unknown'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            Text(
              blog['content']?.toString() ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: 24),

            if (images.isNotEmpty) ...[
              Text('Images', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final img in images)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      storage.getPublicUrl(img.toString()),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 160,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: const Text(
                'Warning: Deleting will permanently remove this blog and its images.',
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 48,
              child: FilledButton.icon(
                icon: const Icon(Icons.delete),
                onPressed: _deleting ? null : _deleteNow,
                label: _deleting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Delete permanently'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
