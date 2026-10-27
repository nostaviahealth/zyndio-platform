import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/password_rules_checklist.dart';
import 'widgets/auth_background.dart';

/// Signup screen matching React Signup.tsx
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _submitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();

    try {
      // TC-012: patient self-signup goes through the patient-signup Edge
      // Function, never client.auth.signUp() directly ([auth] enable_signup
      // stays false). PSU-ENUM-01: on success we always navigate to "Check
      // your email" - the function itself hides whether the email was new.
      await ref.read(authNotifierProvider.notifier).patientSignUp(
            email,
            _passwordController.text,
          );
      if (!mounted) return;
      context.go('/verify-email', extra: email);
    } on PatientAuthException catch (e) {
      setState(() {
        _errorMessage = switch (e.code) {
          'password_too_common' => 'That password is too common. Choose another.',
          'password_too_short' => 'Your password needs to meet every rule below.',
          'rate_limited' => 'Too many attempts. Please wait a few minutes and try again.',
          'invalid_request' => 'Please enter a valid email address.',
          _ => 'Something went wrong. Please try again.',
        };
      });
    } catch (e) {
      final message = e.toString();
      _errorMessage = (message.contains('SocketException') || message.contains('host lookup'))
          ? 'No internet connection. Please check your network and try again.'
          : message.replaceFirst('Exception: ', '');
      setState(() {});
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final nc = context.nc;
    final isDark = context.isDarkMode;

    return AuthBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  decoration: BoxDecoration(
                    color: nc.cardSurface.withOpacity(isDark ? 0.4 : 0.9),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: nc.cardBorder.withOpacity(isDark ? 0.1 : 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: nc.shadowColor,
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                       ),
                    ],
                  ),
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        Text(
                          'Create account',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: nc.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 32),

                        // Error message
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: BrandColors.red500.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.alertCircle,
                                  size: 16,
                                  color: BrandColors.red500,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: BrandColors.red500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Name field
                        TextFormField(
                          controller: _nameController,
                          style: TextStyle(color: nc.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Enter your name',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: nc.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Enter your email',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          style: TextStyle(color: nc.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Create a password',
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            final checks = checkPasswordRules(value ?? '');
                            return checks.allClientRulesMet
                                ? null
                                : 'Your password needs to meet every rule below';
                          },
                        ),
                        const SizedBox(height: 8),
                        PasswordRulesChecklist(
                          password: _passwordController.text,
                          showInvalid: _submitted,
                        ),
                        const SizedBox(height: 16),

                        // Sign up button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignUp,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: isDark ? Colors.white : BrandColors.dark,
                              foregroundColor: isDark ? Colors.black : Colors.white,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: isDark ? Colors.black : Colors.white,
                                    ),
                                  )
                                : const Text('Create account'),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Terms
                        Center(
                          child: Text(
                            'By signing up, you agree to our Terms & Service',
                            style: TextStyle(
                              fontSize: 12,
                              color: nc.textTertiary,
                            ),
                            textAlign: TextAlign.center,
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
