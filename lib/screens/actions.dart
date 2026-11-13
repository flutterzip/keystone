import 'package:flutter/material.dart';
import 'package:keystone/kit/kit.dart';

import '../config/motion.dart';
import '../models/home.dart';
import '../models/viewing.dart';
import 'application/application_screen.dart';
import 'booking/book_viewing_screen.dart';
import 'messages/messages_screen.dart';
import 'messages/thread_screen.dart';
import 'property/brochure_screen.dart';
import 'property/gallery_screen.dart';
import 'property/property_screen.dart';
import 'search/search_screen.dart';
import 'shell/main_shell.dart';

// Where a tap goes, wherever it happens. Screens call these rather than
// wiring navigation themselves, so a home opens the same way from Home,
// Search, Saved, a viewing or a message.

/// A page inside the current tab, so the glass bar stays.
Route<T> tabRoute<T>(Widget page, {String? name}) => MaterialPageRoute<T>(
  settings: RouteSettings(name: name),
  builder: (_) => page,
);

/// A page that fades up in place: for Search, which grows out of its pill.
Route<T> fadeRoute<T>(Widget page, {String? name}) => PageRouteBuilder<T>(
  settings: RouteSettings(name: name),
  transitionDuration: Motion.medium,
  reverseTransitionDuration: Motion.short,
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, animation, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  ),
);

/// Opens a home. [scope] names the list it was tapped in, so its photo
/// flies from that card.
void openHome(BuildContext context, Home home, {String scope = 'page'}) =>
    tabNavigator(
      context,
    ).push(tabRoute(PropertyScreen(homeId: home.id, scope: scope)));

void openSearch(BuildContext context, {bool map = false}) => tabNavigator(
  context,
).push(fadeRoute(SearchScreen(startOnMap: map), name: 'search'));

/// Opens Messages in the current tab, unless it is already on top.
void openMessages(BuildContext context) {
  final nav = tabNavigator(context);
  var onTop = false;
  nav.popUntil((r) {
    onTop = r.settings.name == 'messages';
    return true;
  });
  if (!onTop) nav.push(tabRoute(const MessagesScreen(), name: 'messages'));
}

void openThread(BuildContext context, String threadId) =>
    tabNavigator(context).push(tabRoute(ThreadScreen(threadId: threadId)));

/// The gallery covers the whole screen, bar and all.
void openGallery(BuildContext context, Home home, {int at = 0}) => Navigator.of(
  context,
  rootNavigator: true,
).push(fadeRoute(GalleryScreen(home: home, initial: at)));

void openBrochure(BuildContext context, Home home) => Navigator.of(
  context,
  rootNavigator: true,
).push(tabRoute(BrochureScreen(homeId: home.id)));

/// Booking is its own mode: it arrives through ink spreading from where the
/// button was pressed, the app's one route effect. [reschedule] moves an
/// existing viewing instead of booking a new one.
void openBooking(
  BuildContext context,
  Home home, {
  Offset? origin,
  Viewing? reschedule,
}) {
  final page = BookViewingScreen(homeId: home.id, reschedule: reschedule);
  Navigator.of(context, rootNavigator: true).push(
    Motion.reduced(context)
        ? tabRoute(page)
        : ShaderPageRoute(
            effect: ShaderTransition.ink,
            origin: origin,
            duration: Motion.inkRoute,
            builder: (_) => page,
          ),
  );
}

/// The application for a home: the form if there is none yet, its status
/// if there is.
void openApplication(BuildContext context, Home home) =>
    tabNavigator(context).push(tabRoute(ApplicationScreen(homeId: home.id)));
