import 'package:flutter/material.dart';

class EditBlogPage extends StatefulWidget {
  const EditBlogPage({super.key});

  @override
  State<EditBlogPage> createState() => _EditBlogPageState();
}

class _EditBlogPageState extends State<EditBlogPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Edit Blog')));
  }
}
