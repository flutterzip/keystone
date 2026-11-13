import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import '../models/application.dart';
import '../models/home.dart';
import '../models/money.dart';
import '../models/thread.dart';
import '../models/viewing.dart';
import '../services/application_repository.dart';
import '../services/viewing_repository.dart';
import 'core_providers.dart';

/// Every viewing, soonest first. A write that fails rethrows, so the page
/// that asked stays open and says so.
class ViewingsNotifier extends AsyncNotifier<List<Viewing>> {
  @override
  Future<List<Viewing>> build() async =>
      (await ref.watch(viewingRepositoryProvider.future)).viewings();

  Future<Viewing> _after(
    Future<Viewing> Function(ViewingRepository repo) change,
  ) async {
    final repo = await ref.read(viewingRepositoryProvider.future);
    final v = await change(repo);
    state = AsyncData(await repo.viewings());
    return v;
  }

  Future<Viewing> book(String homeId, DateTime at, ViewingMode mode) =>
      _after((r) => r.book(homeId, at, mode));
  Future<Viewing> reschedule(String id, DateTime at) =>
      _after((r) => r.reschedule(id, at));
  Future<Viewing> cancel(String id) => _after((r) => r.cancel(id));
  Future<Viewing> restore(String id) => _after((r) => r.restore(id));
}

final viewingsProvider = AsyncNotifierProvider<ViewingsNotifier, List<Viewing>>(
  ViewingsNotifier.new,
);

/// The viewing that starts within the hour, or is under way.
final soonViewingProvider = Provider<Viewing?>((ref) {
  final now = ref.watch(nowProvider);
  for (final v
      in ref.watch(viewingsProvider).valueOrNull ?? const <Viewing>[]) {
    if (v.status(now) == ViewingStatus.soon) return v;
  }
  return null;
});

/// The times offered for a home on a day. `ignoring` is a viewing being
/// rescheduled.
typedef SlotQuery = ({String homeId, DateTime day, String? ignoring});

final slotsProvider = FutureProvider.autoDispose.family<List<Slot>, SlotQuery>((
  ref,
  q,
) async {
  // Booked viewings change what is free.
  ref.watch(viewingsProvider);
  return (await ref.watch(
    viewingRepositoryProvider.future,
  )).slots(q.homeId, q.day, ignoring: q.ignoring);
});

/// Conversations with agents, most recent first.
class ThreadsNotifier extends AsyncNotifier<List<MessageThread>> {
  @override
  Future<List<MessageThread>> build() async =>
      (await ref.watch(messageRepositoryProvider.future)).threads();

  Future<void> _reload() async => state = AsyncData(
    await (await ref.read(messageRepositoryProvider.future)).threads(),
  );

  Future<MessageThread> open(String agentId, {String? homeId}) async {
    final t = await (await ref.read(
      messageRepositoryProvider.future,
    )).open(agentId, homeId: homeId);
    await _reload();
    return t;
  }

  /// Sends [text], then shows the agent typing until their answer arrives.
  Future<void> send(String threadId, String text) async {
    final repo = await ref.read(messageRepositoryProvider.future);
    await repo.send(threadId, text);
    await _reload();
    final typing = ref.read(typingProvider.notifier);
    typing.state = {...typing.state, threadId};
    try {
      await repo.awaitReply(threadId);
    } finally {
      typing.state = {...typing.state}..remove(threadId);
    }
    await _reload();
  }

  Future<void> markRead(String threadId) async {
    await (await ref.read(messageRepositoryProvider.future)).markRead(threadId);
    await _reload();
  }

  Future<void> remove(String threadId) async {
    await (await ref.read(messageRepositoryProvider.future)).delete(threadId);
    await _reload();
  }

  Future<void> restore(MessageThread thread) async {
    await (await ref.read(messageRepositoryProvider.future)).restore(thread);
    await _reload();
  }
}

final threadsProvider =
    AsyncNotifierProvider<ThreadsNotifier, List<MessageThread>>(
      ThreadsNotifier.new,
    );

final threadProvider = Provider.family<MessageThread?, String>((ref, id) {
  for (final t
      in ref.watch(threadsProvider).valueOrNull ?? const <MessageThread>[]) {
    if (t.id == id) return t;
  }
  return null;
});

/// Threads whose agent is writing an answer.
final typingProvider = StateProvider<Set<String>>((_) => const {});

final unreadCountProvider = Provider<int>(
  (ref) => (ref.watch(threadsProvider).valueOrNull ?? const <MessageThread>[])
      .fold(0, (n, t) => n + t.unread),
);

/// Applications and offers, newest first.
class ApplicationsNotifier extends AsyncNotifier<List<Application>> {
  @override
  Future<List<Application>> build() async =>
      (await ref.watch(applicationRepositoryProvider.future)).applications();

  Future<Application> _after(
    Future<Application> Function(ApplicationRepository) change,
  ) async {
    final repo = await ref.read(applicationRepositoryProvider.future);
    final a = await change(repo);
    state = AsyncData(await repo.applications());
    return a;
  }

  Future<Application> submit(ApplicationDraft draft) =>
      _after((r) => r.submit(draft));

  /// Rethrows [PaymentDeclined], so the page can stay and say so.
  Future<Application> payDeposit(String id, PaymentCard card) =>
      _after((r) => r.payDeposit(id, card));
  Future<Application> withdraw(String id) => _after((r) => r.withdraw(id));
  Future<Application> restore(String id) => _after((r) => r.restore(id));
}

final applicationsProvider =
    AsyncNotifierProvider<ApplicationsNotifier, List<Application>>(
      ApplicationsNotifier.new,
    );

final applicationProvider = Provider.family<Application?, String>((ref, id) {
  for (final a
      in ref.watch(applicationsProvider).valueOrNull ?? const <Application>[]) {
    if (a.id == id) return a;
  }
  return null;
});

/// The live application for a home, if the person has one.
final applicationForHomeProvider = Provider.family<Application?, String>((
  ref,
  homeId,
) {
  for (final a
      in ref.watch(applicationsProvider).valueOrNull ?? const <Application>[]) {
    if (a.homeId == homeId && !a.withdrawn) return a;
  }
  return null;
});

final holdingDepositProvider = FutureProvider.family<Money, Home>(
  (ref, home) async => (await ref.watch(
    applicationRepositoryProvider.future,
  )).holdingDeposit(home),
);
