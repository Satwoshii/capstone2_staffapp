import 'package:flutter/material.dart';

import 'screens/staff_login_screen.dart';
import 'services/app_config_service.dart';

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

class StaffAdminApp extends StatelessWidget {
  final Object? startupError;

  const StaffAdminApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Syswatch Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF155EEF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ),
      home: startupError == null
          ? const StaffLoginScreen()
          : _StartupErrorScreen(error: startupError!),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final Object error;

  const _StartupErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
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
    );
  }
}
