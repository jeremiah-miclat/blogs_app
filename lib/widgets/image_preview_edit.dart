import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ImagePreviewEdit extends StatelessWidget {
  final List<String> images;
  final Set<String> markedForDelete;
  final String Function(String) storeUrl;
  final bool disabled;
  final void Function(String) toggleRemoveExisting;

  const ImagePreviewEdit({
    super.key,
    required this.images,
    required this.markedForDelete,
    required this.storeUrl,
    required this.toggleRemoveExisting,
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
          trackVisibility: true,
          child: ListView.builder(
            controller: controller,
            scrollDirection: Axis.horizontal,
            primary: false,
            physics: disabled
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final img = images[index];

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          storeUrl(img),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.broken_image)),
                        ),

                        if (markedForDelete.contains(img))
                          IgnorePointer(
                            child: Container(
                              color: const Color.fromARGB(188, 0, 0, 0),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),

                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: disabled
                                ? null
                                : () => toggleRemoveExisting(img),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color.fromARGB(141, 0, 0, 0),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                markedForDelete.contains(img)
                                    ? Icons.undo
                                    : Icons.close,
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
