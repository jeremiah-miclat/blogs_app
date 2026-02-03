import 'package:blogs_app/widgets/appbar.dart';

import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const Drawer(child: Center(child: Text('Drawer Menu'))),
      appBar: Appbar.build(
        context,
        title: 'Blog App',
        isHome: true,
        onProfileTap: () {
          Navigator.pushNamed(context, '/profile');
        },
      ),
      body: Center(child: Text('List View')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/create');
        },
        child: Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
