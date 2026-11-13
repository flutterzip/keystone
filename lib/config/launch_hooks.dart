import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/core_providers.dart';
import '../screens/actions.dart';
import '../screens/application/application_screen.dart';
import '../screens/profile/documents_screen.dart';
import '../screens/profile/saved_searches_screen.dart';
import '../screens/saved/compare_screen.dart';
import '../screens/shell/main_shell.dart';
import '../services/store.dart';

/// Opens the app in a given state, for screenshots and recordings. Off
/// unless asked for, so a normal build is unaffected:
///
///   flutter run --dart-define=start=signedIn,tab=saved
///
/// `tool/shots.sh` uses it to take the README screenshots.
///
/// Tokens, comma separated:
///   fresh           forget everything first, as on a first launch
///   signedIn        skip onboarding and sign in as the demo person
///   dark | light    force the appearance
///   kind=KIND       rent or sale
///   tab=NAME        home, saved, viewings or profile
///   open=WHAT       search, map, messages, searches, documents,
///                   applications, home:ID, gallery:ID, brochure:ID,
///                   book:ID, application:ID, thread:ID or compare:ID+ID
///   touches         draw a dot under every touch, for recordings
///   touch=SCRIPT    taps and waits played after the page opens, for
///                   recording motion hands-free: `600/220x640/900/200x300`
///                   waits 600 ms, taps at (220, 640), waits 900 ms, taps
///                   again. `AxB>CxD` drags from one point to the other
///                   and `type:garden` types into the focused field.
abstract final class LaunchHooks {
  /// What was asked for at build time. Empty in anything that ships.
  static const start = String.fromEnvironment('start', defaultValue: '');

  /// A one-shot request left as a file in the app's Documents folder by
  /// `tool/shots.sh`, so a debug build can be relaunched into a state
  /// without rebuilding. Never read in a release build.
  static const requestFile = 'launch_start.txt';
  static String _asked = start;

  static List<String> get _tokens => [
    for (final t in _asked.split(','))
      if (t.trim().isNotEmpty) t.trim(),
  ];

  static String? _value(String key) {
    for (final t in _tokens) {
      if (t.startsWith('$key=')) return t.substring(key.length + 1);
    }
    return null;
  }

  /// Before the first frame: stored state the first screen reads.
  static Future<void> prepare(Store store) async {
    if (start.isEmpty && !kReleaseMode) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$requestFile');
        if (file.existsSync()) {
          _asked = file.readAsStringSync().trim();
          file.deleteSync();
        }
      } catch (_) {
        // No request, or nowhere to look: start normally.
      }
    }
    final tokens = _tokens;
    if (tokens.isEmpty) return;
    if (tokens.contains('fresh')) await store.reset();
    if (tokens.contains('signedIn')) {
      await store.setString(Store.onboarded, '1');
      await store.setJson(Store.session, {'email': 'hello@flutterzip.com'});
    }
    if (tokens.contains('dark')) await store.setString(Store.themeMode, 'dark');
    if (tokens.contains('light')) {
      await store.setString(Store.themeMode, 'light');
    }
    final kind = _value('kind');
    if (kind != null) await store.setString(Store.listingKind, kind);
  }

  /// After the splash has gone: the tab and page to land on. Pages open
  /// through the same functions the UI uses.
  static void run(BuildContext context, ProviderContainer container) {
    if (_tokens.isEmpty) return;
    final tab = ShellTab.values.asNameMap()[_value('tab')];
    if (tab != null) container.read(shellTabProvider.notifier).state = tab;
    final touch = _value('touch');
    if (touch != null) _play(touch);
    final open = _value('open');
    if (open == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final nav = tabNavigator(context);
      final [what, ...rest] = open.split(':');
      final id = rest.join(':');
      final home = container.read(homeProvider(id.split('+').first));
      switch (what) {
        case 'search':
          openSearch(context);
        case 'map':
          openSearch(context, map: true);
        case 'messages':
          openMessages(context);
        case 'thread':
          openThread(context, id);
        case 'searches':
          nav.push(tabRoute(const SavedSearchesScreen()));
        case 'documents':
          nav.push(tabRoute(const DocumentsScreen()));
        case 'applications':
          nav.push(
            tabRoute(
              ApplicationsScreen(onOpen: (h) => openApplication(context, h)),
            ),
          );
        case 'compare':
          final [a, b] = id.split('+');
          nav.push(tabRoute(CompareScreen(a: a, b: b)));
        case 'home' when home != null:
          openHome(context, home);
        case 'gallery' when home != null:
          openGallery(context, home);
        case 'brochure' when home != null:
          openBrochure(context, home);
        case 'book' when home != null:
          openBooking(context, home);
        case 'application' when home != null:
          openApplication(context, home);
      }
    });
  }

  /// Whether touches are drawn on screen, for recordings.
  static bool get showTouches => _tokens.contains('touches');

  /// Types into the field that has the keyboard, a letter at a time.
  static Future<void> _type(String text) async {
    final field = FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<EditableTextState>();
    if (field == null) return;
    for (var i = 1; i <= text.length; i++) {
      final typed = text.substring(0, i);
      field.userUpdateTextEditingValue(
        TextEditingValue(
          text: typed,
          selection: TextSelection.collapsed(offset: typed.length),
        ),
        SelectionChangedCause.keyboard,
      );
      await Future<void>.delayed(const Duration(milliseconds: 110));
    }
  }

  /// Plays a touch script through the gesture binding, so real recognisers
  /// fire exactly as for a finger.
  static Future<void> _play(String script) async {
    Offset? point(String s) {
      final xy = s.split('x').map(double.tryParse).toList();
      return xy.length == 2 && xy[0] != null && xy[1] != null
          ? Offset(xy[0]!, xy[1]!)
          : null;
    }

    var pointer = 900;
    Duration stamp() =>
        Duration(microseconds: DateTime.now().microsecondsSinceEpoch);
    void send(PointerEvent e) => GestureBinding.instance.handlePointerEvent(e);
    for (final step in script.split('/')) {
      if (step.startsWith('type:')) {
        await _type(step.substring(5));
      } else if (step.contains('>')) {
        final [a, b] = step.split('>').map(point).toList();
        if (a == null || b == null) continue;
        final id = pointer++;
        send(PointerDownEvent(pointer: id, position: a, timeStamp: stamp()));
        const frames = 26;
        for (var i = 1; i <= frames; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 16));
          send(
            PointerMoveEvent(
              pointer: id,
              position: Offset.lerp(a, b, i / frames)!,
              delta: (b - a) / frames.toDouble(),
              timeStamp: stamp(),
            ),
          );
        }
        send(PointerUpEvent(pointer: id, position: b, timeStamp: stamp()));
      } else if (step.contains('x')) {
        final at = point(step);
        if (at == null) continue;
        final id = pointer++;
        send(PointerDownEvent(pointer: id, position: at, timeStamp: stamp()));
        await Future<void>.delayed(const Duration(milliseconds: 60));
        send(PointerUpEvent(pointer: id, position: at, timeStamp: stamp()));
      } else {
        await Future<void>.delayed(
          Duration(milliseconds: int.tryParse(step) ?? 0),
        );
      }
    }
  }
}
