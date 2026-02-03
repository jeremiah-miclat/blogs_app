import 'package:flutter/material.dart';

class DeleteBlogPage extends StatefulWidget {
  const DeleteBlogPage({super.key});

  @override
  State<DeleteBlogPage> createState() => _DeleteBlogPageState();
}

class _DeleteBlogPageState extends State<DeleteBlogPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Delete Page')));
  }
}
