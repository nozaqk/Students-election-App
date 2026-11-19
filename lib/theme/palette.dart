import 'package:flutter/material.dart';

/// The app's colour tokens, mirroring the CSS custom properties of the student web app.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.card,
    required this.ink,
    required this.muted,
    required this.line,
    required this.green,
    required this.green2,
    required this.gold,
    required this.red,
    required this.amber,
    required this.errBg,
    required this.errBorder,
    required this.errInk,
    required this.avatarBg,
  });

  static const Palette light = Palette(
    bg: Color(0xFFF6F4EE),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF14221C),
    muted: Color(0xFF5D6B64),
    line: Color(0xFFDCD8CB),
    green: Color(0xFF0B3D2E),
    green2: Color(0xFF15674D),
    gold: Color(0xFFF2C94C),
    red: Color(0xFFA62D2D),
    amber: Color(0xFF8A5A00),
    errBg: Color(0xFFF9E5E5),
    errBorder: Color(0xFFEBBCBC),
    errInk: Color(0xFFA62D2D),
    avatarBg: Color(0xFFE7EFE9),
  );

  static const Palette dark = Palette(
    bg: Color(0xFF0D1713),
    card: Color(0xFF15231C),
    ink: Color(0xFFEEF3EF),
    muted: Color(0xFF9DB0A6),
    line: Color(0xFF284037),
    green: Color(0xFF0B3D2E),
    green2: Color(0xFF2D9B76),
    gold: Color(0xFFF2C94C),
    red: Color(0xFFA62D2D),
    amber: Color(0xFF8A5A00),
    errBg: Color(0xFF3A1C1C),
    errBorder: Color(0xFF6B2C2C),
    errInk: Color(0xFFFFB4B4),
    avatarBg: Color(0xFFE7EFE9),
  );

  final Color bg;
  final Color card;
  final Color ink;
  final Color muted;
  final Color line;
  final Color green;
  final Color green2;
  final Color gold;
  final Color red;
  final Color amber;
  final Color errBg;
  final Color errBorder;
  final Color errInk;
  final Color avatarBg;

  /// Colour of the "winner" text in results.
  Color get win => const Color(0xFF0A6B3D);

  static const double radius = 14;

  @override
  Palette copyWith({
    Color? bg,
    Color? card,
    Color? ink,
    Color? muted,
    Color? line,
    Color? green,
    Color? green2,
    Color? gold,
    Color? red,
    Color? amber,
    Color? errBg,
    Color? errBorder,
    Color? errInk,
    Color? avatarBg,
  }) =>
      Palette(
        bg: bg ?? this.bg,
        card: card ?? this.card,
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        line: line ?? this.line,
        green: green ?? this.green,
        green2: green2 ?? this.green2,
        gold: gold ?? this.gold,
        red: red ?? this.red,
        amber: amber ?? this.amber,
        errBg: errBg ?? this.errBg,
        errBorder: errBorder ?? this.errBorder,
        errInk: errInk ?? this.errInk,
        avatarBg: avatarBg ?? this.avatarBg,
      );

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) {
    if (other is! Palette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return Palette(
      bg: l(bg, other.bg),
      card: l(card, other.card),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      line: l(line, other.line),
      green: l(green, other.green),
      green2: l(green2, other.green2),
      gold: l(gold, other.gold),
      red: l(red, other.red),
      amber: l(amber, other.amber),
      errBg: l(errBg, other.errBg),
      errBorder: l(errBorder, other.errBorder),
      errInk: l(errInk, other.errInk),
      avatarBg: l(avatarBg, other.avatarBg),
    );
  }
}

extension PaletteContext on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>() ?? Palette.light;
}
