import 'package:flutter/material.dart';

import 'screens/staff_login_screen.dart';
import 'services/app_config_service.dart';
import 'services/theme_service.dart';
import 'widgets/theme_toggle_button.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? startupError;
  try { 
    await AppConfigService.instance.init();
  } catch (error) {
    startupError = error;
  }

  runApp(StaffAdminApp(startupError: startupError));
}

class StaffAdminApp extends StatefulWidget {
  final Object? startupError;

  const StaffAdminApp({super.key, this.startupError});

  @override
  State<StaffAdminApp> createState() => _StaffAdminAppState();
}

class _StaffAdminAppState extends State<StaffAdminApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = ThemeService.instance.themeMode;
    ThemeService.instance.addListener(_handleThemeChanged);
  }

  void _handleThemeChanged() {
    if (!mounted) return;

    final next = ThemeService.instance.themeMode;
    if (next == _themeMode) return;

    setState(() => _themeMode = next);
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_handleThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Syswatch Admin',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC0C0C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC0C0C0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFC0C0C0),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: widget.startupError == null
          ? const StaffLoginScreen()
          : _StartupErrorScreen(error: widget.startupError!),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final Object error;

  const _StartupErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: SizedBox(
              width: 560,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.storage_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Syswatch Admin could not start',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The local application configuration could not be opened. '
                        'Check folder permissions, then restart the Admin App.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SelectableText(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 24,
            left: 24,
            child: ThemeToggleButton(),
          ),
        ],
      ),
    );
  }
}
