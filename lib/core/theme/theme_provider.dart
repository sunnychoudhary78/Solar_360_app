import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});

class ThemeState {
  final ThemeMode themeMode;
  final Color primaryColor;

  const ThemeState({
    required this.themeMode,
    required this.primaryColor,
  });

  ThemeState copyWith({
    ThemeMode? themeMode,
    Color? primaryColor,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      primaryColor: primaryColor ?? this.primaryColor,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier()
      : super(
          const ThemeState(
            themeMode: ThemeMode.light,
            primaryColor: Color(0xff689F38),
          ),
        ) {
    loadTheme();
  }

  static const String _themeModeKey = 'theme_mode';
  static const String _primaryColorKey = 'primary_color';

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final themeModeString = prefs.getString(_themeModeKey) ?? 'light';
    final colorValue = prefs.getInt(_primaryColorKey) ?? 0xff689F38;

    state = ThemeState(
      themeMode: themeModeString == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light,
      primaryColor: Color(colorValue),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _themeModeKey,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );

    state = state.copyWith(themeMode: mode);
  }

  Future<void> setPrimaryColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_primaryColorKey, color.value);

    state = state.copyWith(primaryColor: color);
  }

  Future<void> resetTheme() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_themeModeKey, 'light');
    await prefs.setInt(_primaryColorKey, 0xff689F38);

    state = const ThemeState(
      themeMode: ThemeMode.light,
      primaryColor: Color(0xff689F38),
    );
  }
}