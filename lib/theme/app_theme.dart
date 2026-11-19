import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';

/// Material theme that reproduces the look of the student web app: deep green header, warm
/// off-white background, white cards with hairline borders and 14px corners.
abstract class AppTheme {
  static ThemeData light() => _build(Palette.light, Brightness.light);
  static ThemeData dark() => _build(Palette.dark, Brightness.dark);

  static const SystemUiOverlayStyle overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  static ThemeData _build(Palette p, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: p.green2,
      brightness: brightness,
      primary: p.green2,
      onPrimary: Colors.white,
      surface: p.card,
      onSurface: p.ink,
      error: p.red,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
    final text = base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink).copyWith(
          bodyMedium: base.textTheme.bodyMedium?.copyWith(color: p.ink, fontSize: 16, height: 1.5),
          bodySmall: base.textTheme.bodySmall?.copyWith(color: p.muted, fontSize: 14.7, height: 1.5),
          titleLarge: base.textTheme.titleLarge?.copyWith(color: p.ink, fontSize: 24, fontWeight: FontWeight.w700, height: 1.25),
          titleMedium: base.textTheme.titleMedium?.copyWith(color: p.ink, fontSize: 18.7, fontWeight: FontWeight.w700, height: 1.3),
        );

    return base.copyWith(
      extensions: [p],
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      dividerColor: p.line,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: p.green,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlay,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16.8, fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        isDense: true,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.green2, width: 1.5)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.line)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.red)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.red, width: 1.5)),
        hintStyle: TextStyle(color: p.muted.withAlpha(180)),
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: p.green2, selectionHandleColor: p.green2),
      radioTheme: RadioThemeData(fillColor: WidgetStateProperty.all(p.green2)),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.green2 : Colors.transparent),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: p.muted, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.green2),
      snackBarTheme: SnackBarThemeData(backgroundColor: p.green, contentTextStyle: const TextStyle(color: Colors.white)),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.card),
    );
  }
}
