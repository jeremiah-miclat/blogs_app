import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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
    final controller = ScrollController();

    return SizedBox(
      height: 150,
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: Scrollbar(
          controller: controller,
          thumbVisibility: true,
          child: ListView.builder(
            controller: controller,
            scrollDirection: Axis.horizontal,
            primary: false,
            physics: disabled
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            itemCount: images.length,
            itemBuilder: (context, i) {
              final bytes = images[i].bytes as Uint8List;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(bytes, fit: BoxFit.cover),
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
              );
            },
          ),
        ),
      ),
    );
  }
}
