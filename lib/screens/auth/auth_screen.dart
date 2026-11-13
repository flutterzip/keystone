import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../config/app_brand.dart';
import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/account.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_providers.dart';
import '../../services/auth_repository.dart';
import '../../widgets/ambient.dart';
import '../../widgets/keystone_mark.dart';
import '../../widgets/app_field.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/social_buttons.dart';
import '../shell/main_shell.dart';
import '../splash/splash_overlay.dart';
import 'forgot_password_sheet.dart';
import 'validators.dart';

enum AuthMode { signIn, signUp }

/// Keys for the auth form, so tests and the screen cannot drift.
abstract final class AuthKeys {
  static const name = Key('auth-name');
  static const email = Key('auth-email');
  static const password = Key('auth-password');
  static const submit = Key('auth-submit');
  static const terms = Key('auth-terms');
  static const toggle = Key('auth-toggle');
}

/// Sign in and sign up, as one page with two states. Apple and Google sit
/// above the form on both.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.mode = AuthMode.signIn});

  final AuthMode mode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late AuthMode _mode = widget.mode;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final AnimationController _enter;

  String? _nameError, _emailError, _passwordError, _formError;
  bool _terms = false;

  /// Which action is in flight: 'email', 'apple' or 'google'. That one shows
  /// the loader; the others are held.
  String? _pending;

  bool get _signUp => _mode == AuthMode.signUp;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: Motion.entrance);
    startWhenRevealed(ref, _enter.forward);
  }

  @override
  void dispose() {
    _enter.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _mode = _signUp ? AuthMode.signIn : AuthMode.signUp;
      _nameError = _emailError = _passwordError = _formError = null;
    });
  }

  Future<void> _arrive(UserProfile profile, {required bool isNew}) async {
    await ref.read(sessionProvider.notifier).signedIn(profile.email);
    await ref.read(profileProvider.notifier).signedInAs(profile, isNew: isNew);
    if (!mounted) return;
    // pushReplacement keeps this page alive under the cross-fade.
    Navigator.of(context).pushReplacement(handOffRoute(const MainShell()));
  }

  Future<void> _run(String action, Future<UserProfile> Function() work) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _pending = action;
      _formError = null;
    });
    try {
      final profile = await work();
      await _arrive(profile, isNew: _signUp && action == 'email');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _formError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _formError = 'Something went wrong. Try again.');
      }
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  /// The button never greys out: pressing it with something missing says
  /// what, on the field it belongs to.
  bool _validate() {
    setState(() {
      _nameError = _signUp ? validateName(_name.text) : null;
      _emailError = validateEmail(_email.text);
      _passwordError = validatePassword(_password.text);
      _formError =
          _signUp &&
              !_terms &&
              _nameError == null &&
              _emailError == null &&
              _passwordError == null
          ? 'Agree to the terms to create your account.'
          : null;
    });
    return _nameError == null &&
        _emailError == null &&
        _passwordError == null &&
        _formError == null;
  }

  Future<void> _submit() async {
    if (_pending != null || !_validate()) return;
    final repo = await ref.read(authRepositoryProvider.future);
    await _run(
      'email',
      () => _signUp
          ? repo.signUp(
              name: _name.text,
              email: _email.text,
              password: _password.text,
            )
          : repo.signIn(email: _email.text, password: _password.text),
    );
  }

  Future<void> _social(SocialProvider provider) async {
    if (_pending != null) return;
    // The provider supplies a name and an email, not consent.
    if (_signUp && !_terms) {
      setState(() => _formError = 'Agree to the terms to create your account.');
      return;
    }
    final repo = await ref.read(authRepositoryProvider.future);
    await _run(provider.name, () => repo.signInWith(provider));
  }

  Widget _rise(double from, Widget child) {
    final a = CurvedAnimation(
      parent: _enter,
      curve: Interval(from, (from + .55).clamp(0, 1), curve: Motion.enter),
    );
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .08),
          end: Offset.zero,
        ).animate(a),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final busy = _pending != null;
    return Scaffold(
      backgroundColor: p.paper,
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: AmbientMesh(),
          ),
          SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(bottom: media.padding.bottom + Space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: media.padding.top + 14),
                const Center(child: KeystoneMark(size: 52)),
                const Center(child: Wordmark(size: 22)),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    AppBrand.tagline,
                    style: context.caption.copyWith(color: p.inkSoft),
                  ),
                ),
                const SizedBox(height: 34),
                // The form is a sheet of paper cut into the gradient.
                Container(
                  decoration: BoxDecoration(
                    color: p.paper,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(Radii.xl + 6),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.xxl,
                    Space.gutter,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _rise(
                        0,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _signUp ? 'Create your account' : 'Welcome back',
                              style: context.display,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _signUp
                                  ? 'Save homes, book viewings and apply from your phone.'
                                  : 'Sign in to your saved homes, viewings and messages.',
                              style: context.body,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.xl),
                      _rise(
                        .1,
                        Row(
                          children: [
                            Expanded(
                              child: SocialButton(
                                provider: SocialProvider.apple,
                                busy: _pending == 'apple',
                                onPressed: busy && _pending != 'apple'
                                    ? null
                                    : () => _social(SocialProvider.apple),
                              ),
                            ),
                            const SizedBox(width: Space.md),
                            Expanded(
                              child: SocialButton(
                                provider: SocialProvider.google,
                                busy: _pending == 'google',
                                onPressed: busy && _pending != 'google'
                                    ? null
                                    : () => _social(SocialProvider.google),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.xl),
                      _rise(
                        .16,
                        Row(
                          children: [
                            Expanded(child: Divider(color: p.line)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.md,
                              ),
                              child: Text(
                                'or with email',
                                style: context.caption,
                              ),
                            ),
                            Expanded(child: Divider(color: p.line)),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.xl),
                      _rise(.22, _fields(context)),
                      const SizedBox(height: Space.lg),
                      if (_formError != null) ...[
                        Notice(_formError!, error: true),
                        const SizedBox(height: Space.md),
                      ],
                      _rise(
                        .3,
                        KeyedSubtree(
                          key: AuthKeys.submit,
                          child: PrimaryButton(
                            label: _signUp ? 'Create account' : 'Sign in',
                            busy: _pending == 'email',
                            onPressed: busy && _pending != 'email'
                                ? null
                                : _submit,
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.xl),
                      _rise(
                        .36,
                        Center(
                          // A Wrap: at large text sizes the pair is wider
                          // than a narrow phone.
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _signUp
                                    ? 'Already have an account?'
                                    : 'New to ${AppBrand.name}?',
                                style: context.body,
                              ),
                              TextButton(
                                key: AuthKeys.toggle,
                                onPressed: busy ? null : _switchMode,
                                style: TextButton.styleFrom(
                                  foregroundColor: p.accentInk,
                                  textStyle: const TextStyle(
                                    fontFamily: AppTheme.font,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                child: Text(
                                  _signUp ? 'Sign in' : 'Create an account',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fields(BuildContext context) {
    final p = context.palette;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: Motion.short,
            curve: Motion.settle,
            alignment: Alignment.topCenter,
            child: _signUp
                ? Padding(
                    padding: const EdgeInsets.only(bottom: Space.lg),
                    child: AppField(
                      fieldKey: AuthKeys.name,
                      label: 'Name',
                      controller: _name,
                      hint: 'What should we call you?',
                      icon: Icons.person_outline_rounded,
                      error: _nameError,
                      capitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      onBlur: () => setState(
                        () => _nameError = _name.text.isEmpty
                            ? null
                            : validateName(_name.text),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          AppField(
            fieldKey: AuthKeys.email,
            label: 'Email',
            controller: _email,
            hint: 'you@example.com',
            icon: Icons.mail_outline_rounded,
            error: _emailError,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            // Checked on leaving the field, never on each keystroke.
            onBlur: () => setState(
              () => _emailError = _email.text.isEmpty
                  ? null
                  : validateEmail(_email.text),
            ),
          ),
          const SizedBox(height: Space.lg),
          AppField(
            fieldKey: AuthKeys.password,
            label: 'Password',
            controller: _password,
            hint: _signUp ? 'At least 6 characters' : 'Your password',
            icon: Icons.lock_outline_rounded,
            error: _passwordError,
            obscure: true,
            textInputAction: TextInputAction.done,
            autofillHints: [
              _signUp ? AutofillHints.newPassword : AutofillHints.password,
            ],
            onSubmitted: (_) => _submit(),
            trailing: _signUp
                ? null
                : TextButton(
                    onPressed: () =>
                        showForgotPasswordSheet(context, email: _email.text),
                    style: TextButton.styleFrom(
                      foregroundColor: p.accentInk,
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      textStyle: const TextStyle(
                        fontFamily: AppTheme.font,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    child: const Text('Forgot password?'),
                  ),
          ),
          if (_signUp) ...[
            const SizedBox(height: Space.md),
            Semantics(
              checked: _terms,
              label: 'I agree to the terms and the privacy policy',
              excludeSemantics: true,
              child: InkWell(
                key: AuthKeys.terms,
                borderRadius: BorderRadius.circular(Radii.sm),
                onTap: () => setState(() {
                  _terms = !_terms;
                  if (_terms) _formError = null;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: Motion.quick,
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _terms ? p.accent : null,
                          border: Border.all(
                            color: _terms ? p.accent : p.muted,
                            width: 1.4,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: _terms
                            ? Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: p.onAccent,
                              )
                            : null,
                      ),
                      const SizedBox(width: Space.md),
                      Flexible(
                        child: Text(
                          'I agree to the terms and the privacy policy',
                          style: context.body,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
