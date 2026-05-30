import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_provider.dart';

class AuthSession {
  const AuthSession._();

  static Future<void> logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authProvider.notifier).logout();

    if (!context.mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }
}