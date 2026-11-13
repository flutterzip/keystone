import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/format.dart';
import '../../models/thread.dart';
import '../../providers/activity_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/photo.dart';
import '../actions.dart';

abstract final class MessageKeys {
  static Key thread(String id) => Key('thread-$id');
  static const field = Key('thread-field');
  static const send = Key('thread-send');
  static const typing = Key('thread-typing');
}

/// Conversations with agents. Tap opens one; swipe left deletes it, with an
/// undo. An unread thread carries a dot and heavier type, not colour alone.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final threads = ref.watch(threadsProvider).valueOrNull ?? const [];
    final shown = [
      for (final t in threads)
        if (t.messages.isNotEmpty) t,
    ];
    return SubPage(
      title: 'Messages',
      child: shown.isEmpty
          ? const Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'No messages yet',
                  message:
                      'Ask an agent a question from any home and the conversation is kept here.',
                ),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.only(
                top: Space.sm,
                bottom: media.padding.bottom + Sizes.tabBarReserve,
              ),
              itemCount: shown.length,
              itemBuilder: (context, i) => _ThreadRow(thread: shown[i]),
            ),
    );
  }
}

class _ThreadRow extends ConsumerWidget {
  const _ThreadRow({required this.thread});

  final MessageThread thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final agent = ref.watch(agentProvider(thread.agentId));
    final home = thread.homeId == null
        ? null
        : ref.watch(homeProvider(thread.homeId!));
    final now = ref.watch(nowProvider);
    final last = thread.last!;
    final unread = thread.unread > 0;
    final messenger = ScaffoldMessenger.of(context);
    return Dismissible(
      key: ValueKey(thread.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: p.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Delete', style: context.title.copyWith(color: p.onPhoto)),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: p.onPhoto, size: 20),
          ],
        ),
      ),
      onDismissed: (_) {
        final threads = ref.read(threadsProvider.notifier);
        threads.remove(thread.id);
        showToastOn(
          messenger,
          p,
          'Conversation deleted',
          icon: Icons.delete_outline_rounded,
          onUndo: () => threads.restore(thread),
        );
      },
      child: Semantics(
        button: true,
        label:
            '${agent?.name ?? 'Agent'}${unread ? ', unread' : ''}. ${last.fromMe ? 'You: ' : ''}${last.text}',
        excludeSemantics: true,
        child: InkWell(
          key: MessageKeys.thread(thread.id),
          onTap: () => openThread(context, thread.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.gutter,
              vertical: 13,
            ),
            child: Row(
              children: [
                PersonPhoto(
                  photo: agent?.photo ?? '',
                  name: agent?.name ?? '',
                  size: 50,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              agent?.name ?? 'Agent',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.title.copyWith(
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(agoLabel(last.at, now), style: context.caption),
                        ],
                      ),
                      if (home != null)
                        Text(
                          home.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.caption.copyWith(color: p.accentInk),
                        ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${last.fromMe ? 'You: ' : ''}${last.text}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.body.copyWith(
                                color: unread ? p.ink : p.muted,
                                fontWeight: unread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (unread) ...[
                            const SizedBox(width: 8),
                            Container(
                              key: Key('unread-${thread.id}'),
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: p.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
