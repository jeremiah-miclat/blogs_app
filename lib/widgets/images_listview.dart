import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ImagesListView extends StatelessWidget {
  final List<dynamic> images;
  final dynamic storage;

  const ImagesListView({
    super.key,
    required this.images,
    required this.storage,
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
            physics: const BouncingScrollPhysics(),
            itemCount: images.length,
            itemBuilder: (_, i) {
              final path = images[i].toString();
              return Padding(
                padding: EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    storage.getPublicUrl(path),
                    width: 120,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      width: 120,
                      height: 90,
                      child: Icon(Icons.broken_image),
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
