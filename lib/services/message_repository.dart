import '../config/app_timing.dart';
import '../models/ids.dart';
import '../models/thread.dart';
import 'seed.dart';
import 'store.dart';

abstract interface class MessageRepository {
  /// Most recent conversation first.
  Future<List<MessageThread>> threads();

  /// The thread with [agentId] about [homeId], made if there is none yet.
  Future<MessageThread> open(String agentId, {String? homeId});
  Future<MessageThread> send(String threadId, String text);
  Future<MessageThread> markRead(String threadId);
  Future<void> delete(String threadId);

  /// Puts a deleted thread back.
  Future<void> restore(MessageThread thread);

  /// The agent's answer. A backend delivers this by push or socket instead.
  Future<MessageThread> awaitReply(String threadId);
}

class DemoMessageRepository implements MessageRepository {
  DemoMessageRepository(
    Seed seed,
    Store store, {
    required DateTime firstLaunch,
    required this.clock,
    Duration? latency,
  }) : _latency = latency,
       _list = StoredList(
         store,
         Store.threads,
         seed: () => [
           for (final j in seed.rows('threads'))
             MessageThread.fromJson(j, stamp: firstLaunch),
         ],
         decode: MessageThread.fromJson,
         encode: (t) => t.toJson(),
       );

  final StoredList<MessageThread> _list;
  final DateTime Function() clock;
  final Duration? _latency;

  static const _replies = [
    'Thanks for your message. Let me check and come back to you shortly.',
    'Of course. I will confirm with the owner and let you know today.',
    'Good question. I will find out and message you this afternoon.',
  ];

  @override
  Future<List<MessageThread>> threads() async =>
      _list.read()..sort((a, b) => b.lastAt.compareTo(a.lastAt));

  Future<MessageThread> _update(
    String id,
    MessageThread Function(MessageThread) change,
  ) async {
    late MessageThread out;
    await _list.write([
      for (final t in _list.read())
        if (t.id == id) out = change(t) else t,
    ]);
    return out;
  }

  @override
  Future<MessageThread> open(String agentId, {String? homeId}) async {
    final all = _list.read();
    for (final t in all) {
      if (t.agentId == agentId && t.homeId == homeId) return t;
    }
    final t = MessageThread(
      id: Ids.next('t'),
      agentId: agentId,
      homeId: homeId,
      messages: const [],
      readAt: clock(),
    );
    await _list.write([...all, t]);
    return t;
  }

  @override
  Future<MessageThread> send(String threadId, String text) async {
    await AppTiming.wait(_latency ?? AppTiming.sendMessage);
    final now = clock();
    return _update(
      threadId,
      (t) => t.copyWith(
        readAt: now,
        messages: [
          ...t.messages,
          Message(id: Ids.next('m'), fromMe: true, text: text.trim(), at: now),
        ],
      ),
    );
  }

  @override
  Future<MessageThread> awaitReply(String threadId) async {
    await AppTiming.wait(_latency ?? AppTiming.agentReply);
    return _update(
      threadId,
      (t) => t.copyWith(
        messages: [
          ...t.messages,
          Message(
            id: Ids.next('m'),
            fromMe: false,
            text: _replies[t.messages.length % _replies.length],
            at: clock(),
          ),
        ],
      ),
    );
  }

  @override
  Future<MessageThread> markRead(String threadId) =>
      _update(threadId, (t) => t.copyWith(readAt: clock()));

  @override
  Future<void> delete(String threadId) => _list.write([
    for (final t in _list.read())
      if (t.id != threadId) t,
  ]);

  @override
  Future<void> restore(MessageThread thread) async {
    final all = _list.read();
    if (all.any((t) => t.id == thread.id)) return;
    await _list.write([...all, thread]);
  }
}

// A network implementation:
//
// class RemoteMessageRepository implements MessageRepository {
//   RemoteMessageRepository(this._dio);
//   final Dio _dio;
//
//   @override
//   Future<List<MessageThread>> threads() async => [
//     for (final j in (await _dio.get('/threads')).data) MessageThread.fromJson(j),
//   ];
//
//   @override
//   Future<MessageThread> send(String id, String text) async => MessageThread.fromJson(
//     (await _dio.post('/threads/$id/messages', data: {'text': text})).data,
//   );
//   ...
// }
