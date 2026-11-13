import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/app_timing.dart';
import '../config/design_tokens.dart';
import '../config/palette.dart';
import 'app_sheet.dart';
import 'keystone_mark.dart';
import 'primary_button.dart';

export 'controls.dart';

/// A page pushed inside a tab: an opaque ground (so the page beneath never
/// shows through the transition), a back button and a title.
class SubPage extends StatelessWidget {
  const SubPage({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.onBack,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.paper,
      child: Column(
        children: [
          SizedBox(height: MediaQuery.paddingOf(context).top),
          SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 6),
                BackChevron(onTap: onBack),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.heading,
                  ),
                ),
                ?trailing,
                const SizedBox(width: Space.md),
              ],
            ),
          ),
          Divider(color: p.line),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// The first page of a tab. Its list scrolls up under the status bar, so a
/// band of paper fades over the top to keep the clock readable.
class TabPage extends StatelessWidget {
  const TabPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final top = MediaQuery.paddingOf(context).top;
    return Material(
      color: p.paper,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + 14,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [.7, 1],
                    colors: [p.paper, p.paper.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BackChevron extends StatelessWidget {
  const BackChevron({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: onTap ?? () => Navigator.of(context).maybePop(),
    icon: Icon(
      Icons.arrow_back_ios_new_rounded,
      size: 18,
      color: context.palette.ink,
    ),
  );
}

/// A round icon button with a 44dp target. [filled] gives it a disc of
/// card colour, for sitting on a photograph.
class RoundIcon extends StatelessWidget {
  const RoundIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.color,
    this.size = 18,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: filled ? p.card : null,
                shape: BoxShape.circle,
                boxShadow: filled
                    ? [BoxShadow(color: p.shadow, blurRadius: 10)]
                    : null,
              ),
              child: Icon(icon, size: size, color: color ?? p.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty states name the situation under the arch, never a generic icon.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.action,
    this.onAction,
  });

  final IconData? icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.all(Space.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 104,
            child: Stack(
              alignment: Alignment.center,
              children: [
                KeystoneMark(
                  size: 104,
                  color: p.line,
                  keyColor: p.accent.withValues(alpha: .7),
                ),
                if (icon != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 38),
                    child: Icon(icon, color: p.muted, size: 24),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          Text(title, style: context.heading, textAlign: TextAlign.center),
          const SizedBox(height: Space.sm),
          Text(message, style: context.body, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: Space.xl),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: p.ink,
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.xl,
                  vertical: Space.md,
                ),
                shape: StadiumBorder(side: BorderSide(color: p.ink)),
                textStyle: const TextStyle(
                  fontFamily: AppTheme.font,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
              child: Text(action!),
            ),
          ],
        ],
      ),
    );
  }
}

/// A one-line notice: an icon and a sentence, sized to the sentence.
class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.icon, this.error = false});

  final String text;
  final IconData? icon;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tone = error ? p.error : p.inkSoft;
    return Row(
      children: [
        Icon(
          icon ??
              (error
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded),
          size: 16,
          color: tone,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: context.caption.copyWith(
              color: tone,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// A row of a label and a value, as on a receipt.
class ReceiptRow extends StatelessWidget {
  const ReceiptRow(this.label, this.value, {super.key, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: strong ? context.title : context.body,
            ),
          ),
          const SizedBox(width: Space.md),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: context.price.copyWith(
                fontSize: strong ? 17 : 14,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The heading of a section, with an optional action at its right.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.heading,
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: p.accentInk,
                minimumSize: const Size(48, 40),
                padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                textStyle: const TextStyle(
                  fontFamily: AppTheme.font,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// A confirmation whose button names what it does. Resolves true to go on.
Future<bool> confirmRemove(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  String keep = 'Keep it',
}) async =>
    await showAppSheet<bool>(
      context,
      title: title,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          0,
          Space.gutter,
          Space.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: context.body),
            const SizedBox(height: Space.xl),
            KeyedSubtree(
              key: const Key('confirm-remove'),
              child: PrimaryButton(
                label: action,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
            const SizedBox(height: Space.sm),
            PrimaryButton(
              quiet: true,
              label: keep,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ) ??
    false;

/// A quiet floating confirmation, with an optional "Undo".
void showToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_rounded,
  VoidCallback? onUndo,
  VoidCallback? onClosed,
}) => showToastOn(
  ScaffoldMessenger.of(context),
  context.palette,
  message,
  icon: icon,
  onUndo: onUndo,
  onClosed: onClosed,
);

void showToastOn(
  ScaffoldMessengerState messenger,
  Palette p,
  String message, {
  IconData icon = Icons.check_circle_rounded,
  VoidCallback? onUndo,
  VoidCallback? onClosed,
}) {
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      duration: onUndo == null
          ? const Duration(milliseconds: 2000)
          : AppTiming.undoWindow,
      // A SnackBar with an action stays until it is tapped unless told
      // otherwise; an "Undo" is only on offer for the undo window.
      persist: false,
      // Clear of the floating tab bar, and of a page's pinned button above
      // it: an "Undo" must never sit on top of "Book a viewing".
      margin: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Sizes.tabBarReserve + Sizes.buttonHeight - 6,
      ),
      action: onUndo == null
          ? null
          : SnackBarAction(label: 'Undo', onPressed: onUndo),
      content: Row(
        children: [
          Icon(icon, color: p.paper, size: 19),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
  if (onClosed != null) controller.closed.then((_) => onClosed());
}
