class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.avatar,
    this.memberNumber = '',
    this.memberSince = 2026,
  });

  final String name;
  final String email;
  final String phone;

  /// A media reference: `asset:people/x.png` for a bundled picture,
  /// `file:media/x.jpg` for one the person chose, or empty for none (the
  /// initial shows instead). Never image bytes.
  final String avatar;

  /// The number printed on the resident key card.
  final String memberNumber;
  final int memberSince;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? avatar,
  }) => UserProfile(
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    avatar: avatar ?? this.avatar,
    memberNumber: memberNumber,
    memberSince: memberSince,
  );

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    name: j['name'] as String,
    email: j['email'] as String,
    phone: j['phone'] as String? ?? '',
    avatar: j['avatar'] as String? ?? '',
    memberNumber: j['memberNumber'] as String? ?? '',
    memberSince: j['memberSince'] as int? ?? 2026,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'phone': phone,
    'avatar': avatar,
    'memberNumber': memberNumber,
    'memberSince': memberSince,
  };
}

/// A saved way to pay. Only what a receipt shows is ever kept: the brand,
/// the last four digits, the expiry and the holder. The full number and the
/// security code are never stored, logged or sent anywhere by this app.
class PaymentCard {
  const PaymentCard({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    required this.holder,
  });

  final String id;
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;
  final String holder;

  String get masked => '$brand ending $last4';
  String get expiry =>
      '${expMonth.toString().padLeft(2, '0')}/${(expYear % 100).toString().padLeft(2, '0')}';

  /// "Visa" for a number starting 4, and so on. Unknown ranges are "Card".
  static String brandOf(String digits) {
    if (digits.startsWith('4')) return 'Visa';
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(digits)) return 'Mastercard';
    if (RegExp(r'^3[47]').hasMatch(digits)) return 'Amex';
    return 'Card';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'brand': brand,
    'last4': last4,
    'expMonth': expMonth,
    'expYear': expYear,
    'holder': holder,
  };

  factory PaymentCard.fromJson(Map<String, dynamic> j) => PaymentCard(
    id: j['id'] as String,
    brand: j['brand'] as String,
    last4: j['last4'] as String,
    expMonth: j['expMonth'] as int,
    expYear: j['expYear'] as int,
    holder: j['holder'] as String,
  );
}
