import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keystone/providers/session_providers.dart';
import 'package:keystone/screens/auth/auth_screen.dart';
import 'package:keystone/screens/onboarding/onboarding_screen.dart';
import 'package:keystone/screens/home/home_tab.dart';
import 'package:keystone/widgets/social_buttons.dart';

import '../helpers.dart';

void main() {
  final seed = readSeed();
  setUpAll(quietMotion);

  Future<void> submit(WidgetTester t) =>
      tapVisible(t, find.byKey(AuthKeys.submit));

  testWidgets('sign in names what is missing instead of greying out', (
    t,
  ) async {
    phone(t);
    final (c, _) = await makeContainer(seed);
    await pumpScreen(t, c, const AuthScreen());
    expect(find.text('Welcome back'), findsOneWidget);
    await submit(t);
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    await t.enterText(find.byKey(AuthKeys.email), 'not-an-email');
    await t.enterText(find.byKey(AuthKeys.password), '123');
    await submit(t);
    expect(find.text("That email doesn't look right"), findsOneWidget);
    expect(find.text('Use at least 6 characters'), findsOneWidget);
    expect(c.read(sessionProvider), isNull);
  });

  testWidgets('the seeded wrong password shows its own sentence', (t) async {
    phone(t);
    final (c, _) = await makeContainer(seed);
    await pumpScreen(t, c, const AuthScreen());
    await t.enterText(find.byKey(AuthKeys.email), 'someone@example.com');
    await t.enterText(find.byKey(AuthKeys.password), 'wrongpass');
    await submit(t);
    expect(
      find.text('That password is not right. Try again or reset it.'),
      findsOneWidget,
    );
    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('any well-formed sign in lands on Home as the demo person', (
    t,
  ) async {
    phone(t);
    final (c, _) = await makeContainer(seed);
    await pumpScreen(t, c, const AuthScreen());
    await t.enterText(find.byKey(AuthKeys.email), 'Whoever@Example.com');
    await t.enterText(find.byKey(AuthKeys.password), 'anything');
    await submit(t);
    expect(find.byType(HomeTab), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
    expect(c.read(sessionProvider), 'whoever@example.com');
    final profile = c.read(profileProvider).value!;
    expect(profile.name, 'Olympicson');
    expect(profile.email, 'whoever@example.com');
  });

  testWidgets('sign up needs a name and the terms, then keeps the name', (
    t,
  ) async {
    phone(t);
    final (c, _) = await makeContainer(seed);
    await pumpScreen(t, c, const AuthScreen());
    await tapVisible(t, find.byKey(AuthKeys.toggle));
    expect(find.text('Create your account'), findsOneWidget);
    await t.enterText(find.byKey(AuthKeys.email), 'ada@example.com');
    await t.enterText(find.byKey(AuthKeys.password), 'longenough');
    await submit(t);
    expect(find.text('Tell us what to call you'), findsOneWidget);
    await t.enterText(find.byKey(AuthKeys.name), 'Ada Lovelace');
    await submit(t);
    expect(
      find.text('Agree to the terms to create your account.'),
      findsOneWidget,
    );
    await tapVisible(t, find.byKey(AuthKeys.terms));
    await submit(t);
    expect(find.byType(HomeTab), findsOneWidget);
    expect(c.read(profileProvider).value!.name, 'Ada Lovelace');
  });

  testWidgets('Apple and Google sit on both screens and sign in', (t) async {
    phone(t);
    final (c, _) = await makeContainer(seed);
    await pumpScreen(t, c, const AuthScreen());
    expect(find.byType(SocialButton), findsNWidgets(2));
    expect(find.text('or with email'), findsOneWidget);
    await tapVisible(t, find.byKey(AuthKeys.toggle));
    expect(find.byType(SocialButton), findsNWidgets(2));
    // A provider gives a name and an email, not consent.
    await tapVisible(t, find.byType(SocialButton).first);
    expect(
      find.text('Agree to the terms to create your account.'),
      findsOneWidget,
    );
    await tapVisible(t, find.byKey(AuthKeys.toggle));
    await tapVisible(t, find.byType(SocialButton).last);
    expect(find.byType(HomeTab), findsOneWidget);
    expect(c.read(sessionProvider), 'hello@flutterzip.com');
  });

  testWidgets('forgot password never says whether the email is registered', (
    t,
  ) async {
    phone(t);
    final (c, _) = await makeContainer(seed);
    await pumpScreen(t, c, const AuthScreen());
    await t.enterText(find.byKey(AuthKeys.email), 'nobody@example.com');
    await t.tap(find.text('Forgot password?'));
    await t.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
    await t.tap(find.text('Send reset link'));
    await t.pumpAndSettle();
    expect(
      find.text(
        'If nobody@example.com has an account, a reset link is on its way.',
      ),
      findsOneWidget,
    );
    await t.tap(find.text('Back to sign in'));
    await t.pumpAndSettle();
    expect(find.text('Reset your password'), findsNothing);
  });

  testWidgets('the form fits a small phone at large text', (t) async {
    phone(t, size: const Size(360, 640));
    final (c, _) = await makeContainer(seed);
    t.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpScreen(t, c, const AuthScreen(mode: AuthMode.signUp));
    expect(t.takeException(), isNull);
  });

  group('onboarding', () {
    testWidgets('three slides, then sign in, and it is remembered', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed);
      await pumpScreen(t, c, const OnboardingScreen());
      expect(find.text('Search your way'), findsOneWidget);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(find.text('Book viewings in a tap'), findsOneWidget);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(find.text('Sign from your phone'), findsOneWidget);
      expect(find.text('TENANCY AGREEMENT'), findsOneWidget);
      await t.tap(find.text('Get started'));
      await t.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(c.read(onboardedProvider), isTrue);
    });

    testWidgets('can be skipped, and follows a drag back', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed);
      await pumpScreen(t, c, const OnboardingScreen());
      await t.drag(find.byType(PageView), const Offset(-300, 0));
      await t.pumpAndSettle();
      expect(find.text('Book viewings in a tap'), findsOneWidget);
      await t.drag(find.byType(PageView), const Offset(300, 0));
      await t.pumpAndSettle();
      expect(find.text('Search your way'), findsOneWidget);
      await t.tap(find.text('Skip'));
      await t.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
    });
  });
}
