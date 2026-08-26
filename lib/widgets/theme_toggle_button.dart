import 'package:flutter/material.dart';

import '../services/theme_service.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Do not listen to ThemeService here. MaterialApp already rebuilds when the
    // theme changes, and Theme.of(context) will rebuild this button safely.
    // Having a second listener inside the same subtree can cause overlapping
    // inherited-widget deactivation during route/theme transitions.
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: ThemeService.instance.toggleTheme,
        icon: Icon(
          isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          color: isDarkMode
              ? Colors.amber
              : Theme.of(context).colorScheme.primary,
        ),
        tooltip: 'Toggle Light/Dark Mode',
      ),
    );
  }
}
