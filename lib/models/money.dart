/// Money is integer minor units with a currency code, everywhere. This is
/// the only place it becomes text.
class Money {
  const Money(this.amount, this.currency);

  final int amount;
  final String currency;

  String get text => formatMoney(amount, currency);
  String get compact => formatMoney(amount, currency, compact: true);

  Money copyWith({int? amount}) => Money(amount ?? this.amount, currency);

  factory Money.fromJson(Map<String, dynamic> j) =>
      Money(j['amount'] as int, j['currency'] as String);

  Map<String, dynamic> toJson() => {'amount': amount, 'currency': currency};

  @override
  bool operator ==(Object other) =>
      other is Money && other.amount == amount && other.currency == currency;

  @override
  int get hashCode => Object.hash(amount, currency);
}

const _symbols = {'EUR': '€', 'USD': r'$', 'GBP': '£'};

/// "€2,900", "€1,180,000", "€12.50"; compact gives "€2.45M" and "€890K" for
/// places with no room, such as a map pin.
String formatMoney(int minor, String currency, {bool compact = false}) {
  final symbol = _symbols[currency] ?? '$currency ';
  final negative = minor < 0;
  final abs = minor.abs();
  final sign = negative ? '-' : '';
  if (compact) {
    final whole = abs / 100;
    String trim(double v) {
      final s = v.toStringAsFixed(2);
      return s.replaceFirst(RegExp(r'\.?0+$'), '');
    }

    if (whole >= 1000000) return '$sign$symbol${trim(whole / 1000000)}M';
    if (whole >= 10000) return '$sign$symbol${(whole / 1000).round()}K';
  }
  final whole = (abs ~/ 100).toString();
  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }
  final rest = abs % 100;
  final tail = rest == 0 ? '' : '.${rest.toString().padLeft(2, '0')}';
  return '$sign$symbol$grouped$tail';
}
