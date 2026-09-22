import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/windows_account_info.dart';
import '../services/server_discovery_service.dart';
import '../services/teacher_windows_session_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/theme_toggle_button.dart';
import 'teacher_dashboard_screen.dart';

/// Teacher-only Windows-account startup screen.
///
/// There is no SysWatch email/password form. Windows authenticates the person
/// first; SysWatch reads the signed-in Windows account, discovers the local
/// server, records who is currently using the shared Teacher account, then
/// opens the Teacher dashboard automatically. The Windows user's email does
/// not have to match the SysWatch Teacher account.
///
/// Unlike the Student kiosk flow, this screen does not make the application
/// fullscreen and does not lock Windows.
class TeacherLoginScreen extends StatefulWidget {
  const TeacherLoginScreen({super.key});

  @override
  State<TeacherLoginScreen> createState() => _TeacherLoginScreenState();
}

class _TeacherLoginScreenState extends State<TeacherLoginScreen>
    with SingleTickerProviderStateMixin {
  bool _checking = true;
  bool _routeChanged = false;

  String _status = 'Reading the Windows account...';
  String? _errorMessage;
  WindowsAccountInfo? _account;

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor =>
      _isDarkMode ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _cardColor =>
      _isDarkMode ? const Color(0xFF13141A) : Colors.white;
  Color get _fieldColor =>
      _isDarkMode ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _accentA => const Color(0xFFFFD700);
  Color get _accentB => const Color(0xFF003366);
  Color get _accentForeground => _isDarkMode ? _accentA : _accentB;
  Color get _textColor =>
      _isDarkMode ? Colors.white : const Color(0xFF1A1C1E);
  Color get _subTextColor => _isDarkMode ? Colors.white54 : Colors.black54;
  Color get _borderColor => _isDarkMode
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.09);
  Color get _errorColor => const Color(0xFFFF6B6B);
  Color get _successColor => const Color(0xFF22A06B);

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOutCubic,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _entryController.forward();
      unawaited(_beginAutomaticLogin());
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _beginAutomaticLogin() async {
    if (_checking && _account != null) return;

    if (mounted) {
      setState(() {
        _checking = true;
        _errorMessage = null;
        _status = 'Reading the Windows account...';
      });
    }

    try {
      final account =
          await TeacherWindowsSessionService.instance.currentAccount();
      if (account == null) {
        throw Exception(
          'SysWatch could not read the signed-in Windows account. Sign in to '
          'Windows first, then try again.',
        );
      }

      if (!mounted) return;
      setState(() {
        _account = account;
        _status = 'Finding the local SysWatch server...';
      });

      final server = await ServerDiscoveryService.instance.discover();
      if (server == null) {
        throw Exception(
          'The local SysWatch server could not be found. Make sure this PC is '
          'connected to the school LAN and the XAMPP server is running.',
        );
      }

      if (!mounted) return;
      setState(() {
        _status = 'Recording the current Windows user...';
      });

      final user = await TeacherWindowsSessionService.instance
          .tryAutomaticTeacherLogin();

      if (user == null) {
        throw Exception(
          'SysWatch could not open the Teacher account automatically.',
        );
      }

      if (!mounted) return;
      setState(() {
        _status = 'Windows user recorded. Opening Teacher dashboard...';
      });

      await _openTeacherDashboard(user);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _status = 'Teacher account could not be opened.';
        _errorMessage = cleanError(error);
      });
    }
  }

  Future<void> _openTeacherDashboard(AppUser user) async {
    if (_routeChanged || !mounted) return;
    _routeChanged = true;

    FocusManager.instance.primaryFocus?.unfocus();
    _entryController.stop();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => TeacherDashboardScreen(user: user),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          _buildAmbientOrbs(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 32,
              ),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: _buildCard(),
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

  Widget _buildAmbientOrbs() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            left: -80,
            child: _orb(
              300,
              _accentForeground.withValues(
                alpha: _isDarkMode ? 0.12 : 0.08,
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -80,
            child: _orb(
              330,
              _accentB.withValues(alpha: _isDarkMode ? 0.10 : 0.07),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildCard() {
    final account = _account;

    return Container(
      width: 500,
      padding: const EdgeInsets.fromLTRB(34, 38, 34, 32),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.5 : 0.1),
            blurRadius: 60,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _buildLogoBadge()),
          const SizedBox(height: 18),
          Text(
            'SysWatch Teacher',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textColor,
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Automatic Windows User Recording',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _subTextColor,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 24),
          if (account != null) _buildWindowsAccountCard(account),
          if (account != null) const SizedBox(height: 16),
          _buildStatusBox(),
          if (!_checking) ...[
            const SizedBox(height: 18),
            _buildRetryButton(),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLogoBadge() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _accentForeground.withValues(alpha: 0.10),
        border: Border.all(
          color: _accentForeground.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _accentForeground.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        Icons.school_rounded,
        color: _accentForeground,
        size: 35,
      ),
    );
  }

  Widget _buildWindowsAccountCard(WindowsAccountInfo account) {
    final display = account.displayLabel;
    final identifier = account.accountIdentifier.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accentForeground.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.account_circle_rounded,
              color: _accentForeground,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (identifier.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    identifier,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _subTextColor,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  account.computerName.trim().isEmpty
                      ? 'Windows PC'
                      : account.computerName.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.verified_user_outlined,
            color: _successColor,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBox() {
    final hasError = _errorMessage != null;
    final accent = hasError ? _errorColor : _accentForeground;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: _isDarkMode ? 0.11 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_checking)
            SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(
                strokeWidth: 2.1,
                color: accent,
              ),
            )
          else
            Icon(
              hasError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              color: accent,
              size: 20,
            ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _status,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: _subTextColor,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryButton() {
    return OutlinedButton.icon(
      onPressed: _checking ? null : _beginAutomaticLogin,
      style: OutlinedButton.styleFrom(
        foregroundColor: _accentForeground,
        side: BorderSide(color: _accentForeground.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: const Icon(Icons.refresh_rounded, size: 20),
      label: const Text(
        'Retry',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
