import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
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
      } else {
        await _authService.signUp(
          email: _emailController.text,
          password: _passwordController.text,
        );
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
