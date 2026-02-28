import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safety_pal/providers/auth_provider.dart';
import 'package:safety_pal/screens/auth/login_screen.dart';
import 'package:safety_pal/screens/main_shell.dart';

/// App initialization screen that checks authentication state.
class AppInitializer extends StatelessWidget {
  const AppInitializer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // If user is authenticated, show main shell
        if (authProvider.isAuthenticated) {
          return const MainShell();
        }

        // If no user, show login screen
        return const LoginScreen();
      },
    );
  }
}
