import 'package:blogs_app/pages/home.dart';
import 'package:blogs_app/pages/login.dart';
import 'package:blogs_app/widgets/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final event = snapshot.data!.event;

          debugPrint('Auth event: $event');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashPage();
        }

        final session = snapshot.data?.session;
        debugPrint('Session exists: ${session != null}');
        if (session == null) {
          return const LoginPage();
        } else {
          return const HomePage();
        }
      },
    );
  }
}
