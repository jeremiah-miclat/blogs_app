import 'package:blogs_app/ext/snackbar_ext.dart';
import 'package:blogs_app/repository/blogs.dart';
import 'package:blogs_app/services/supabase_service.dart';
import 'package:blogs_app/widgets/image_preview.dart';
import 'package:blogs_app/widgets/image_preview_edit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditCommentDialog extends StatefulWidget {
  final String blogId;
  final Map<String, dynamic> comment;
  final BlogsRepository blogRepo;

  const EditCommentDialog({
    super.key,
    required this.blogId,
    required this.comment,
    required this.blogRepo,
  });

  @override
  State<EditCommentDialog> createState() => _EditCommentDialogState();
}

class _EditCommentDialogState extends State<EditCommentDialog> {
  late final TextEditingController _ctrl;

  bool _saving = false;

  late final List<String> _existingImages;
  final Set<String> _markedForDelete = {};

  final List<PlatformFile> _newImages = [];
  static const Set<String> _allowedExt = {'jpg', 'jpeg', 'png', 'webp'};

  bool _isAllowedImg(PlatformFile f) {
    final ext = (f.extension ?? '').toLowerCase();
    return _allowedExt.contains(ext);
  }

  @override
  void initState() {
    super.initState();
    debugPrint('Comment: ${widget.comment}');
    _ctrl = TextEditingController(
      text: (widget.comment['content'] ?? '').toString(),
    );

    final imgs = (widget.comment['images'] is List)
        ? (widget.comment['images'] as List).map((e) => e.toString()).toList()
        : <String>[];
    _existingImages = imgs;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleRemoveExisting(String path) {
    setState(() {
      if (_markedForDelete.contains(path)) {
        _markedForDelete.remove(path);
      } else {
        _markedForDelete.add(path);
      }
    });
  }

  Future<void> _pickNewImages() async {
    if (_saving) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExt.toList(),
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;

    final picked = result.files.where(_isAllowedImg).toList();
    if (picked.isEmpty) return;

    setState(() => _newImages.addAll(picked));
  }

  void _removeNewAt(int i) => setState(() => _newImages.removeAt(i));

  Future<void> _save() async {
    if (_saving) return;

    final commentId = widget.comment['id']?.toString();
    if (commentId == null || commentId.isEmpty) return;

    final nextText = _ctrl.text.trim();

    final noTextChange =
        nextText == (widget.comment['content'] ?? '').toString().trim();
    final noImgChange = _markedForDelete.isEmpty && _newImages.isEmpty;
    if (noTextChange && noImgChange) {
      Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await widget.blogRepo.updateComment(
        blogId: widget.blogId,
        commentId: commentId,
        content: nextText,
        removeImagePaths: _markedForDelete.toList(),
        newFiles: List<PlatformFile>.from(_newImages),
      );

      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error: $e');
      context.showSnack('Failed to post comment');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = SupabaseService.client.storage.from('comments-image');

    return AlertDialog(
      title: const Text('Edit comment'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_existingImages.isNotEmpty) ...[
                const SizedBox(height: 8),
                ImagePreviewEdit(
                  images: _existingImages,
                  markedForDelete: _markedForDelete,
                  storeUrl: storage.getPublicUrl,
                  toggleRemoveExisting: _toggleRemoveExisting,
                  disabled: _saving,
                ),
                const SizedBox(height: 12),
              ],

              if (_newImages.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'New images',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ImagePreview(
                        images: _newImages,
                        disabled: _saving,
                        onRemove: _removeNewAt,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              TextField(
                controller: _ctrl,
                enabled: !_saving,
                minLines: 1,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Comment',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickNewImages,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Add images'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),

        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
