/// Keeps removed rows on screen while their "Undo" is on offer.
///
/// The record is removed from its state straight away, so counts and totals
/// are right at once; the row lingers in the list (blown to dust) until the
/// undo window closes, and re-forms in place if it is taken.
class Linger {
  final _at = <String, int>{};

  /// The ids to build: the live ones, with each lingering id back at the
  /// place it was removed from.
  List<String> rows(List<String> live) {
    _at.removeWhere((id, _) => live.contains(id));
    final out = [...live];
    for (final e in _at.entries.toList()..sort((a, b) => a.value - b.value)) {
      out.insert(e.value.clamp(0, out.length), e.key);
    }
    return out;
  }

  bool isGone(String id) => _at.containsKey(id);

  /// Call just before removing [id] from [live].
  void hold(String id, List<String> live) => _at[id] = live.indexOf(id);

  /// The undo window closed: let the row go.
  void release(String id) => _at.remove(id);
}
