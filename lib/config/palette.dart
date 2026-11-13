import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Every colour in the app is defined in this file.
//
// To re-skin Keystone, edit [Palette.light] and [Palette.dark] below. Every
// screen, sheet and button, the splash, the glass tab bar, the drawn map,
// the floor plans, the key card and the logo itself read their colours from
// here through `context.palette`; nothing else in lib/ hard-codes a colour
// (a test enforces it). `tool/make_mark.py` reads this file too, so the app
// icon follows the same values.
//
// Two things are deliberately not here:
//  * the property photographs, which look the same in light and dark;
//  * the Apple and Google sign-in buttons (lib/widgets/social_buttons.dart),
//    whose colours are fixed by their brand guidelines.
//
// The system: limestone paper, evergreen ink, and exactly one accent, brass,
// the colour of the keystone in the logo. Evergreen is the ink at full
// strength, so the main button is a block of ink rather than a second hue.
// Ink is never pure black and paper is never pure white.
// ---------------------------------------------------------------------------

@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.paper,
    required this.card,
    required this.plate,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.line,
    required this.field,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.accentInk,
    required this.onAccent,
    required this.accentWash,
    required this.error,
    required this.positive,
    required this.shadow,
    required this.mesh,
    required this.glassTint,
    required this.scrim,
    required this.onIsland,
    required this.photoScrim,
    required this.onPhoto,
    required this.mapLand,
    required this.mapBlock,
    required this.mapStreet,
    required this.mapPark,
    required this.mapWater,
    required this.keyCard,
    required this.keyLine,
  });

  /// The page ground.
  final Color paper;

  /// Raised surfaces: cards, sheets.
  final Color card;

  /// What shows where a photograph is still loading, or missing.
  final Color plate;

  /// Primary type and icons.
  final Color ink;

  /// Body copy.
  final Color inkSoft;

  /// Captions, hints, inactive icons.
  final Color muted;

  /// Hairlines and dividers.
  final Color line;

  /// The fill of a text field or an unselected chip at rest.
  final Color field;

  /// The main button, and type on top of it.
  final Color primary;
  final Color onPrimary;

  /// The one accent, brass: the keystone, map pins, badges, selection.
  final Color accent;

  /// The accent when it is type or a fine icon on [paper]: the same brass,
  /// deep enough to read.
  final Color accentInk;

  /// Type and icons on top of [accent].
  final Color onAccent;

  /// A pale tint of the accent for selected chips and notices.
  final Color accentWash;

  /// Errors: a brick neighbour of the brass, not its opposite.
  final Color error;

  /// Confirmed, verified, available.
  final Color positive;

  /// Soft shadows under cards and pins.
  final Color shadow;

  /// The four colours of the splash and sign-in mesh gradient.
  final List<Color> mesh;

  /// The tint of the glass tab bar.
  final Color glassTint;

  /// The dim behind a sheet.
  final Color scrim;

  /// Type on the black live-viewing pill.
  final Color onIsland;

  /// The shade laid over the foot of a photograph so type reads on it, and
  /// that type.
  final Color photoScrim;
  final Color onPhoto;

  /// The drawn map: ground, city blocks, streets, parks and the river.
  final Color mapLand;
  final Color mapBlock;
  final Color mapStreet;
  final Color mapPark;
  final Color mapWater;

  /// The resident key card: its ground and its fine line work.
  final Color keyCard;
  final Color keyLine;

  static const light = Palette(
    paper: Color(0xFFF3F1EC),
    card: Color(0xFFFBFAF7),
    plate: Color(0xFFE3E0D7),
    ink: Color(0xFF12241D),
    inkSoft: Color(0xFF3A4A43),
    muted: Color(0xFF7A847E),
    line: Color(0xFFE0DDD3),
    field: Color(0xFFEAE7DF),
    primary: Color(0xFF173A2E),
    onPrimary: Color(0xFFF6F4EF),
    accent: Color(0xFFB8894A),
    accentInk: Color(0xFF8A6126),
    onAccent: Color(0xFF12241D),
    accentWash: Color(0xFFF0E7D6),
    error: Color(0xFFA5452E),
    positive: Color(0xFF2F6B4F),
    shadow: Color(0x2612241D),
    mesh: [
      Color(0xFFF3F1EC),
      Color(0xFFE6DCC6),
      Color(0xFFCBD6C8),
      Color(0xFFF0E7D6),
    ],
    glassTint: Color(0x8A12241D),
    scrim: Color(0x5512241D),
    onIsland: Color(0xFFF6F4EF),
    photoScrim: Color(0xD90B1712),
    onPhoto: Color(0xFFFBFAF7),
    mapLand: Color(0xFFEDEAE2),
    mapBlock: Color(0xFFE2DED3),
    mapStreet: Color(0xFFFBFAF7),
    mapPark: Color(0xFFCDDBC8),
    mapWater: Color(0xFFBFD3D4),
    keyCard: Color(0xFF0E1F18),
    keyLine: Color(0xFFEBD7AE),
  );

  static const dark = Palette(
    paper: Color(0xFF0D1512),
    card: Color(0xFF151F1B),
    plate: Color(0xFF22302A),
    ink: Color(0xFFECE9E1),
    inkSoft: Color(0xFFC6CCC5),
    muted: Color(0xFF8A958F),
    line: Color(0xFF24322C),
    field: Color(0xFF1A2621),
    primary: Color(0xFFD2A866),
    onPrimary: Color(0xFF0D1512),
    accent: Color(0xFFD2A866),
    accentInk: Color(0xFFD9B274),
    onAccent: Color(0xFF0D1512),
    accentWash: Color(0xFF2B2A1D),
    error: Color(0xFFE28A6E),
    positive: Color(0xFF7FC29D),
    shadow: Color(0x66000000),
    mesh: [
      Color(0xFF0D1512),
      Color(0xFF15302A),
      Color(0xFF3A2F1C),
      Color(0xFF101C18),
    ],
    glassTint: Color(0x8A060B09),
    scrim: Color(0x99000000),
    onIsland: Color(0xFFF6F4EF),
    photoScrim: Color(0xD9060B09),
    onPhoto: Color(0xFFFBFAF7),
    mapLand: Color(0xFF111B17),
    mapBlock: Color(0xFF17231E),
    mapStreet: Color(0xFF25332D),
    mapPark: Color(0xFF183326),
    mapWater: Color(0xFF12292E),
    keyCard: Color(0xFF07100C),
    keyLine: Color(0xFFEBD7AE),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).extension<Palette>()!;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      paper: l(paper, other.paper),
      card: l(card, other.card),
      plate: l(plate, other.plate),
      ink: l(ink, other.ink),
      inkSoft: l(inkSoft, other.inkSoft),
      muted: l(muted, other.muted),
      line: l(line, other.line),
      field: l(field, other.field),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      accent: l(accent, other.accent),
      accentInk: l(accentInk, other.accentInk),
      onAccent: l(onAccent, other.onAccent),
      accentWash: l(accentWash, other.accentWash),
      error: l(error, other.error),
      positive: l(positive, other.positive),
      shadow: l(shadow, other.shadow),
      mesh: [for (var i = 0; i < mesh.length; i++) l(mesh[i], other.mesh[i])],
      glassTint: l(glassTint, other.glassTint),
      scrim: l(scrim, other.scrim),
      onIsland: l(onIsland, other.onIsland),
      photoScrim: l(photoScrim, other.photoScrim),
      onPhoto: l(onPhoto, other.onPhoto),
      mapLand: l(mapLand, other.mapLand),
      mapBlock: l(mapBlock, other.mapBlock),
      mapStreet: l(mapStreet, other.mapStreet),
      mapPark: l(mapPark, other.mapPark),
      mapWater: l(mapWater, other.mapWater),
      keyCard: l(keyCard, other.keyCard),
      keyLine: l(keyLine, other.keyLine),
    );
  }
}
