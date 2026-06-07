import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_provider.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  static final List<Color> themeColors = [
    const Color(0xff689F38),
    const Color(0xffFB8C00),
    const Color(0xff1976D2),
    const Color(0xff3F51B5),
    const Color(0xff673AB7),
    const Color(0xff455A64),
    const Color(0xff009688),
    const Color(0xffD32F2F),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    final primaryColor = themeState.primaryColor;
    final isDark = themeState.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section(
            context,
            title: 'Appearance',
            child: Container(
              height: 64,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey.shade800
                    : const Color(0xffeee3d8),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Row(
                children: [
                  _modeButton(
                    title: 'Light',
                    icon: Icons.wb_sunny,
                    selected: !isDark,
                    color: primaryColor,
                    onTap: () => notifier.setThemeMode(ThemeMode.light),
                  ),
                  _modeButton(
                    title: 'Dark',
                    icon: Icons.dark_mode,
                    selected: isDark,
                    color: primaryColor,
                    onTap: () => notifier.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          _section(
            context,
            title: 'Primary Color',
            child: Wrap(
              spacing: 18,
              runSpacing: 18,
              children: themeColors.map((color) {
                final selected = color.value == primaryColor.value;

                return GestureDetector(
                  onTap: () => notifier.setPrimaryColor(color),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: Colors.black, width: 3)
                          : null,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.45),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 30,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 22),
          _section(
            context,
            title: 'Reset',
            child: OutlinedButton.icon(
              onPressed: notifier.resetTheme,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset to Defaults'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1f1f1f) : const Color(0xffffefe5),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _modeButton({
    required String title,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : Colors.black,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}