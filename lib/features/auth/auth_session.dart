import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  const AuthSession._();

  static Future<void> logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('isLoggedIn');
    await prefs.remove('userRole');
    await prefs.remove('lastLoggedInUser');

    navigator.pushNamedAndRemoveUntil(
      '/',
      (route) => false,
    );
  }
}
