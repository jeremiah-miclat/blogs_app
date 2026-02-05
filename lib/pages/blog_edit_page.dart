import 'dart:async';

import 'package:blogs_app/repository/blogs.dart';
import 'package:blogs_app/services/supabase_service.dart';
import 'package:blogs_app/widgets/appbar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class BlogEditPage extends StatefulWidget {
  final Map<String, dynamic> blog;

  const BlogEditPage({super.key, required this.blog});

  @override
  State<BlogEditPage> createState() => _BlogEditPageState();
}

class _BlogEditPageState extends State<BlogEditPage> {
  final _blogRepo = BlogsRepository(SupabaseService.client);

  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _submitting = false;

  late Map<String, dynamic> _blog;

  late List<dynamic> _existingImages;

  final List<String> _toRemoveImgUrls = [];

  final List<PlatformFile> _newImgs = [];

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

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _isAllowedImage(PlatformFile f) {
    final ext = (f.extension ?? '').toLowerCase();
    if (ext.isEmpty) return false;
    return _allowedExt.contains(ext);
  }

  @override
  void initState() {
    super.initState();

    _blog = Map<String, dynamic>.from(widget.blog);

    _titleCtrl.text = (_blog['title'] ?? '').toString();
    _contentCtrl.text = (_blog['content'] ?? '').toString();

    _existingImages = (_blog['images_path'] as List? ?? []).cast<String>();
  }

  Future<void> _pickNewImages() async {
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

      setState(() => _newImgs.addAll(valid));
    } catch (e) {
      _toast('Failed to pick images: $e');
    }
  }

  void _toggleRemoveExisting(String imgPath) {
    setState(() {
      if (_toRemoveImgUrls.contains(imgPath)) {
        _toRemoveImgUrls.remove(imgPath);
      } else {
        _toRemoveImgUrls.add(imgPath);
      }
    });
  }

  void _removeNewAt(int index) {
    setState(() => _newImgs.removeAt(index));
  }

  int _remainingCountAfterRemove() {
    final keepExisting = _existingImages
        .where((e) => !_toRemoveImgUrls.contains(e))
        .length;
    return keepExisting + _newImgs.length;
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final blogId = _blog['id'];
    if (blogId == null) {
      _toast('Missing blog id');
      return;
    }

    setState(() => _submitting = true);
    FocusScope.of(context).unfocus();

    try {
      final updatedBlog = <String, dynamic>{
        'id': blogId,
        'title': _titleCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
      };
      debugPrint('To be deleted Img Paths: $_toRemoveImgUrls');
      final updated = await _blogRepo.updateBlog(
        updatedBlog: updatedBlog,
        toRemoveImgUrls: _toRemoveImgUrls,
        newImgs: _newImgs,
      );

      // debugPrint('New imgs: $_newImgs');
      if (!mounted) return;

      _toast('Saved!');

      Navigator.pop(context, updated);
    } catch (e) {
      _toast('Failed to save: $e');
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
    final storage = Supabase.instance.client.storage.from('blogs-image');

    final keptExisting = _existingImages
        .where((e) => !_toRemoveImgUrls.contains(e))
        .toList();

    return Scaffold(
      appBar: Appbar.build(context, title: 'Edit Blog'),
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
                enabled: !_submitting,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contentCtrl,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: _validateContent,
                enabled: !_submitting,
              ),

              const SizedBox(height: 16),

              Text(
                'Existing Images (${keptExisting.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              if (_existingImages.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('No existing images.'),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      for (final img in _existingImages)
                        ListTile(
                          leading: Checkbox(
                            value: _toRemoveImgUrls.contains(img),
                            onChanged: _submitting
                                ? null
                                : (_) => _toggleRemoveExisting(img),
                          ),
                          title: Text(
                            img.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _toRemoveImgUrls.contains(img)
                                ? 'Will be removed'
                                : 'Keep',
                          ),
                          trailing: SizedBox(
                            width: 48,
                            height: 48,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                storage.getPublicUrl(img.toString()),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                          onTap: _submitting
                              ? null
                              : () => _toggleRemoveExisting(img),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _submitting ? null : _pickNewImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Add new images'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              if (_newImgs.isNotEmpty) ...[
                Text(
                  'New Images (${_newImgs.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < _newImgs.length; i++)
                        ListTile(
                          title: Text(
                            _newImgs[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${(_newImgs[i].size / (1024 * 1024)).toStringAsFixed(2)} MB',
                          ),
                          trailing: IconButton(
                            onPressed: _submitting
                                ? null
                                : () => _removeNewAt(i),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              Text(
                'Total images after save (estimate): ${_remainingCountAfterRemove()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const SizedBox(height: 20),

              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _save,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
