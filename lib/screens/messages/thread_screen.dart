import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/format.dart';
import '../../models/thread.dart';
import '../../providers/activity_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/photo.dart';
import '../../widgets/primary_button.dart';
import '../actions.dart';
import 'messages_screen.dart';

/// One conversation: the messages, the agent typing, and a box to write in
/// that stays above the keyboard.
class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Opening a thread is what reads it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _read());
  }

  void _read() {
    if (!mounted) return;
    final t = ref.read(threadProvider(widget.threadId));
    if (t != null && t.unread > 0) {
      ref.read(threadsProvider.notifier).markRead(t.id);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _text.clear();
    try {
      await ref.read(threadsProvider.notifier).send(widget.threadId, text);
    } catch (_) {
      if (mounted) {
        _text.text = text;
        showToast(
          context,
          'That did not send. Try again.',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final thread = ref.watch(threadProvider(widget.threadId));
    // An answer that arrives while the thread is open is read at once.
    ref.listen(threadProvider(widget.threadId), (_, _) => _read());
    if (thread == null) {
      return const SubPage(title: 'Messages', child: SizedBox.shrink());
    }
    final agent = ref.watch(agentProvider(thread.agentId));
    final home = thread.homeId == null
        ? null
        : ref.watch(homeProvider(thread.homeId!));
    final typing = ref.watch(typingProvider).contains(thread.id);
    final now = ref.watch(nowProvider);
    final keyboard = media.viewInsets.bottom;
    // Newest at the bottom of a reversed list, so it stays in view.
    final messages = thread.messages.reversed.toList();

    return SubPage(
      title: agent?.name ?? 'Agent',
      trailing: PersonPhoto(
        photo: agent?.photo ?? '',
        name: agent?.name ?? '',
        size: 34,
      ),
      child: Column(
        children: [
          if (home != null)
            Semantics(
              button: true,
              label: 'About ${home.title}. Open the home',
              excludeSemantics: true,
              child: InkWell(
                onTap: () => openHome(context, home),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.gutter,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: p.card,
                    border: Border(bottom: BorderSide(color: p.line)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 44,
                          height: 36,
                          child: HomePhoto(home.cover, decodeWidth: 60),
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              home.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.title.copyWith(fontSize: 13.5),
                            ),
                            Text(
                              home.priceText,
                              maxLines: 1,
                              style: context.caption,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: p.muted),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: messages.isEmpty && !typing
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Space.xxl),
                      child: Text(
                        'Ask ${agent?.firstName ?? 'the agent'} anything about ${home?.title ?? 'this home'}.',
                        textAlign: TextAlign.center,
                        style: context.body,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      Space.lg,
                      Space.gutter,
                      Space.md,
                    ),
                    itemCount: messages.length + (typing ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (typing && i == 0) {
                        return Align(
                          key: MessageKeys.typing,
                          alignment: Alignment.centerLeft,
                          child: _Bubble(
                            mine: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: DotsLoader(color: p.muted, size: 6),
                            ),
                          ),
                        );
                      }
                      final m = messages[i - (typing ? 1 : 0)];
                      return _MessageRow(key: ValueKey(m.id), m: m, now: now);
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.sm,
              // Above the keyboard when it is up, above the glass bar when
              // it is not.
              keyboard > 0
                  ? keyboard + Space.sm
                  : media.padding.bottom + Sizes.tabBarReserve - 16,
            ),
            decoration: BoxDecoration(
              color: p.paper,
              border: Border(top: BorderSide(color: p.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 46),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: p.field,
                      borderRadius: BorderRadius.circular(Radii.xl),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      key: MessageKeys.field,
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: context.body.copyWith(color: p.ink, fontSize: 15),
                      cursorColor: p.accent,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Message ${agent?.firstName ?? ''}'.trim(),
                        hintStyle: context.body.copyWith(
                          color: p.muted,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _text,
                  builder: (context, value, _) {
                    final ready = value.text.trim().isNotEmpty;
                    return Semantics(
                      button: true,
                      enabled: ready,
                      label: ready ? 'Send' : 'Send. Write a message first',
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: MessageKeys.send,
                        behavior: HitTestBehavior.opaque,
                        onTap: ready ? _send : null,
                        child: SizedBox.square(
                          dimension: 50,
                          child: Center(
                            child: AnimatedContainer(
                              duration: Motion.quick,
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: ready ? p.primary : p.field,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_upward_rounded,
                                size: 20,
                                color: ready ? p.onPrimary : p.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({super.key, required this.m, required this.now});

  final Message m;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: m.fromMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          _Bubble(
            mine: m.fromMe,
            child: Text(
              m.text,
              style: context.body.copyWith(
                fontSize: 15,
                color: m.fromMe ? p.onPrimary : p.ink,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
            child: Text(
              dayOf(m.at) == dayOf(now)
                  ? timeLabel(m.at)
                  : '${dayLabel(m.at, now)}, ${timeLabel(m.at)}',
              style: context.caption.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.mine, required this.child});

  final bool mine;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const r = Radius.circular(20);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .76,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? p.primary : p.card,
          border: mine ? null : Border.all(color: p.line),
          borderRadius: BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: mine ? r : const Radius.circular(6),
            bottomRight: mine ? const Radius.circular(6) : r,
          ),
        ),
        child: child,
      ),
    );
  }
}
