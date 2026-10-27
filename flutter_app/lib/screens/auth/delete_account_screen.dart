import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

/// Ava 12-delete-account: settings (entry) is the caller's "Delete account"
/// button elsewhere in Settings; this screen covers reauth / confirm /
/// deleting / error / deleted. Apple 5.1.1(v): fully in-app, re-auth first,
/// consequences spelled out before the destructive action.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

enum _Step { reauth, confirm, deleting, deleted }

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  _Step _step = _Step.reauth;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _onReauthSubmit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _step = _Step.confirm; _errorMessage = null; });
  }

  Future<void> _onConfirmDelete() async {
    setState(() { _step = _Step.deleting; _isLoading = true; _errorMessage = null; });
    try {
      await ref.read(authNotifierProvider.notifier).deleteAccount(_passwordController.text);
      if (!mounted) return;
      setState(() => _step = _Step.deleted);
    } on PatientAuthException catch (e) {
      setState(() {
        _step = _Step.reauth;
        _errorMessage = e.code == 'reauth_failed'
            ? 'That password is incorrect.'
            : 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nc = context.nc;

    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(color: BrandColors.red500)),
                const SizedBox(height: 16),
              ],
              if (_step == _Step.reauth) ..._reauthContent(nc),
              if (_step == _Step.confirm) ..._confirmContent(nc),
              if (_step == _Step.deleting) ...[
                const SizedBox(height: 48),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_step == _Step.deleted) ..._deletedContent(nc),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _reauthContent(BrandThemeColors nc) {
    return [
      Text('Confirm it\'s you',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: nc.textPrimary)),
      const SizedBox(height: 8),
      Text('Enter your current password to continue.', style: TextStyle(color: nc.textSecondary)),
      const SizedBox(height: 24),
      Form(
        key: _formKey,
        child: TextFormField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Current password'),
          validator: (value) =>
              (value == null || value.isEmpty) ? 'Please enter your password' : null,
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(onPressed: _onReauthSubmit, child: const Text('Continue')),
      ),
    ];
  }

  List<Widget> _confirmContent(BrandThemeColors nc) {
    return [
      Text('Delete your account?',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: nc.textPrimary)),
      const SizedBox(height: 16),
      Text(
        'This deletes your Zyndio app account and app data, and signs you out of every '
        'device. Your clinic records stay with your clinic - deleting this account does '
        'not cancel your care program.',
        style: TextStyle(color: nc.textSecondary),
      ),
      const SizedBox(height: 8),
      Text(
        'You will get a confirmation email once this is done.',
        style: TextStyle(color: nc.textSecondary),
      ),
      const SizedBox(height: 32),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _isLoading ? null : _onConfirmDelete,
          style: OutlinedButton.styleFrom(
            foregroundColor: BrandColors.red500,
            side: const BorderSide(color: BrandColors.red500),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Delete my account'),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Keep my account'),
        ),
      ),
    ];
  }

  List<Widget> _deletedContent(BrandThemeColors nc) {
    return [
      Text('Account deleted',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: nc.textPrimary)),
      const SizedBox(height: 16),
      Text(
        'Your Zyndio app account has been deleted. Your clinic records stay with your '
        'clinic.',
        style: TextStyle(color: nc.textSecondary),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => context.go('/login'),
          child: const Text('Done'),
        ),
      ),
    ];
  }
}
