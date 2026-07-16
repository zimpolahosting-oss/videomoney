import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/app_language_service.dart';
import '../../services/auth_service.dart';
import '../../services/remember_me_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _restoreRememberMe();
  }

  Future<void> _restoreRememberMe() async {
    final enabled = await RememberMeService.instance.isEnabled();
    final creds = enabled ? await RememberMeService.instance.readCredentials() : null;
    if (!mounted) return;

    setState(() => _rememberMe = enabled);
    if (creds != null) {
      _emailController.text = creds.email;
      _passwordController.text = creds.password;

      // If Firebase doesn't restore the session automatically, try to sign in
      // silently (only when user explicitly enabled "remember me").
      if (FirebaseAuth.instance.currentUser == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_attemptAutoLogin());
        });
      }
    }
  }

  Future<void> _attemptAutoLogin() async {
    if (_isLoading || !_rememberMe) return;
    final l10n = context.l10n;
    final creds = await RememberMeService.instance.readCredentials();
    if (creds == null) return;

    setState(() => _isLoading = true);
    try {
      await _authService.signIn(email: creds.email, password: creds.password);
    } on FirebaseAuthException catch (error) {
      await RememberMeService.instance.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? l10n.authenticationFailed)),
      );
    } catch (_) {
      await RememberMeService.instance.clear();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _authService.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );

        if (_rememberMe) {
          await RememberMeService.instance.setEnabled(true);
          await RememberMeService.instance.saveCredentials(
            email: _emailController.text,
            password: _passwordController.text,
          );
        } else {
          await RememberMeService.instance.clear();
        }
      } else {
        await _authService.signUp(
          email: _emailController.text,
          password: _passwordController.text,
        );

        // Default to remembering the account if the user explicitly opted in.
        if (_rememberMe) {
          await RememberMeService.instance.setEnabled(true);
          await RememberMeService.instance.saveCredentials(
            email: _emailController.text,
            password: _passwordController.text,
          );
        }
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? l10n.authenticationFailed)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    final l10n = context.l10n;

    try {
      await _authService.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.passwordResetEmailSent(email),
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? l10n.unableSendResetEmail)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _showPasswordResetDialog() async {
    final emailController = TextEditingController(text: _emailController.text);
    final l10n = context.l10n;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.resetPassword),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: l10n.email,
              hintText: l10n.emailHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                _emailController.text = emailController.text;
                Navigator.of(dialogContext).pop();
                await _sendPasswordReset();
              },
              child: Text(l10n.sendResetLink),
            ),
          ],
        );
      },
    );

    emailController.dispose();
  }

  String _currentLanguageLabel() {
    final currentCode = AppLanguageService.instance.selectedLanguageCode;
    for (final option in AppLanguageService.instance.supportedLanguageOptions) {
      if (option.code == currentCode) {
        return option.label;
      }
    }
    return 'English';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF07120D),
              Color(0xFF030806),
              Color(0xFF020503),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.06),
                        Colors.white.withOpacity(0.02),
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.outline.withOpacity(0.9),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.10),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: PopupMenuButton<String>(
                              tooltip: l10n.appLanguage,
                              onSelected: (value) async {
                                await AppLanguageService.instance
                                    .setPreferredLanguageCode(value);
                                if (mounted) {
                                  setState(() {});
                                }
                              },
                              itemBuilder: (context) {
                                final selectedCode = AppLanguageService
                                    .instance
                                    .selectedLanguageCode;
                                return AppLanguageService.instance
                                    .supportedLanguageOptions
                                    .map(
                                      (option) => PopupMenuItem<String>(
                                        value: option.code,
                                        child: Row(
                                          children: [
                                            Icon(
                                              selectedCode == option.code
                                                  ? Icons.radio_button_checked
                                                  : Icons.radio_button_off,
                                              size: 18,
                                              color: AppTheme.primarySoft,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                option.label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(growable: false);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.outline.withOpacity(0.7),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.language_outlined,
                                      size: 18,
                                      color: AppTheme.primarySoft,
                                    ),
                                    const SizedBox(width: 8),
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 122),
                                      child: Text(
                                        _currentLanguageLabel(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: AppTheme.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Center(child: BrandLogo(height: 76)),
                          const SizedBox(height: 24),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: Column(
                              key: ValueKey<bool>(_isLogin),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isLogin ? l10n.welcomeBack : l10n.createYourAccount,
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _isLogin
                                      ? l10n.signInBody
                                      : l10n.signUpBody,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppTheme.outline.withOpacity(0.7),
                              ),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.system_update_alt_rounded,
                                  color: AppTheme.primarySoft,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'If videos do not start on your phone, update Android System WebView, Google Chrome and YouTube first.',
                                    style: TextStyle(
                                      color: AppTheme.textMuted,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppTheme.outline.withOpacity(0.7),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => setState(() => _isLogin = true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _isLogin
                                          ? AppTheme.primary
                                          : Colors.transparent,
                                      foregroundColor: _isLogin
                                          ? const Color(0xFF04110A)
                                          : Colors.white,
                                      elevation: 0,
                                    ),
                                    child: Text(l10n.login),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => setState(() => _isLogin = false),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: !_isLogin
                                          ? AppTheme.primary
                                          : Colors.transparent,
                                      foregroundColor: !_isLogin
                                          ? const Color(0xFF04110A)
                                          : Colors.white,
                                      elevation: 0,
                                    ),
                                    child: Text(l10n.signUp),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: l10n.email,
                              hintText: l10n.emailHint,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return l10n.enterYourEmail;
                              }
                              if (!value.contains('@')) {
                                return l10n.enterValidEmail;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: l10n.password,
                              hintText: l10n.useAtLeast6Chars,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return l10n.enterYourPassword;
                              }
                              if (value.trim().length < 6) {
                                return l10n.useAtLeast6Chars;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: _isLoading
                                    ? null
                                    : (value) async {
                                        final enabled = value ?? false;
                                        setState(() => _rememberMe = enabled);
                                        if (!enabled) {
                                          await RememberMeService.instance.clear();
                                        } else {
                                          await RememberMeService.instance.setEnabled(true);
                                        }
                                      },
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l10n.rememberMe,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          if (_isLogin) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed:
                                    _isLoading ? null : _showPasswordResetDialog,
                                child: Text(l10n.forgotPassword),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: AppTheme.outline.withOpacity(0.6),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified_user_outlined,
                                  color: AppTheme.primarySoft,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.firebaseAuthNotice,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _submit,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _isLogin ? l10n.login : l10n.createAccount,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: Text(
                              _isLogin
                                  ? l10n.secureAccessDashboard
                                  : l10n.firestoreBalanceStored,
                              style: Theme.of(context).textTheme.bodyMedium,
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
      ),
    );
  }
}
