import 'package:flutter/material.dart';

class DrawerCustom extends StatelessWidget {
  const DrawerCustom({super.key, this.blogs});

  final List<Map<String, dynamic>>? blogs;

  @override
  Widget build(BuildContext context) {
    final authors = blogs
        ?.where((b) => b['author_name'] != null)
        .map((b) => b['author_name'] as String)
        .toSet()
        .toList();
    return Drawer(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bloggers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),
            authors != null
                ? Expanded(
                    child: ListView.separated(
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemCount: authors.length,
                      itemBuilder: (context, i) {
                        return SizedBox(
                          height: 24,
                          child: InkWell(
                            onTap: () => {},
                            child: Text('- ${authors[i]}'),
                          ),
                        );
                      },
                    ),
                  )
                : Center(child: Text('No Bloggers yet.')),
          ],
        ),
      ),
    );
  }
}
