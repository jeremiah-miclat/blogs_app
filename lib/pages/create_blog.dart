import 'package:blogs_app/repository/blogs.dart';
import 'package:blogs_app/services/supabase_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class CreateBlogPage extends StatefulWidget {
  const CreateBlogPage({super.key});

  @override
  State<CreateBlogPage> createState() => _CreateBlogPageState();
}

class _CreateBlogPageState extends State<CreateBlogPage> {
  final _blogRepo = BlogsRepository(SupabaseService.client);

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  final List<PlatformFile> _images = [];
  bool _submitting = false;

  static const int _maxTotalBytes = 50 * 1024 * 1024;
  static const int _maxSingleBytes = 50 * 1024 * 1024;

  static const Set<String> _allowedExt = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
    'heic',
    'heif',
  };

  int get _totalBytes => _images.fold<int>(0, (sum, f) => sum + (f.size));

  String? _validateTitle(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Title is required';
    return null;
  }

  String? _validateContent(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Content is required';
    return null;
  }

  bool _isAllowedImage(PlatformFile f) {
    final ext = (f.extension ?? '').toLowerCase();
    if (ext.isEmpty) return false;
    return _allowedExt.contains(ext);
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExt.toList(),
        allowMultiple: true,
        withData: true,
        withReadStream: false,
      );

      if (result == null) return;

      final picked = result.files;

      final invalid = picked.where((f) => !_isAllowedImage(f)).toList();
      if (invalid.isNotEmpty) {
        _toast(
          'Some files were skipped (not a supported image type): '
          '${invalid.map((e) => e.name).take(3).join(", ")}'
          '${invalid.length > 3 ? "..." : ""}',
        );
      }

      final valid = picked.where(_isAllowedImage).toList();
      if (valid.isEmpty) return;

      final tooLarge = valid.where((f) => f.size > _maxSingleBytes).toList();
      if (tooLarge.isNotEmpty) {
        _toast('Skipped ${tooLarge.length} file(s) too large.');
      }

      final remaining = valid.where((f) => f.size <= _maxSingleBytes).toList();
      if (remaining.isEmpty) return;

      final existingKeys = _images.map((f) => '${f.name}:${f.size}').toSet();
      final deduped = remaining
          .where((f) => !existingKeys.contains('${f.name}:${f.size}'))
          .toList();

      if (deduped.isEmpty) {
        _toast('Those images are already added.');
        return;
      }

      final newTotal = _totalBytes + deduped.fold<int>(0, (s, f) => s + f.size);
      if (newTotal > _maxTotalBytes) {
        _toast('Selection too large.');
        return;
      }

      setState(() => _images.addAll(deduped));
    } catch (e) {
      _toast('Failed to pick images: $e');
    }
  }

  void _removeImageAt(int index) {
    setState(() => _images.removeAt(index));
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (_totalBytes > _maxTotalBytes) {
      _toast('Total selected images too large.');
      return;
    }

    setState(() => _submitting = true);
    FocusScope.of(context).unfocus();

    try {
      final createdBlog = await _blogRepo.createBlog(
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        files: _images,
      );

      if (!mounted) return;
      _toast('Blog created!');
      Navigator.pop(context, createdBlog);
    } catch (e) {
      _toast('Failed to create blog: $e');
      debugPrint(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Blog Page')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: _validateTitle,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contentCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: _validateContent,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _submitting ? null : _pickImages,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Add images'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),

              const SizedBox(height: 12),

              if (_images.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'No images selected yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < _images.length; i++)
                        ListTile(
                          title: Text(
                            _images[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          trailing: IconButton(
                            onPressed: _submitting
                                ? null
                                : () => _removeImageAt(i),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
