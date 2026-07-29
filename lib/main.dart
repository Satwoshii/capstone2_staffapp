import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/staff_login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? startupError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
      title: 'Syswatch Staff',
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
                    Icons.cloud_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Firebase could not start',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check the Firebase Windows configuration and internet '
                    'connection, then restart the Staff App.',
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
