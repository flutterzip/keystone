class Message {
  const Message({
    required this.id,
    required this.fromMe,
    required this.text,
    required this.at,
  });

  final String id;
  final bool fromMe;
  final String text;
  final DateTime at;

  factory Message.fromJson(
    Map<String, dynamic> j, {
    DateTime? stamp,
    String? fallbackId,
  }) => Message(
    id: j['id'] as String? ?? fallbackId ?? '',
    fromMe: j['fromMe'] as bool,
    text: j['text'] as String,
    at: j['at'] != null
        ? DateTime.parse(j['at'] as String)
        : (stamp ?? DateTime.now()).subtract(
            Duration(minutes: j['minutesAgo'] as int),
          ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromMe': fromMe,
    'text': text,
    'at': at.toIso8601String(),
  };
}

/// A conversation with an agent, usually about one home. Unread is not
/// stored: it is any message from the agent since the thread was last read.
class MessageThread {
  const MessageThread({
    required this.id,
    required this.agentId,
    required this.messages,
    required this.readAt,
    this.homeId,
  });

  final String id;
  final String agentId;
  final String? homeId;
  final List<Message> messages;
  final DateTime readAt;

  Message? get last => messages.isEmpty ? null : messages.last;

  DateTime get lastAt => last?.at ?? readAt;

  int get unread =>
      messages.where((m) => !m.fromMe && m.at.isAfter(readAt)).length;

  MessageThread copyWith({List<Message>? messages, DateTime? readAt}) =>
      MessageThread(
        id: id,
        agentId: agentId,
        homeId: homeId,
        messages: messages ?? this.messages,
        readAt: readAt ?? this.readAt,
      );

  factory MessageThread.fromJson(Map<String, dynamic> j, {DateTime? stamp}) {
    final base = stamp ?? DateTime.now();
    final id = j['id'] as String;
    final raw = (j['messages'] as List).cast<Map<String, dynamic>>();
    return MessageThread(
      id: id,
      agentId: j['agentId'] as String,
      homeId: j['homeId'] as String?,
      readAt: j['readAt'] != null
          ? DateTime.parse(j['readAt'] as String)
          : base.subtract(Duration(minutes: j['readMinutesAgo'] as int? ?? 0)),
      messages: [
        for (var i = 0; i < raw.length; i++)
          Message.fromJson(raw[i], stamp: base, fallbackId: '$id-$i'),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'agentId': agentId,
    'homeId': homeId,
    'readAt': readAt.toIso8601String(),
    'messages': [for (final m in messages) m.toJson()],
  };
}
