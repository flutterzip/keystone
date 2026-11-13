import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/application.dart';
import '../../providers/activity_providers.dart';
import '../../providers/browse_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/media_providers.dart';
import '../../providers/reset.dart';
import '../../providers/session_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../actions.dart';
import '../application/application_screen.dart';
import '../auth/auth_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../shell/main_shell.dart';
import 'avatar_sheet.dart';
import 'documents_screen.dart';
import 'edit_profile_sheet.dart';
import 'key_card.dart';
import 'saved_searches_screen.dart';

abstract final class ProfileKeys {
  static const edit = Key('profile-edit');
  static const applications = Key('profile-applications');
  static const searches = Key('profile-searches');
  static const documents = Key('profile-documents');
  static const messages = Key('profile-messages');
  static const reset = Key('profile-reset');
  static const signOut = Key('profile-sign-out');
}

/// You: photo and details, the resident key card, applications, saved
/// searches, documents, appearance, and the way out.
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  /// Leaves the shell for [page]. The shell stays alive under the
  /// cross-fade and [then] runs once it has gone, so nothing blanks
  /// mid-flight.
  static Future<void> _leave(
    BuildContext context,
    Widget page,
    Future<void> Function(ProviderContainer) then,
  ) async {
    // The page's own ref is disposed with it: act through the container.
    final container = ProviderScope.containerOf(context, listen: false);
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushReplacement(handOffRoute(page));
    await Future<void>.delayed(
      Motion.handOff + const Duration(milliseconds: 50),
    );
    await then(container);
    container.read(shellTabProvider.notifier).state = ShellTab.home;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final now = ref.watch(nowProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final applications =
        ref.watch(applicationsProvider).valueOrNull ?? const <Application>[];
    final live = applications.where((a) => !a.withdrawn).length;
    final due = applications.where((a) => a.depositDue(now)).length;
    final searches = ref.watch(savedSearchesProvider).valueOrNull?.length ?? 0;
    final documents = ref.watch(documentsProvider).valueOrNull?.length ?? 0;
    final unread = ref.watch(unreadCountProvider);
    final hasPhoto =
        (profile?.avatar.isNotEmpty ?? false) ||
        ref.watch(pendingAvatarProvider) != null;

    void push(Widget page) => tabNavigator(context).push(tabRoute(page));
    String count(int n) => n == 0 ? 'None yet' : '$n';

    return TabPage(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          media.padding.top + Space.lg,
          Space.gutter,
          media.padding.bottom + Sizes.tabBarReserve,
        ),
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Change profile photo',
                child: GestureDetector(
                  key: AvatarKeys.avatar,
                  onTap: () => showAvatarSheet(context, hasPhoto: hasPhoto),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Avatar(profile: profile, size: 76),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: p.ink,
                            shape: BoxShape.circle,
                            border: Border.all(color: p.paper, width: 2),
                          ),
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: 14,
                            color: p.paper,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.display.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      profile?.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.caption,
                    ),
                    if (profile?.phone.isNotEmpty ?? false)
                      Text(
                        profile!.phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.caption,
                      ),
                  ],
                ),
              ),
              RoundIcon(
                key: ProfileKeys.edit,
                icon: Icons.edit_outlined,
                label: 'Edit your details',
                onTap: profile == null
                    ? null
                    : () => showEditProfileSheet(context, profile),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          if (profile != null) KeyCard(profile: profile),
          const SizedBox(height: Space.xl),
          _Group(
            children: [
              _Row(
                key: ProfileKeys.applications,
                icon: Icons.assignment_outlined,
                label: 'Applications and offers',
                value: due > 0 ? 'Deposit due' : count(live),
                flag: due > 0,
                onTap: () => push(
                  ApplicationsScreen(
                    onOpen: (home) => openApplication(context, home),
                  ),
                ),
              ),
              _Row(
                key: ProfileKeys.messages,
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Messages',
                value: unread == 0 ? null : '$unread unread',
                flag: unread > 0,
                onTap: () => openMessages(context),
              ),
              _Row(
                key: ProfileKeys.searches,
                icon: Icons.notifications_none_rounded,
                label: 'Saved searches',
                value: count(searches),
                onTap: () => push(const SavedSearchesScreen()),
              ),
              _Row(
                key: ProfileKeys.documents,
                icon: Icons.folder_outlined,
                label: 'Documents',
                value: count(documents),
                onTap: () => push(const DocumentsScreen()),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          Text('APPEARANCE', style: context.label.copyWith(color: p.muted)),
          const SizedBox(height: Space.md),
          Segmented<ThemeMode>(
            values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
            labelOf: (m) => switch (m) {
              ThemeMode.system => 'Auto',
              ThemeMode.light => 'Light',
              ThemeMode.dark => 'Dark',
            },
            value: ref.watch(themeModeProvider),
            keyPrefix: 'appearance',
            onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
          ),
          const SizedBox(height: Space.xl),
          _Group(
            children: [
              _Row(
                key: ProfileKeys.reset,
                icon: Icons.restart_alt_rounded,
                label: 'Reset demo data',
                onTap: () async {
                  final yes = await confirmRemove(
                    context,
                    title: 'Reset demo data?',
                    message:
                        'Your saved homes, viewings, messages, applications, documents and details go back to how they started, and you are signed out.',
                    action: 'Reset everything',
                  );
                  if (!yes || !context.mounted) return;
                  await _leave(
                    context,
                    const OnboardingScreen(),
                    resetDemoData,
                  );
                },
              ),
              _Row(
                key: ProfileKeys.signOut,
                icon: Icons.logout_rounded,
                label: 'Sign out',
                onTap: () {
                  HapticFeedback.selectionClick();
                  _leave(
                    context,
                    const AuthScreen(),
                    (c) => c.read(sessionProvider.notifier).signOut(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(color: p.line, indent: 52),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.flag = false,
  });

  final IconData icon;
  final String label;
  final String? value;

  /// Something here wants attention: the value is set in the accent with a
  /// dot before it.
  final bool flag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: value == null ? label : '$label, $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              const SizedBox(width: Space.lg),
              Icon(icon, size: 20, color: p.ink),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.title,
                ),
              ),
              if (flag) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: p.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (value != null)
                Text(
                  value!,
                  style: context.caption.copyWith(
                    color: flag ? p.accentInk : null,
                    fontWeight: flag ? FontWeight.w700 : null,
                  ),
                ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
              const SizedBox(width: Space.md),
            ],
          ),
        ),
      ),
    );
  }
}
