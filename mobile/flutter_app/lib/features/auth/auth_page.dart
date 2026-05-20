import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/effective_api_base_url.dart';
import '../../core/storage/app_settings_controller.dart';
import '../../core/config/app_environment.dart';
import '../../shared/models/auth_models.dart';
import 'auth_controller.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  bool _registerMode = false;
  String? _lastShownErrorMessage;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AuthState>(
      authControllerProvider,
      (previous, next) {
        final message = next.errorMessage?.trim() ?? '';
        if (!mounted || message.isEmpty || message == _lastShownErrorMessage) {
          return;
        }

        _lastShownErrorMessage = message;
        _showMessage(message);
      },
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final environment = ref.watch(appEnvironmentProvider);
    final apiBaseUrl = ref.watch(
      appSettingsControllerProvider.select((state) => state.apiBaseUrlOverride),
    );
    final effectiveApiBaseUrl = ref.watch(effectiveApiBaseUrlProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE0F4EC),
              Color(0xFFF4F7F2),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Math Notebook',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: '用户名',
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_registerMode) ...[
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: '邮箱',
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: '密码',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed:
                                    authState.isSubmitting ? null : _submit,
                                child: Text(
                                  authState.isSubmitting
                                      ? '提交中...'
                                      : (_registerMode ? '注册并进入' : '登录'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if ((authState.errorMessage ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _AuthErrorMessage(message: authState.errorMessage!.trim()),
                        ],
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: authState.isSubmitting
                              ? null
                              : () {
                                  setState(() {
                                    _registerMode = !_registerMode;
                                  });
                                },
                          child: Text(
                            _registerMode ? '已有账号，去登录' : '没有账号，先注册',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '当前 API：$effectiveApiBaseUrl',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          apiBaseUrl.isEmpty
                              ? '默认来源：${environment.defaultApiBaseUrlSource}'
                              : '当前使用设置页覆盖地址',
                          style: Theme.of(context).textTheme.bodySmall,
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

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final email = _emailController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showMessage('请输入用户名和密码');
      return;
    }

    if (_registerMode && email.isEmpty) {
      _showMessage('注册模式下需要填写邮箱');
      return;
    }

    try {
      if (_registerMode) {
        await ref.read(authControllerProvider.notifier).register(
              RegisterPayload(
                username: username,
                password: password,
                email: email,
              ),
            );
      } else {
        await ref.read(authControllerProvider.notifier).login(
              LoginPayload(
                username: username,
                password: password,
              ),
            );
      }

      if (mounted) {
        _lastShownErrorMessage = null;
        context.go('/dashboard');
      }
    } catch (_) {}
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _AuthErrorMessage extends StatelessWidget {
  const _AuthErrorMessage({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
