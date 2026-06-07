import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';
import '../features/auth/models/auth_user.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/home/screens/home_screen.dart';

class SolarSalesApp extends ConsumerWidget {
  const SolarSalesApp({super.key});

  static const Color primaryColor = Color(0xFF4E5FAE);
  static const Color secondaryColor = Color(0xFF22B8A8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final themeState = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Solar Sales',
      debugShowCheckedModeBanner: false,
      themeMode: themeState.themeMode,
      theme: AppTheme.light(themeState.primaryColor),
      darkTheme: AppTheme.dark(themeState.primaryColor),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
      },
      home: _buildHome(auth),
    );
  }

  Widget _buildHome(AuthState auth) {
    if (!auth.initialized || auth.loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (auth.isAuthenticated) {
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}