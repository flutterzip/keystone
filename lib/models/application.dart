import 'money.dart';

enum ApplicationKind {
  application('Rental application'),
  offer('Offer');

  const ApplicationKind(this.label);
  final String label;
}

/// One step of an application's life, for the timeline.
class ApplicationStage {
  const ApplicationStage(this.title, this.note, {this.at, this.done = false});

  final String title;
  final String note;

  /// When it happened, or is expected to.
  final DateTime? at;
  final bool done;
}

/// A rental application or an offer to buy.
///
/// Only what the person did is stored: when they sent it, what they
/// offered, when they paid the deposit, whether they withdrew. Where it has
/// got to is worked out from the clock.
class Application {
  const Application({
    required this.id,
    required this.homeId,
    required this.kind,
    required this.submittedAt,
    this.offer,
    this.moveIn,
    this.note = '',
    this.depositPaidAt,
    this.depositCard,
    this.withdrawnAt,
  });

  final String id;
  final String homeId;
  final ApplicationKind kind;
  final DateTime submittedAt;

  /// What was offered, for a purchase.
  final Money? offer;

  /// The day the person wants to move in, for a rental.
  final DateTime? moveIn;
  final String note;
  final DateTime? depositPaidAt;

  /// "Visa ending 4242": what a receipt shows, never more.
  final String? depositCard;
  final DateTime? withdrawnAt;

  static const reviewAfter = Duration(hours: 2);
  static const decisionAfter = Duration(days: 2);
  static const contractAfter = Duration(days: 1);

  bool get withdrawn => withdrawnAt != null;
  bool get isOffer => kind == ApplicationKind.offer;

  DateTime get reviewAt => submittedAt.add(reviewAfter);
  DateTime get decisionAt => submittedAt.add(decisionAfter);

  bool approved(DateTime now) => !withdrawn && !now.isBefore(decisionAt);

  /// The deposit can be paid once it is approved, and only once.
  bool depositDue(DateTime now) => approved(now) && depositPaidAt == null;

  String statusLabel(DateTime now) {
    if (withdrawn) return 'Withdrawn';
    if (depositPaidAt != null) return 'Deposit paid';
    if (approved(now)) return isOffer ? 'Offer accepted' : 'Approved';
    if (!now.isBefore(reviewAt)) return 'Under review';
    return 'Sent';
  }

  List<ApplicationStage> stages(DateTime now) {
    final paid = depositPaidAt;
    return [
      ApplicationStage(
        isOffer ? 'Offer sent' : 'Application sent',
        'The agent has everything they need.',
        at: submittedAt,
        done: true,
      ),
      ApplicationStage(
        'Under review',
        isOffer
            ? 'The owners are considering your offer.'
            : 'References and documents are being checked.',
        at: reviewAt,
        done: !now.isBefore(reviewAt),
      ),
      ApplicationStage(
        isOffer ? 'Offer accepted' : 'Approved',
        isOffer
            ? 'The owners have said yes.'
            : 'The owner is happy to go ahead.',
        at: decisionAt,
        done: !now.isBefore(decisionAt),
      ),
      ApplicationStage(
        'Holding deposit',
        paid == null
            ? 'Pay it to take the home off the market.'
            : 'Paid with $depositCard. The home is held for you.',
        at: paid,
        done: paid != null,
      ),
      ApplicationStage(
        'Contract',
        'Ready to sign from your phone a day after the deposit.',
        at: paid?.add(contractAfter),
        done: paid != null && !now.isBefore(paid.add(contractAfter)),
      ),
    ];
  }

  Application copyWith({
    DateTime? depositPaidAt,
    String? depositCard,
    DateTime? Function()? withdrawnAt,
  }) => Application(
    id: id,
    homeId: homeId,
    kind: kind,
    submittedAt: submittedAt,
    offer: offer,
    moveIn: moveIn,
    note: note,
    depositPaidAt: depositPaidAt ?? this.depositPaidAt,
    depositCard: depositCard ?? this.depositCard,
    withdrawnAt: withdrawnAt == null ? this.withdrawnAt : withdrawnAt(),
  );

  factory Application.fromJson(Map<String, dynamic> j, {DateTime? stamp}) {
    final base = stamp ?? DateTime.now();
    DateTime? date(String k) =>
        j[k] == null ? null : DateTime.parse(j[k] as String);
    final moveInDays = j['moveInDays'] as int?;
    return Application(
      id: j['id'] as String,
      homeId: j['homeId'] as String,
      kind: ApplicationKind.values.byName(j['kind'] as String),
      submittedAt:
          date('submittedAt') ??
          base.subtract(Duration(minutes: j['submittedMinutesAgo'] as int)),
      offer: j['offer'] == null
          ? null
          : Money.fromJson(j['offer'] as Map<String, dynamic>),
      moveIn:
          date('moveIn') ??
          (moveInDays == null ? null : base.add(Duration(days: moveInDays))),
      note: j['note'] as String? ?? '',
      depositPaidAt: date('depositPaidAt'),
      depositCard: j['depositCard'] as String?,
      withdrawnAt: date('withdrawnAt'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'homeId': homeId,
    'kind': kind.name,
    'submittedAt': submittedAt.toIso8601String(),
    'offer': offer?.toJson(),
    'moveIn': moveIn?.toIso8601String(),
    'note': note,
    'depositPaidAt': depositPaidAt?.toIso8601String(),
    'depositCard': depositCard,
    'withdrawnAt': withdrawnAt?.toIso8601String(),
  };
}

/// A paper kept for applications: an ID, payslips, a reference.
class Document {
  const Document({
    required this.id,
    required this.name,
    required this.kind,
    required this.addedAt,
  });

  final String id;
  final String name;
  final String kind;
  final DateTime addedAt;

  static const kinds = [
    'Identity',
    'Proof of income',
    'Reference',
    'Bank statement',
  ];

  /// A new document is checked for an hour before it counts as verified.
  static const checkTime = Duration(hours: 1);

  bool verified(DateTime now) => !now.isBefore(addedAt.add(checkTime));

  Document copyWith({String? name}) =>
      Document(id: id, name: name ?? this.name, kind: kind, addedAt: addedAt);

  factory Document.fromJson(Map<String, dynamic> j, {DateTime? stamp}) =>
      Document(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: j['kind'] as String,
        addedAt: j['addedAt'] != null
            ? DateTime.parse(j['addedAt'] as String)
            : (stamp ?? DateTime.now()).subtract(
                Duration(minutes: j['addedMinutesAgo'] as int),
              ),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'addedAt': addedAt.toIso8601String(),
  };
}
