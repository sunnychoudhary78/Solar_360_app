import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return MaterialApp(
      title: 'Solar Sales',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',

        scaffoldBackgroundColor: const Color(0xFFF7F8FC),

        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: secondaryColor,
        ),

        primaryColor: primaryColor,

        splashColor: primaryColor.withOpacity(0.12),
        highlightColor: Colors.transparent,

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F8FC),
          foregroundColor: primaryColor,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(
            color: primaryColor,
          ),
        ),

        iconTheme: const IconThemeData(
          color: primaryColor,
        ),

        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: Color(0xFFE4E1EA),
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFE4E1EA),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: primaryColor,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: const BorderSide(
              color: primaryColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
          ),
        ),

        floatingActionButtonTheme:
            const FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),

        progressIndicatorTheme:
            const ProgressIndicatorThemeData(
          color: primaryColor,
        ),

        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.all(
            primaryColor,
          ),
        ),

        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.all(
            primaryColor,
          ),
        ),

        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.all(
            primaryColor,
          ),
          trackColor: WidgetStateProperty.all(
            primaryColor.withOpacity(0.4),
          ),
        ),
      ),

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