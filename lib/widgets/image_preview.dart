import 'package:flutter/material.dart';
import 'dart:typed_data';

class ImagePreview extends StatelessWidget {
  final List<dynamic> images;
  final bool disabled;
  final void Function(int index) onRemove;

  const ImagePreview({
    super.key,
    required this.images,
    required this.onRemove,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < images.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 400,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      images[i].bytes as Uint8List,
                      fit: BoxFit.cover,
                    ),

                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: disabled ? null : () => onRemove(i),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
