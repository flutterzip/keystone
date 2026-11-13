import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keystone/kit/kit.dart';

import '../config/app_theme.dart';
import '../config/motion.dart';
import '../models/format.dart';
import '../models/home.dart';
import '../models/viewing.dart';
import '../providers/core_providers.dart';

/// The live pill for a viewing that starts within the hour: a countdown
/// that opens, when tapped, into where and how. Under reduce motion it is
/// a still black capsule with the same words.
class ViewingIsland extends ConsumerStatefulWidget {
  const ViewingIsland({super.key, required this.viewing, required this.home});

  final Viewing viewing;
  final Home home;

  @override
  ConsumerState<ViewingIsland> createState() => _ViewingIslandState();
}

class _ViewingIslandState extends ConsumerState<ViewingIsland> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = ref.watch(nowProvider);
    final v = widget.viewing;
    final started = !now.isBefore(v.at);
    final line = started
        ? 'Viewing under way'
        : 'Viewing ${untilLabel(v.at, now)}';
    final on = p.onIsland;
    final small = TextStyle(
      fontFamily: AppTheme.font,
      color: on,
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w600,
    );
    final width = (MediaQuery.sizeOf(context).width - 40).clamp(240.0, 400.0);

    final compact = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: small,
          ),
        ),
      ],
    );
    final open = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                v.mode == ViewingMode.video
                    ? Icons.videocam_outlined
                    : Icons.key_rounded,
                size: 18,
                color: p.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.home.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: small.copyWith(fontSize: 15),
                ),
              ),
              Text(
                timeLabel(v.at),
                style: small.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          Text(
            v.mode == ViewingMode.video
                ? 'Video call. ${started ? 'Under way' : 'Starts ${untilLabel(v.at, now)}'}'
                : '${widget.home.address}. ${started ? 'Under way' : 'Starts ${untilLabel(v.at, now)}'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: small.copyWith(
              color: on.withValues(alpha: .7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      key: const Key('viewing-island'),
      button: true,
      label: '$line, ${widget.home.title} at ${timeLabel(v.at)}',
      excludeSemantics: true,
      // Only as tall as what it is showing, so it leaves no gap when shut.
      child: AnimatedSize(
        duration: Motion.medium,
        curve: Motion.settle,
        alignment: Alignment.topCenter,
        child: MorphingIsland(
          maxHeight: _open ? 88 : MorphingIsland.compactHeight + 8,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _open = !_open);
          },
          view: _open
              ? IslandView(id: 'open', size: Size(width, 80), child: open)
              : IslandView(
                  id: 'compact',
                  size: const Size(214, MorphingIsland.compactHeight),
                  child: compact,
                ),
        ),
      ),
    );
  }
}
