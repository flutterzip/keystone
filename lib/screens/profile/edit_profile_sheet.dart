import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_timing.dart';
import '../../config/design_tokens.dart';
import '../../models/account.dart';
import '../../providers/session_providers.dart';
import '../../widgets/app_field.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_button.dart';
import '../auth/validators.dart';

abstract final class EditProfileKeys {
  static const name = Key('edit-name');
  static const email = Key('edit-email');
  static const phone = Key('edit-phone');
  static const save = Key('edit-save');
}

Future<void> showEditProfileSheet(BuildContext context, UserProfile profile) =>
    showAppSheet(
      context,
      title: 'Your details',
      builder: (_) => _EditProfile(profile: profile),
    );

class _EditProfile extends ConsumerStatefulWidget {
  const _EditProfile({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends ConsumerState<_EditProfile> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _email = TextEditingController(text: widget.profile.email);
  late final _phone = TextEditingController(text: widget.profile.phone);
  String? _nameError, _emailError, _phoneError, _problem;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phone = _phone.text.trim();
    setState(() {
      _nameError = validateName(_name.text);
      _emailError = validateEmail(_email.text);
      _phoneError =
          phone.isNotEmpty && phone.replaceAll(RegExp(r'\D'), '').length < 7
          ? 'That number looks too short'
          : null;
      _problem = null;
    });
    if (_nameError != null || _emailError != null || _phoneError != null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await AppTiming.atLeast(
        AppTiming.saveForm,
        ref
            .read(profileProvider.notifier)
            .save(
              widget.profile.copyWith(
                name: _name.text.trim(),
                email: _email.text.trim().toLowerCase(),
                phone: phone,
              ),
            ),
      );
      // The email is who is signed in: keep the session in step with it.
      await ref
          .read(sessionProvider.notifier)
          .signedIn(_email.text.trim().toLowerCase());
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = 'Could not save your details. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.sm,
        Space.gutter,
        Space.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(
            fieldKey: EditProfileKeys.name,
            label: 'Name',
            controller: _name,
            hint: 'Your name',
            icon: Icons.person_outline_rounded,
            error: _nameError,
            capitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: Space.lg),
          AppField(
            fieldKey: EditProfileKeys.email,
            label: 'Email',
            controller: _email,
            hint: 'you@example.com',
            icon: Icons.mail_outline_rounded,
            error: _emailError,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: Space.lg),
          AppField(
            fieldKey: EditProfileKeys.phone,
            label: 'Phone',
            controller: _phone,
            hint: 'For delivery updates',
            icon: Icons.phone_outlined,
            error: _phoneError,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          if (_problem != null) ...[
            const SizedBox(height: Space.md),
            Notice(_problem!, error: true),
          ],
          const SizedBox(height: Space.xl),
          KeyedSubtree(
            key: EditProfileKeys.save,
            child: PrimaryButton(
              label: 'Save details',
              busy: _busy,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}
