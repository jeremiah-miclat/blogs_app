import 'package:blogs_app/widgets/appbar.dart';
import 'package:flutter/material.dart';
import 'package:blogs_app/ext/snackbar_ext.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<StatefulWidget> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
  }

  Future<void> _register() async {
    if (_loading) return;
    final email = _email.text.trim();
    final password = _password.text.trim();
    final displayName = _displayName.text.trim();
    if (email.isEmpty || password.isEmpty || displayName.isEmpty) {
      context.showSnack('All fields are required');
    }

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
      if (mounted && response.user != null) {
        context.showSnack('You are now registered.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        context.showSnack('Register failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar.build(context, title: 'Register'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _displayName,
              decoration: const InputDecoration(labelText: 'Username'),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _loading ? null : _register,
              child: Text(_loading ? 'Registering...' : 'Register'),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Already have an account? '),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Login'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
