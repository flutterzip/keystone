import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keystone/kit/kit.dart';

import '../../config/app_theme.dart';
import '../../config/motion.dart';
import '../../providers/activity_providers.dart';
import '../../widgets/save_flight.dart';
import '../actions.dart';
import '../home/home_tab.dart';
import '../profile/profile_tab.dart';
import '../saved/saved_tab.dart';
import '../splash/splash_overlay.dart';
import '../viewings/viewings_tab.dart';

enum ShellTab {
  home('Home', Icons.home_rounded),
  saved('Saved', Icons.favorite_rounded),
  viewings('Viewings', Icons.event_rounded),
  profile('You', Icons.person_rounded);

  const ShellTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

final shellTabProvider = StateProvider<ShellTab>((_) => ShellTab.home);

/// One navigator per tab. Pages pushed from a tab (a home, a thread, an
/// application) open inside it, so the glass bar stays, the Saved tab is
/// always there for a home to fly into, and each tab keeps its own history.
final tabNavigatorKeys = {
  for (final t in ShellTab.values)
    t: GlobalKey<NavigatorState>(debugLabel: 'tab-${t.name}'),
};

/// The navigator of the tab on screen. Use it from anywhere, including a
/// sheet that lives on the root navigator, to open a page within the shell.
NavigatorState tabNavigator(BuildContext context) {
  final tab = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(shellTabProvider);
  return tabNavigatorKeys[tab]!.currentState ?? Navigator.of(context);
}

/// Home, Saved, Viewings and You, under a floating glass tab bar whose
/// separate pane is Messages.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  /// Tabs are built the first time they are opened, then kept.
  final _visited = <ShellTab>{};
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: Motion.entrance);
    startWhenRevealed(ref, _enter.forward);
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  static Widget _page(ShellTab t) => switch (t) {
    ShellTab.home => const HomeTab(),
    ShellTab.saved => const SavedTab(),
    ShellTab.viewings => const ViewingsTab(),
    ShellTab.profile => const ProfileTab(),
  };

  Widget _tab(ShellTab t) {
    final key = tabNavigatorKeys[t]!;
    // Android back and the iOS edge swipe pop inside the tab first.
    return NavigatorPopHandler<Object?>(
      onPopWithResult: (_) => key.currentState?.maybePop(),
      child: Navigator(
        key: key,
        // Nested navigators need their own controller for Heroes to fly.
        observers: [HeroController()],
        onGenerateRoute: (settings) =>
            MaterialPageRoute(settings: settings, builder: (_) => _page(t)),
      ),
    );
  }

  void _select(int index) =>
      ref.read(shellTabProvider.notifier).state = ShellTab.values[index];

  /// Tapping the tab you are on goes back to its first page.
  void _reselect(int index) => tabNavigatorKeys[ShellTab.values[index]]!
      .currentState
      ?.popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tab = ref.watch(shellTabProvider);
    final unread = ref.watch(unreadCountProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    _visited.add(tab);
    final rise = CurvedAnimation(
      parent: _enter,
      curve: const Interval(.35, 1, curve: Curves.easeOutCubic),
    );
    return Scaffold(
      // Pages handle the keyboard themselves; the bar never rides up on it.
      resizeToAvoidBottomInset: false,
      backgroundColor: p.paper,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: tab.index,
              children: [
                for (final t in ShellTab.values)
                  // Hidden tabs stay mounted; without this their pages would
                  // offer Heroes to a flight in another tab.
                  HeroMode(
                    enabled: t == tab,
                    child: _visited.contains(t)
                        ? _tab(t)
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: bottom + 10,
            child: FadeTransition(
              opacity: rise,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, .6),
                  end: Offset.zero,
                ).animate(rise),
                child: LayoutBuilder(
                  builder: (context, box) {
                    // Where the kit lays the tabs out: a bar beside the
                    // round action pane, the tabs sharing it equally.
                    const h = LiquidGlassTabBar.height;
                    final tabWidth =
                        (box.maxWidth - h - 12 - 12) / ShellTab.values.length;
                    final savedX = 6 + tabWidth * (ShellTab.saved.index + .5);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        LiquidGlassTabBar(
                          currentIndex: tab.index,
                          onChanged: _select,
                          onReselected: _reselect,
                          settings: LiquidGlassSettings(tint: p.glassTint),
                          items: [
                            for (final t in ShellTab.values)
                              GlassTabItem(icon: t.icon, label: t.label),
                          ],
                          action: Icons.chat_bubble_outline_rounded,
                          actionLabel: unread == 0
                              ? 'Messages'
                              : 'Messages, $unread unread',
                          onAction: () => openMessages(context),
                        ),
                        Positioned(
                          left: savedX - 22,
                          top: 4,
                          width: 44,
                          height: 44,
                          child: const IgnorePointer(child: _SavedTarget()),
                        ),
                        if (unread > 0)
                          Positioned(
                            right: 11,
                            top: 11,
                            child: IgnorePointer(child: _Badge(count: unread)),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sits over the Saved tab's icon: the point homes fly to. A brass ring
/// opens from it each time one lands.
class _SavedTarget extends StatelessWidget {
  const _SavedTarget();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.square(key: savedTargetKey, dimension: 24),
        ValueListenableBuilder<int>(
          valueListenable: savedLanded,
          builder: (context, landed, _) => landed == 0
              ? const SizedBox.shrink()
              : TweenAnimationBuilder<double>(
                  key: ValueKey(landed),
                  tween: Tween(begin: 0, end: 1),
                  duration: Motion.long,
                  curve: Curves.easeOut,
                  builder: (_, t, _) => Container(
                    width: 20 + 34 * t,
                    height: 20 + 34 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: p.accent.withValues(alpha: 1 - t),
                        width: 2.5 * (1 - t) + .5,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      key: const Key('messages-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: p.onAccent,
          fontSize: 10.5,
          height: 1.1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
