import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeNotifier extends Notifier<Color> {
  static const _key = 'app_primary_color';
  static const Color defaultAppColor = Color(0xFF0F766E);

  @override
  Color build() {
    _loadSavedColor();
    return defaultAppColor;
  }

  Future<void> _loadSavedColor() async {
    final prefs = await SharedPreferences.getInstance();
    final savedColor = prefs.getInt(_key);
    if (savedColor != null) {
      state = Color(savedColor);
    }
  }

  Future<void> changeColor(Color newColor) async {
    state = newColor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, newColor.toARGB32());
  }

  void resetColor() {
    state = defaultAppColor;
  }
}

final appThemeProvider = NotifierProvider<AppThemeNotifier, Color>(
  AppThemeNotifier.new,
);
