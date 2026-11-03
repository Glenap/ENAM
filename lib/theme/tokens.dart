import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// FINN design tokens.
///
/// One aesthetic: an editorial financial terminal. Near-black surfaces, a single
/// amber accent, semantic up/down only for market direction, tabular numerals
/// everywhere. No gradients, no emoji, no card-grid mush.
class T {
  // surfaces (dark, default)
  static const bg = Color(0xFF0A0A0B);
  static const surface = Color(0xFF121214);
  static const surfaceHi = Color(0xFF17171A);
  static const line = Color(0xFF24242A);
  static const lineSoft = Color(0xFF1B1B20);

  // ink
  static const ink = Color(0xFFF2F2F0);
  static const ink2 = Color(0xFFA8A8A2);
  static const ink3 = Color(0xFF6E6E68);

  // accent + semantics
  static const accent = Color(0xFFD9A441);
  static const up = Color(0xFF3FB27F);
  static const down = Color(0xFFD1534C);
  static const warn = Color(0xFFD98A3A);

  // light mode
  static const lBg = Color(0xFFF7F6F3);
  static const lSurface = Color(0xFFFFFFFF);
  static const lSurfaceHi = Color(0xFFFAF9F6);
  static const lLine = Color(0xFFE2E0D9);
  static const lInk = Color(0xFF14140F);
  static const lInk2 = Color(0xFF56564E);
  static const lInk3 = Color(0xFF8A8A80);

  static const radius = 14.0;
  static const gap = 12.0;
  static const pad = 16.0;
  static const tabH = 56.0;
}

class Palette extends InheritedWidget {
  const Palette({super.key, required this.dark, required super.child});
  final bool dark;

  static Palette of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<Palette>()!;

  Color get bg => dark ? T.bg : T.lBg;
  Color get surface => dark ? T.surface : T.lSurface;
  Color get surfaceHi => dark ? T.surfaceHi : T.lSurfaceHi;
  Color get line => dark ? T.line : T.lLine;
  Color get lineSoft => dark ? T.lineSoft : T.lLine;
  Color get ink => dark ? T.ink : T.lInk;
  Color get ink2 => dark ? T.ink2 : T.lInk2;
  Color get ink3 => dark ? T.ink3 : T.lInk3;

  @override
  bool updateShouldNotify(Palette old) => old.dark != dark;
}

/// Tabular figures: every number in the app is right-aligned in a mono face.
class Num extends StatelessWidget {
  const Num(this.text,
      {super.key, this.size = 13, this.weight = FontWeight.w500, this.color, this.align});
  final String text;
  final double size;
  final FontWeight weight;
  final Color? color;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        textAlign: align,
        style: TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color,
          fontFamily: 'monospace',
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: -0.2,
          height: 1.25,
        ));
  }
}

/// Headline face: a display serif for the briefing sentence and section titles.
class Display extends StatelessWidget {
  const Display(this.text, {super.key, this.size = 22, this.color, this.height = 1.18});
  final String text;
  final double size;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
          fontSize: size,
          height: height,
          fontWeight: FontWeight.w600,
          color: color ?? Palette.of(context).ink,
          fontFamily: 'serif',
          letterSpacing: -0.3,
        ));
  }
}

class Label extends StatelessWidget {
  const Label(this.text, {super.key, this.color, this.size = 10.5, this.spacing = 0.8});
  final String text;
  final Color? color;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: TextStyle(
          fontSize: size,
          letterSpacing: spacing,
          fontWeight: FontWeight.w600,
          color: color ?? Palette.of(context).ink3,
        ));
  }
}

ThemeData buildTheme(bool dark) {
  final p = dark
      ? const Palette(dark: true, child: SizedBox())
      : const Palette(dark: false, child: SizedBox());
  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: T.accent,
      brightness: dark ? Brightness.dark : Brightness.light,
      surface: p.surface,
      primary: T.accent,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    textTheme: const TextTheme().apply(bodyColor: p.ink, displayColor: p.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg, surfaceTintColor: Colors.transparent,
      elevation: 0, centerTitle: false,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.surfaceHi, contentTextStyle: TextStyle(color: p.ink),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Widget hairline(BuildContext c, {double opacity = 1}) => Container(
      height: 1, color: Palette.of(c).line.withValues(alpha: opacity));

String fmtCr(num? v, {int dp = 0}) {
  if (v == null) return '—';
  final s = v.abs().toStringAsFixed(dp);
  return '${v < 0 ? '-' : ''}${_group(s)}';
}

String _group(String s) {
  final parts = s.split('.');
  final int0 = parts[0];
  final buf = StringBuffer();
  for (int i = 0; i < int0.length; i++) {
    if (i > 0 && (int0.length - i) % 3 == 0) buf.write(',');
    buf.write(int0[i]);
  }
  return parts.length > 1 ? '$buf.${parts[1]}' : buf.toString();
}

String fmtPct(num? v, {int dp = 1, bool sign = true}) {
  if (v == null) return '—';
  final s = '${v.abs().toStringAsFixed(dp)}%';
  return v > 0 && sign ? '+$s' : (v < 0 ? '-$s' : s);
}
