import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/screens/splash_screen.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/auth/presentation/screens/login_screen.dart';
import 'package:solar_sales/features/customer_portal/presentation/screens/customer_shell.dart';
import 'package:solar_sales/features/shell/presentation/screens/app_shell.dart';
import 'package:solar_sales/features/shell/presentation/screens/subscription_inactive_screen.dart';

class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  static bool _hasShownStartupSplash = false;

  bool _autoLoginAttempted = false;
  bool _minimumSplashElapsed = _hasShownStartupSplash;
  bool _startupSplashCompleted = _hasShownStartupSplash;
  Timer? _minimumSplashTimer;

  @override
  void initState() {
    super.initState();

    if (!_hasShownStartupSplash) {
      _minimumSplashTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() => _minimumSplashElapsed = true);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoLoginAttempted) return;
      _autoLoginAttempted = true;
      final auth = ref.read(authProvider);
      if (auth.isInitializing) {
        ref.read(authProvider.notifier).tryAutoLogin();
      }
    });
  }

  @override
  void dispose() {
    _minimumSplashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    final shouldShowStartupSplash = !_startupSplashCompleted &&
        (authState.isInitializing || !_minimumSplashElapsed);

    if (shouldShowStartupSplash) {
      return const SplashScreen();
    }

    if (!_startupSplashCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _startupSplashCompleted) return;
        setState(() {
          _startupSplashCompleted = true;
          _hasShownStartupSplash = true;
        });
      });
      return const SplashScreen();
    }

    if (authState.subscriptionInactive) {
      return const SubscriptionInactiveScreen();
    }

    if (authState.isCustomerSession && authState.isAuthenticated) {
      return const CustomerShell();
    }

    if (authState.isAuthenticated) {
      return const AppShell();
    }

    return const LoginScreen();
  }
}
