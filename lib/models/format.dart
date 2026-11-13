// Dates and times as the app says them. One place, so every screen agrees.

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

String weekdayShort(DateTime t) => _days[t.weekday - 1];
String monthShort(DateTime t) => _months[t.month - 1];

/// "14:45".
String timeLabel(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "Today", "Tomorrow", "Yesterday" or "Thu 14 Nov".
String dayLabel(DateTime t, DateTime now) {
  final days = dayOf(t).difference(dayOf(now)).inDays;
  return switch (days) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ => '${weekdayShort(t)} ${t.day} ${monthShort(t)}',
  };
}

/// "Today at 14:45".
String whenLabel(DateTime t, DateTime now) =>
    '${dayLabel(t, now)} at ${timeLabel(t)}';

/// "in 38 min", "in 2 h", "now".
String untilLabel(DateTime t, DateTime now) {
  final m = (t.difference(now).inSeconds / 60).ceil();
  if (m <= 0) return 'now';
  if (m < 60) return 'in $m min';
  final h = m ~/ 60;
  return m % 60 == 0 ? 'in $h h' : 'in $h h ${m % 60} min';
}

/// "just now", "12 min ago", "3 h ago", "Yesterday", "Thu 14 Nov".
String agoLabel(DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24 && dayOf(t) == dayOf(now)) return '${d.inHours} h ago';
  return dayLabel(t, now);
}

/// A day or time label set inside a sentence: "today at 14:45" but still
/// "Thu 14 Nov", because a weekday keeps its capital.
String inSentence(String label) {
  for (final word in const ['Today', 'Tomorrow', 'Yesterday']) {
    if (label.startsWith(word)) {
      return label[0].toLowerCase() + label.substring(1);
    }
  }
  return label;
}
