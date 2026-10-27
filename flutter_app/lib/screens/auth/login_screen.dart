import 'dart:io';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import 'widgets/auth_background.dart';

/// Login screen matching React Login.tsx
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).signIn(
            _emailController.text.trim(),
            _passwordController.text,
          );
    } catch (e) {
      setState(() {
        _errorMessage = _parseError(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _parseError(String error) {
    if (error.contains('SocketException') || 
        error.contains('host lookup') ||
        error.contains('No address associated')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (error.contains('TimeoutException') || error.contains('timed out')) {
      return 'Connection timed out. Please try again.';
    }
    if (error.contains('Invalid login credentials') || 
        error.contains('invalid_credentials')) {
      return 'Invalid email or password. Please try again.';
    }
    if (error.contains('Email not confirmed')) {
      return 'Please check your email and confirm your account.';
    }
    if (error.contains('rate limit') || error.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (error.contains('locked')) {
      return "Sign-in is paused for this account after several wrong attempts. "
          "Try again in 15 minutes, or reset your password.";
    }
    return error
        .replaceFirst('Exception: ', '')
        .replaceFirst('AuthException: ', '')
        .replaceAll(RegExp(r'AuthRetryableFetchException\(message: '), '')
        .replaceAll(RegExp(r'\)$'), '');
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    } catch (e) {
      if (!e.toString().contains('cancelled')) {
        setState(() {
          _errorMessage = _parseError(e.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).signInWithApple();
    } catch (e) {
      if (!e.toString().contains('cancelled')) {
        setState(() {
          _errorMessage = _parseError(e.toString());
        });
      }
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
                        // Toggle buttons
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: nc.navbarPillBg,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => context.go('/signup'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    'Sign up',
                                    style: TextStyle(
                                      color: nc.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: nc.cardSurfaceElevated,
                                    borderRadius: BorderRadius.circular(50),
                                    boxShadow: [
                                      BoxShadow(
                                        color: nc.shadowColor,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Sign in',
                                    style: TextStyle(
                                      color: nc.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Title
                        Text(
                          'Welcome back',
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
                            hintText: 'Enter your password',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.go('/forgot-password'),
                            child: Text(
                              'Forgot password?',
                              style: TextStyle(color: nc.textSecondary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Sign in button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignIn,
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
                                : const Text('Sign in'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: nc.divider)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'or',
                                style: TextStyle(color: nc.textTertiary, fontSize: 12),
                              ),
                            ),
                            Expanded(child: Divider(color: nc.divider)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Google Sign-In button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                            icon: Image.asset(
                              'assets/icons/google_logo.png',
                              height: 20,
                              width: 20,
                            ),
                            label: const Text('Continue with Google'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: nc.divider),
                              foregroundColor: nc.textPrimary,
                              backgroundColor: nc.cardSurfaceElevated,
                            ),
                          ),
                        ),
                        
                        if (Platform.isIOS) ...[
                          const SizedBox(height: 12),
                          // Apple Sign-In button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _handleAppleSignIn,
                              icon: Icon(Icons.apple, size: 20, color: isDark ? Colors.black : Colors.white),
                              label: const Text('Continue with Apple'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: isDark ? Colors.white : Colors.black),
                                foregroundColor: isDark ? Colors.black : Colors.white,
                                backgroundColor: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 32),

                        // Terms
                        Center(
                          child: Text(
                            'By signing in, you agree to our Terms & Service',
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
