import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keystone/kit/kit.dart';

import '../config/app_theme.dart';
import '../config/motion.dart';
import '../models/home.dart';
import '../providers/browse_providers.dart';
import 'photo.dart';

/// Where a saved home lands: the Saved tab's icon in the glass bar.
final savedTargetKey = GlobalKey(debugLabel: 'saved-target');

/// Ticks each time a home lands in Saved, so the tab can pop.
final savedLanded = ValueNotifier<int>(0);

/// Saves [home], or takes it off the shortlist if it is already there.
///
/// Saving throws a copy of the photo from [from] into the Saved tab and adds
/// the home when it lands, so the tab ticks on arrival and not before. With
/// reduce motion, or when either end is off screen, it lands at once.
void toggleSaved(
  BuildContext context,
  WidgetRef ref, {
  required Home home,
  required GlobalKey from,
}) {
  final saved = ref.read(savedProvider.notifier);
  if (ref.read(isSavedProvider(home.id))) {
    HapticFeedback.selectionClick();
    saved.remove(home.id);
    return;
  }
  HapticFeedback.lightImpact();
  FlyTo.launch(
    context,
    from: from,
    to: savedTargetKey,
    endScale: .12,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: HomePhoto(home.cover, decodeWidth: 240),
    ),
    onLanded: () {
      saved.add(home.id);
      savedLanded.value++;
      HapticFeedback.selectionClick();
    },
  );
}

/// The heart on a home. Filled and brass when the home is saved.
class SaveButton extends ConsumerWidget {
  const SaveButton({
    super.key,
    required this.home,
    required this.from,
    this.onPhoto = true,
  });

  final Home home;

  /// The photo the flight lifts off from.
  final GlobalKey from;

  /// On a photograph it sits on a disc; on paper it is bare.
  final bool onPhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final saved = ref.watch(isSavedProvider(home.id));
    return Semantics(
      button: true,
      label: saved ? 'Remove ${home.title} from saved' : 'Save ${home.title}',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('save-${home.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => toggleSaved(context, ref, home: home, from: from),
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: onPhoto
                  ? BoxDecoration(
                      color: p.card,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: p.shadow, blurRadius: 10)],
                    )
                  : null,
              child: AnimatedSwitcher(
                duration: Motion.short,
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, a) =>
                    ScaleTransition(scale: a, child: child),
                child: Icon(
                  saved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  key: ValueKey(saved),
                  size: 19,
                  color: saved ? p.accent : p.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
