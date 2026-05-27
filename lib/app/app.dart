import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/home/screens/home_screen.dart';

class SolarSalesApp extends StatelessWidget {
  const SolarSalesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solar Sales',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF0E0F14),
        useMaterial3: true,
      ),
      home: const SessionGate(),
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<bool> _sessionFuture = _hasActiveSession();

  Future<bool> _hasActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFFF7F8FC),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return snapshot.data! ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
