import 'package:flutter/material.dart';

import '../services/app_config_service.dart';
import '../services/staff_service.dart';
import '../utils/value_helpers.dart';
import 'staff_dashboard_screen.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
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

  @override
  void initState() {
    super.initState();
    _serverController.text = AppConfigService.instance.serverUrl;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _serverController.dispose();
    super.dispose();
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
      await _saveServer();
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

    try {
      await _saveServer();
      final user = await StaffService.instance.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StaffDashboardScreen(user: user),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = cleanError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 480,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.admin_panel_settings,
                            size: 44,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Syswatch Admin',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Intranet administrator management',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          enabled: !_loading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Staff Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            final email = (value ?? '').trim();
                            if (email.isEmpty) return 'Enter your staff email.';
                            if (!email.contains('@')) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          enabled: !_loading,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: _loading
                                  ? null
                                  : () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) => (value ?? '').isEmpty
                              ? 'Enter your password.'
                              : null,
                          onFieldSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _loading
                                ? null
                                : () => setState(
                                      () => _showServerSettings =
                                          !_showServerSettings,
                                    ),
                            icon: const Icon(Icons.lan_outlined),
                            label: Text(
                              _showServerSettings
                                  ? 'Hide server settings'
                                  : 'Server settings',
                            ),
                          ),
                        ),
                        if (_showServerSettings) ...[
                          TextFormField(
                            controller: _serverController,
                            enabled: !_loading && !_testing,
                            decoration: const InputDecoration(
                              labelText: 'Syswatch Server LAN Address',
                              hintText: 'http://192.168.1.10/syswatch_api',
                              prefixIcon: Icon(Icons.dns_outlined),
                            ),
                            validator: (value) {
                              if (!_showServerSettings) return null;
                              final text = (value ?? '').trim();
                              if (text.isEmpty) return 'Server address is required.';
                              final uri = Uri.tryParse(text);
                              if (uri == null ||
                                  !uri.hasScheme ||
                                  uri.host.isEmpty) {
                                return 'Enter a complete http:// address.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: _testing ? null : _testServer,
                              icon: _testing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.network_check),
                              label: Text(
                                _testing ? 'Testing...' : 'Test Connection',
                              ),
                            ),
                          ),
                        ],
                        if (_serverStatus != null) ...[
                          const SizedBox(height: 10),
                          _StatusBox(
                            message: _serverStatus!,
                            error: false,
                          ),
                        ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 10),
                          _StatusBox(message: _errorMessage!, error: true),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _login,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(
                              _loading ? 'Signing in...' : 'Sign In',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  final String message;
  final bool error;

  const _StatusBox({required this.message, required this.error});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: error ? scheme.onErrorContainer : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
