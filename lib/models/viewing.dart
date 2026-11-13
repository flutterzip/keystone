enum ViewingMode {
  inPerson('In person', 'Meet the agent at the home'),
  video('Video call', 'The agent walks you round on a call');

  const ViewingMode(this.label, this.note);
  final String label;
  final String note;
}

enum ViewingStatus { upcoming, soon, past, cancelled }

/// A booked viewing. Only when it is and whether it was cancelled are
/// stored; whether it is upcoming, about to start or over is worked out
/// from the clock, so every screen agrees.
class Viewing {
  const Viewing({
    required this.id,
    required this.homeId,
    required this.at,
    required this.mode,
    this.cancelledAt,
  });

  final String id;
  final String homeId;
  final DateTime at;
  final ViewingMode mode;
  final DateTime? cancelledAt;

  /// A viewing lasts this long.
  static const length = Duration(minutes: 30);

  /// It counts as "soon" from this long before it starts.
  static const soonWindow = Duration(minutes: 60);

  ViewingStatus status(DateTime now) {
    if (cancelledAt != null) return ViewingStatus.cancelled;
    if (!now.isBefore(at.add(length))) return ViewingStatus.past;
    if (!now.isBefore(at.subtract(soonWindow))) return ViewingStatus.soon;
    return ViewingStatus.upcoming;
  }

  Viewing copyWith({
    DateTime? at,
    ViewingMode? mode,
    DateTime? Function()? cancelledAt,
  }) => Viewing(
    id: id,
    homeId: homeId,
    at: at ?? this.at,
    mode: mode ?? this.mode,
    cancelledAt: cancelledAt == null ? this.cancelledAt : cancelledAt(),
  );

  /// [stamp] turns the seed's relative minutes into dates.
  factory Viewing.fromJson(Map<String, dynamic> j, {DateTime? stamp}) {
    final base = stamp ?? DateTime.now();
    final cancelledAgo = j['cancelledMinutesAgo'] as int?;
    return Viewing(
      id: j['id'] as String,
      homeId: j['homeId'] as String,
      at: j['at'] != null
          ? DateTime.parse(j['at'] as String)
          : base.add(Duration(minutes: j['inMinutes'] as int)),
      mode: ViewingMode.values.byName(j['mode'] as String),
      cancelledAt: j['cancelledAt'] != null
          ? DateTime.parse(j['cancelledAt'] as String)
          : cancelledAgo == null
          ? null
          : base.subtract(Duration(minutes: cancelledAgo)),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'homeId': homeId,
    'at': at.toIso8601String(),
    'mode': mode.name,
    'cancelledAt': cancelledAt?.toIso8601String(),
  };
}

/// One bookable time on a day. A slot that cannot be booked says why.
class Slot {
  const Slot(this.at, {this.taken});

  final DateTime at;

  /// Null when free; otherwise the sentence shown when it is tapped.
  final String? taken;

  bool get free => taken == null;
}
