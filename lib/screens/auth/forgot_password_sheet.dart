import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../providers/core_providers.dart';
import '../../widgets/app_field.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_button.dart';
import 'validators.dart';

Future<void> showForgotPasswordSheet(BuildContext context, {String? email}) =>
    showAppSheet(
      context,
      title: 'Reset your password',
      builder: (_) => _ForgotSheet(email: email ?? ''),
    );

class _ForgotSheet extends ConsumerStatefulWidget {
  const _ForgotSheet({required this.email});

  final String email;

  @override
  ConsumerState<_ForgotSheet> createState() => _ForgotSheetState();
}

class _ForgotSheetState extends ConsumerState<_ForgotSheet> {
  late final _email = TextEditingController(text: widget.email);
  String? _error;
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final error = validateEmail(_email.text);
    setState(() => _error = error);
    if (error != null) return;
    setState(() => _busy = true);
    final repo = await ref.read(authRepositoryProvider.future);
    await repo.sendPasswordReset(_email.text);
    if (mounted) {
      setState(() {
        _busy = false;
        _sent = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _sent
            ? [
                // The same sentence whether or not the address has an
                // account: anything else would say which emails are
                // registered.
                Notice(
                  'If ${_email.text.trim()} has an account, a reset link is on its way.',
                  icon: Icons.mark_email_read_outlined,
                ),
                const SizedBox(height: Space.xl),
                PrimaryButton(
                  label: 'Back to sign in',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]
            : [
                Text(
                  'Enter the email you signed up with and we will send a link.',
                  style: context.body,
                ),
                const SizedBox(height: Space.xl),
                AppField(
                  label: 'Email',
                  controller: _email,
                  hint: 'you@example.com',
                  icon: Icons.mail_outline_rounded,
                  error: _error,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _send(),
                ),
                const SizedBox(height: Space.xl),
                PrimaryButton(
                  label: 'Send reset link',
                  busy: _busy,
                  onPressed: _send,
                ),
              ],
      ),
    );
  }
}
