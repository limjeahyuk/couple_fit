import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Design tokens (from the "커플 운동 앱" canvas).
const bg = Color(0xFF111318), ink = bg, navBg = Color(0xFF16181E), navLine = Color(0xFF23262E);
const surf = Color(0xFF1B1E25), surf2 = Color(0xFF252932), off = Color(0xFF2E333D);
const lime = Color(0xFFC6F36B), coral = Color(0xFFFF8E6E), blue = Color(0xFF8DB8FF), yellow = Color(0xFFFFC56E);
const fg = Color(0xFFF2F3F5), sub = Color(0xFFC4C8D0), muted = Color(0xFF9AA0AC), dim = Color(0xFF6B717D), navOff = Color(0xFF8A909C);

ThemeData appTheme() {
  final base = ThemeData.dark();
  final radius = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
  return base.copyWith(
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(primary: lime, onPrimary: ink, secondary: coral, surface: surf, onSurface: fg),
    textTheme: GoogleFonts.ibmPlexSansKrTextTheme(base.textTheme).apply(bodyColor: fg, displayColor: fg),
    appBarTheme: const AppBarTheme(backgroundColor: bg, surfaceTintColor: Colors.transparent),
    dialogTheme: const DialogThemeData(backgroundColor: surf),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: surf),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: lime,
            foregroundColor: ink,
            minimumSize: const Size.fromHeight(60),
            shape: radius,
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: lime, minimumSize: const Size(44, 44), textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surf2,
      labelStyle: const TextStyle(color: muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? lime : off),
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? ink : muted),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}

/// Chart series colors: lime/coral stepped into the dark-surface lightness band (OKLCH L .665 / .55)
/// so lines don't glare; validated on #1B1E25 (dataviz validate_palette.js: all checks pass, CVD ΔE 11.3).
const chartMe = Color(0xFF7CA400), chartPartner = Color(0xFFB64C2E);

/// Numbers use Space Grotesk, like the design.
TextStyle digits(double size, {Color color = fg, FontWeight w = FontWeight.w700}) =>
    GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: w, color: color, height: 1.1);

TextStyle ts(double size, {Color color = fg, FontWeight w = FontWeight.w400, double? h}) =>
    TextStyle(fontSize: size, color: color, fontWeight: w, height: h);

Widget box(Widget child, {double r = 24, EdgeInsets p = const EdgeInsets.all(20), Color c = surf, BoxBorder? border}) =>
    Container(
        padding: p,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(r), border: border),
        child: child);

/// Tappable surface card.
Widget tapBox(VoidCallback onTap, Widget child, {double r = 20, EdgeInsets p = const EdgeInsets.all(18)}) => Material(
    color: surf,
    borderRadius: BorderRadius.circular(r),
    child: InkWell(borderRadius: BorderRadius.circular(r), onTap: onTap, child: Padding(padding: p, child: child)));

/// Avatar colors people can pick (all light, so the ink initial stays readable).
const avatarColors = [lime, coral, blue, yellow, Color(0xFF7FE0C3), Color(0xFFB9A6FF), Color(0xFFFF9EC7), Color(0xFFE8D5B5)];
const avatarEmojis = ['🐻', '🐰', '🐱', '🐶', '🦊', '🐼', '🐯', '🐨', '🐸', '🐧', '🦁', '🐹', '💪', '🔥', '⭐', '🏃'];

/// [look] is a user's saved `avatar` map ({bg, emoji}); without one: initial on [c].
Widget avatar(String name, Color c, {double size = 36, bool ring = false, Map? look}) {
  final emoji = look?['emoji'] as String?;
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
        color: look?['bg'] is int ? Color(look!['bg'] as int) : c,
        shape: BoxShape.circle,
        border: ring ? Border.all(color: bg, width: 2) : null),
    child: Text(emoji ?? (name.isEmpty ? '?' : name.characters.first),
        style: emoji != null ? TextStyle(fontSize: size * 0.52, height: 1.1) : ts(size * 0.39, color: ink, w: FontWeight.w700)),
  );
}

Widget dot(Color c, [double s = 7]) =>
    Container(width: s, height: s, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

Widget legend(Color c, String label) =>
    Row(mainAxisSize: MainAxisSize.min, children: [dot(c, 8), const SizedBox(width: 5), Text(label, style: ts(12, color: muted))]);

Widget ring(double size, double value, Color color, double stroke) => SizedBox(
    width: size,
    height: size,
    child: CircularProgressIndicator(
        value: value.clamp(0, 1).toDouble(), strokeWidth: stroke, color: color, backgroundColor: surf2, strokeCap: StrokeCap.round));

Widget bar(double value, Color color, {double h = 6}) => LinearProgressIndicator(
    value: value.clamp(0, 1).toDouble(), minHeight: h, color: color, backgroundColor: surf2, borderRadius: BorderRadius.circular(h / 2));

Widget h1(String text) => Text(text, style: ts(28, w: FontWeight.w700, h: 1.35));

const checkIcon = Icons.check_rounded;

/// Selectable rounded chip (metric / filter / category pickers).
Widget pill(String label, bool on, VoidCallback onTap) => Padding(
  padding: const EdgeInsets.only(right: 8, bottom: 8),
  child: Material(
    color: on ? lime : surf2,
    shape: const StadiumBorder(),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        // widthFactor 1: center vertically but stay as wide as the label (alignment alone fills the row).
        child: Center(widthFactor: 1, child: Text(label, style: ts(13, w: FontWeight.w600, color: on ? ink : sub))),
      ),
    ),
  ),
);

/// ▲ value ▼ with its label; [step] gets +1 / -1. [onTapValue] lets the value be typed instead.
Widget stepper(String value, String label, void Function(int dir) step,
        {double size = 44, bool arrows = true, VoidCallback? onTapValue}) =>
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (arrows)
          IconButton(
            tooltip: '$label 올리기',
            onPressed: () => step(1),
            visualDensity: size < 30 ? VisualDensity.compact : null,
            icon: Icon(Icons.keyboard_arrow_up_rounded, color: sub, size: size < 30 ? 26 : 32),
          ),
        GestureDetector(
          onTap: onTapValue,
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: digits(size), maxLines: 1)),
        ),
        Text(label, style: ts(12, color: muted)),
        if (arrows)
          IconButton(
            tooltip: '$label 내리기',
            onPressed: () => step(-1),
            visualDensity: size < 30 ? VisualDensity.compact : null,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: sub, size: size < 30 ? 26 : 32),
          ),
      ],
    );
