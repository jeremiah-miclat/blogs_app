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
    return Column(
      children: [
        for (final img in images)
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
                    // Material(
                    //   color: Colors.transparent,
                    //   child: InkWell(onTap: () => toggleRemoveExisting(img)),
                    // ),
                    Image.network(
                      storeUrl(img),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Center(child: Icon(Icons.broken_image)),
                    ),

                    if (markedForDelete.contains(img))
                      Container(
                        color: const Color.fromARGB(188, 0, 0, 0),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),

                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: () => toggleRemoveExisting(img),
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
          ),
      ],
    );
  }
}
