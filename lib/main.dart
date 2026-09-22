import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/teacher_login_screen.dart';
import 'screens/teacher_room_config_dialog.dart';
import 'services/app_config_service.dart';
import 'services/teacher_windows_session_service.dart';
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

  runApp(SysWatchTeacherApp(startupError: startupError));

  // Keep the Teacher Windows-session recorder active in the background.
  // This does not make the window fullscreen and does not lock the PC.
  if (startupError == null) {
    unawaited(TeacherWindowsSessionService.instance.start());
  }
}

class SysWatchTeacherApp extends StatefulWidget {
  final Object? startupError;

  const SysWatchTeacherApp({super.key, this.startupError});

  @override
  State<SysWatchTeacherApp> createState() => _SysWatchTeacherAppState();
}

class _SysWatchTeacherAppState extends State<SysWatchTeacherApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late ThemeMode _themeMode;
  bool _teacherConfigOpen = false;

  @override
  void initState() {
    super.initState();
    _themeMode = ThemeService.instance.themeMode;
    ThemeService.instance.addListener(_handleThemeChanged);
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
  }

  void _handleThemeChanged() {
    if (!mounted) return;
    final next = ThemeService.instance.themeMode;
    if (next == _themeMode) return;
    setState(() => _themeMode = next);
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final keyboard = HardwareKeyboard.instance;
    final isConfigShortcut = event.logicalKey == LogicalKeyboardKey.keyA &&
        keyboard.isControlPressed &&
        keyboard.isShiftPressed;
    if (!isConfigShortcut) return false;

    unawaited(_openTeacherRoomConfiguration());
    return true;
  }

  Future<void> _openTeacherRoomConfiguration() async {
    if (_teacherConfigOpen) return;
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    _teacherConfigOpen = true;
    try {
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const TeacherRoomConfigDialog(),
      );
      if (saved != true) return;

      // Force a fresh automatic Teacher login so the newly assigned room is
      // returned by the server immediately. Windows identity recording stays
      // active in the background.
      await AppConfigService.instance.clearSession();
      if (!mounted) return;
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const TeacherLoginScreen()),
        (_) => false,
      );
    } finally {
      _teacherConfigOpen = false;
    }
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_handleThemeChanged);
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    TeacherWindowsSessionService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'SysWatch Teacher',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003366),
          primary: const Color(0xFF003366),
          secondary: const Color(0xFFFFD700),
          brightness: Brightness.light,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF003366),
          selectionColor: Color(0x33003366),
          selectionHandleColor: Color(0xFF003366),
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF003366),
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
          seedColor: const Color(0xFF003366),
          primary: const Color(0xFFFFD700),
          secondary: const Color(0xFF003366),
          brightness: Brightness.dark,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFFFFD700),
          selectionColor: Color(0x33FFD700),
          selectionHandleColor: Color(0xFFFFD700),
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFD700),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      // Normal desktop window: no kiosk service, no fullscreen call, and no
      // Admin/ITSO login route. The Teacher Windows-account flow starts here.
      home: widget.startupError == null
          ? const TeacherLoginScreen()
          : _TeacherStartupErrorScreen(error: widget.startupError!),
    );
  }
}

class _TeacherStartupErrorScreen extends StatelessWidget {
  final Object error;

  const _TeacherStartupErrorScreen({required this.error});

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
                        Icons.school_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'SysWatch Teacher could not start',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The local Teacher application configuration could not '
                        'be opened. Check folder permissions, then restart the '
                        'Teacher app.',
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
