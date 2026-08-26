import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_config_service.dart';
import '../services/server_discovery_service.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/theme_toggle_button.dart';
import 'staff_dashboard_screen.dart';
import 'teacher_dashboard_screen.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverController = TextEditingController();

  bool _loading = false;
  bool _testing = false;
  bool _obscurePassword = true;
  bool _showServerSettings = false;
  String? _errorMessage;
  String? _serverStatus;

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ── Palette ──────────────────────────────────────────────────────────────
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor =>
      _isDarkMode ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _cardColor =>
      _isDarkMode ? const Color(0xFF13141A) : Colors.white;
  Color get _fieldColor =>
      _isDarkMode ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _accentA => const Color(0xFFC0C0C0);
  Color get _accentB => const Color(0xFF000000);
  Color get _accentAForeground =>
      _isDarkMode ? _accentA : const Color(0xFF606060);
  Color get _accentBForeground => _isDarkMode ? Colors.white : _accentB;
  Color get _textColor =>
      _isDarkMode ? Colors.white : const Color(0xFF1A1C1E);
  Color get _subTextColor => _isDarkMode ? Colors.white54 : Colors.black45;
  Color get _borderColor => _isDarkMode
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.09);
  Color get _errorColor => const Color(0xFFFF6B6B);

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _serverController.text = AppConfigService.instance.serverUrl;

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _entryController.forward();
      unawaited(_autoDiscoverServer());
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _autoDiscoverServer({bool force = false}) async {
    if (!mounted) return;
    setState(() {
      _serverStatus = 'Finding Syswatch server automatically...';
      _errorMessage = null;
    });

    try {
      final found = await ServerDiscoveryService.instance.discover(
        forceLanScan: force,
      );
      if (!mounted) return;
      if (found != null) {
        _serverController.text = found;
        setState(() => _serverStatus = 'Connected automatically to Syswatch server.');
      } else {
        setState(() {
          _serverStatus = 'Automatic discovery is waiting for the server. '
              'Manual settings remain available as a fallback.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _serverStatus = 'Automatic discovery could not find the server yet.';
      });
    }
  }

  Future<void> _saveServer() async {
    await AppConfigService.instance.saveServerUrl(_serverController.text);
  }

  Future<void> _testServer() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _serverStatus = null;
      _errorMessage = null;
    });

    try {
      final found = await ServerDiscoveryService.instance.discover(
        forceLanScan: true,
      );
      if (found != null) {
        _serverController.text = found;
      } else {
        await _saveServer();
      }
      final result = await StaffService.instance.health();
      if (!mounted) return;
      setState(() {
        _serverStatus = result['database'] == 'online'
            ? 'Server and database are online.'
            : 'Server responded successfully.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = cleanError(error));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _login() async {
    if (_loading || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
      _serverStatus = null;
    });

    var routeChanged = false;

    try {
      final found = await ServerDiscoveryService.instance.discover();
      if (found != null) {
        _serverController.text = found;
      } else {
        // Keep manual server settings only as a fallback when discovery fails.
        await _saveServer();
      }

      final user = await StaffService.instance.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Finish all login-page interaction before replacing the route.
      // In particular, do not call setState from the finally block after
      // pushReplacement starts deactivating this Form/Theme subtree.
      FocusManager.instance.primaryFocus?.unfocus();
      _entryController.stop();

      routeChanged = true;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => user.isTeacher
              ? TeacherDashboardScreen(user: user)
              : StaffDashboardScreen(user: user),
        ),
      );

      return;
    } catch (error) {
      if (!mounted) return;

      routeChanged = false;
      setState(() => _errorMessage = cleanError(error));
    } finally {
      if (!routeChanged && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ── Input decoration ──────────────────────────────────────────────────────
  InputDecoration _fieldDecoration(String label, IconData icon,
      {Widget? suffixIcon, String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: TextStyle(color: _subTextColor, fontSize: 14),
      hintStyle: TextStyle(color: _subTextColor.withValues(alpha: 0.5), fontSize: 13),
      prefixIcon: Icon(icon, color: _subTextColor.withValues(alpha: 0.45), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _accentA, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _errorColor, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _errorColor, width: 1.5),
      ),
      errorStyle: TextStyle(color: _errorColor, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          _buildAmbientOrbs(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: _buildCard(),
                ),
              ),
            ),
          ),
          Positioned(
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
            top: -80,
            left: -80,
            child: _orb(280, _accentA.withValues(alpha: _isDarkMode ? 0.12 : 0.09)),
          ),
          Positioned(
            bottom: -100,
            right: -60,
            child: _orb(320, _accentB.withValues(alpha: _isDarkMode ? 0.10 : 0.08)),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );

  Widget _buildCard() {
    return Container(
      width: 480,
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 36),
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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: _buildLogoBadge()),
            const SizedBox(height: 20),

            Text(
              'SySwatch Admin',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textColor,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Intranet Admin, ITSO, and Teacher Management',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _subTextColor,
                fontSize: 13.5,
                letterSpacing: 0.1,
              ),
            ),

            const SizedBox(height: 24),

            TextFormField(
              controller: _emailController,
              enabled: !_loading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: _textColor, fontSize: 15),
              cursorColor: _accentAForeground,
              decoration: _fieldDecoration('Staff Email', Icons.email_outlined),
              validator: (value) {
                final email = (value ?? '').trim();
                if (email.isEmpty) return 'Enter your staff email.';
                if (!email.contains('@')) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _passwordController,
              enabled: !_loading,
              obscureText: _obscurePassword,
              inputFormatters: [
                LengthLimitingTextInputFormatter(
                  StaffService.maximumPasswordLength,
                ),
              ],
              textInputAction: TextInputAction.done,
              style: TextStyle(color: _textColor, fontSize: 15),
              cursorColor: _accentAForeground,
              decoration: _fieldDecoration(
                'Password',
                Icons.lock_outline_rounded,
                suffixIcon: GestureDetector(
                  onTap: _loading
                      ? null
                      : () => setState(() => _obscurePassword = !_obscurePassword),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      key: ValueKey(_obscurePassword),
                      color: _subTextColor.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ),
                ),
              ),
              validator: (value) {
                final length = (value ?? '').runes.length;
                if (length < StaffService.minimumPasswordLength ||
                    length > StaffService.maximumPasswordLength) {
                  return 'Password must contain 8 to 64 characters.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _loading
                    ? null
                    : () => setState(() => _showServerSettings = !_showServerSettings),
                style: TextButton.styleFrom(foregroundColor: _accentBForeground),
                icon: const Icon(Icons.lan_outlined, size: 18),
                label: Text(
                  _showServerSettings ? 'Hide server settings' : 'Server settings',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),

            if (_showServerSettings) ...[
              const SizedBox(height: 4),
              TextFormField(
                controller: _serverController,
                enabled: !_loading && !_testing,
                style: TextStyle(color: _textColor, fontSize: 14),
                cursorColor: _accentAForeground,
                decoration: _fieldDecoration(
                  'Syswatch Server LAN Address',
                  Icons.dns_outlined,
                  hintText: 'http://192.168.1.10/syswatch_api',
                ),
                validator: (value) {
                  if (!_showServerSettings) return null;
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'Server address is required.';
                  final uri = Uri.tryParse(text);
                  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
                    return 'Enter a complete http:// address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: _buildTestConnectionButton(),
              ),
            ],

            if (_serverStatus != null) ...[
              const SizedBox(height: 14),
              _StatusBox(
                message: _serverStatus!,
                accent: _accentAForeground,
                textColor: _textColor,
                background: _accentA.withValues(alpha: _isDarkMode ? 0.12 : 0.1),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              _StatusBox(
                message: _errorMessage!,
                accent: _errorColor,
                textColor: _textColor,
                background: _errorColor.withValues(alpha: _isDarkMode ? 0.12 : 0.08),
              ),
            ],

            const SizedBox(height: 22),
            _buildLoginButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTestConnectionButton() {
    return OutlinedButton.icon(
      onPressed: _testing ? null : _testServer,
      style: OutlinedButton.styleFrom(
        foregroundColor: _accentBForeground,
        side: BorderSide(color: _accentBForeground.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: _testing
          ? SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(_accentBForeground),
        ),
      )
          : const Icon(Icons.network_check, size: 18),
      label: Text(_testing ? 'Testing…' : 'Test Connection'),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _loading ? _fieldColor : (_isDarkMode ? _accentA : _accentB),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _loading
              ? []
              : [
            BoxShadow(
              color: (_isDarkMode ? _accentA : _accentB).withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ElevatedButton(
          onPressed: _loading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: _isDarkMode ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _loading
                ? Row(
              key: const ValueKey('loading'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isDarkMode ? Colors.black : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Signing in…',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ],
            )
                : Row(
              key: const ValueKey('idle'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.login_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Sign In',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15.5,
                    letterSpacing: 0.2,
                    color: _isDarkMode ? Colors.black : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoBadge() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _isDarkMode ? _accentA.withValues(alpha: 0.12) : _accentB.withValues(alpha: 0.08),
        border: Border.all(color: _accentA.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _accentA.withValues(alpha: 0.2),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        Icons.admin_panel_settings_rounded,
        color: _isDarkMode ? _accentA : _accentB,
        size: 34,
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  final String message;
  final Color accent;
  final Color textColor;
  final Color background;

  const _StatusBox({
    required this.message,
    required this.accent,
    required this.textColor,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            accent == const Color(0xFFFF6B6B)
                ? Icons.error_outline
                : Icons.check_circle_outline,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
