import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Arma el ThemeData a partir de los tokens. Nada de colores sueltos aca:
/// todo sale de RtcLight / RtcDark, igual que en la web todo sale de las
/// variables CSS.
abstract final class RtcTheme {
  static ThemeData get light => _build(
    brightness: Brightness.light,
    background: RtcLight.background,
    foreground: RtcLight.foreground,
    card: RtcLight.card,
    cardForeground: RtcLight.cardForeground,
    primary: RtcLight.primary,
    primaryForeground: RtcLight.primaryForeground,
    secondary: RtcLight.secondary,
    secondaryForeground: RtcLight.secondaryForeground,
    muted: RtcLight.muted,
    mutedForeground: RtcLight.mutedForeground,
    destructive: RtcLight.destructive,
    destructiveForeground: RtcLight.destructiveForeground,
    border: RtcLight.border,
    ring: RtcLight.ring,
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    background: RtcDark.background,
    foreground: RtcDark.foreground,
    card: RtcDark.card,
    cardForeground: RtcDark.cardForeground,
    primary: RtcDark.primary,
    primaryForeground: RtcDark.primaryForeground,
    secondary: RtcDark.secondary,
    secondaryForeground: RtcDark.secondaryForeground,
    muted: RtcDark.muted,
    mutedForeground: RtcDark.mutedForeground,
    destructive: RtcDark.destructive,
    destructiveForeground: RtcDark.destructiveForeground,
    border: RtcDark.border,
    ring: RtcDark.ring,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color foreground,
    required Color card,
    required Color cardForeground,
    required Color primary,
    required Color primaryForeground,
    required Color secondary,
    required Color secondaryForeground,
    required Color muted,
    required Color mutedForeground,
    required Color destructive,
    required Color destructiveForeground,
    required Color border,
    required Color ring,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: primaryForeground,
      secondary: secondary,
      onSecondary: secondaryForeground,
      error: destructive,
      onError: destructiveForeground,
      surface: background,
      onSurface: foreground,
      // `muted` de shadcn es el gris de fondo; `mutedForeground` el texto
      // secundario. Material los llama surfaceContainerHighest / onSurfaceVariant.
      surfaceContainerHighest: muted,
      onSurfaceVariant: mutedForeground,
      outline: border,
      outlineVariant: border,
      // Las tarjetas tienen su propio fondo en shadcn (en dark es distinto
      // del gris que Material generaria por elevacion).
      surfaceContainer: card,
      surfaceContainerLow: card,
      surfaceTint:
          Colors.transparent, // Material tinta por elevacion; shadcn no.
    );

    final text = _textTheme(foreground, mutedForeground);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: border,
      fontFamily: RtcType.fontFamily,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,

      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: RtcType.lg.copyWith(
          color: foreground,
          fontWeight: RtcType.semibold,
        ),
      ),

      // Card: rounded-xl (12px) + ring-1 ring-foreground/10, sin elevacion.
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: RtcRadius.brXl,
          side: BorderSide(color: cardForeground.withValues(alpha: 0.10)),
        ),
      ),

      // Boton `variant="default"`: bg-primary, rounded-lg (10px), text-sm
      // font-medium. La altura real la define cada `size` en el sitio.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: primaryForeground,
          textStyle: RtcType.sm.copyWith(fontWeight: RtcType.medium),
          minimumSize: const Size(
            0,
            44,
          ), // 44 = minimo tactil, no los 32 de la web
          padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s4),
          shape: const RoundedRectangleBorder(borderRadius: RtcRadius.brLg),
          elevation: 0,
        ),
      ),

      // Boton `variant="outline"`.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: background,
          textStyle: RtcType.sm.copyWith(fontWeight: RtcType.medium),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s4),
          side: BorderSide(color: border),
          shape: const RoundedRectangleBorder(borderRadius: RtcRadius.brLg),
        ),
      ),

      // Boton `variant="ghost"` / `variant="link"`.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          textStyle: RtcType.sm.copyWith(fontWeight: RtcType.medium),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s3),
          shape: const RoundedRectangleBorder(borderRadius: RtcRadius.brLg),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        hintStyle: RtcType.sm.copyWith(color: mutedForeground),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s3,
          vertical: RtcSpace.s3,
        ),
        border: OutlineInputBorder(
          borderRadius: RtcRadius.brLg,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: RtcRadius.brLg,
          borderSide: BorderSide(color: border),
        ),
        // focus-visible:ring-3 ring-ring/50 => borde de marca al enfocar.
        focusedBorder: OutlineInputBorder(
          borderRadius: RtcRadius.brLg,
          borderSide: BorderSide(color: ring, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: RtcRadius.brLg,
          borderSide: BorderSide(color: destructive),
        ),
      ),

      // Los sheets son el patron central de la app (MobileStackSheet).
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: mutedForeground.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(RtcRadius.xxl),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: RtcRadius.brXl),
      ),

      // Badge / chips: rounded-full, texto xs.
      chipTheme: ChipThemeData(
        backgroundColor: muted,
        labelStyle: RtcType.xs.copyWith(
          color: foreground,
          fontWeight: RtcType.medium,
        ),
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(borderRadius: RtcRadius.brFull),
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s3,
          vertical: RtcSpace.s1,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: RtcType.sm.copyWith(color: cardForeground),
        actionTextColor: primary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: RtcRadius.brLg),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: muted,
      ),
    );
  }

  static TextTheme _textTheme(Color foreground, Color mutedForeground) {
    return TextTheme(
      displayLarge: RtcType.xl5.copyWith(
        color: foreground,
        fontWeight: RtcType.bold,
      ),
      displayMedium: RtcType.xl4.copyWith(
        color: foreground,
        fontWeight: RtcType.bold,
      ),
      displaySmall: RtcType.xl3.copyWith(
        color: foreground,
        fontWeight: RtcType.bold,
      ),
      headlineMedium: RtcType.xl2.copyWith(
        color: foreground,
        fontWeight: RtcType.semibold,
      ),
      headlineSmall: RtcType.xl.copyWith(
        color: foreground,
        fontWeight: RtcType.semibold,
      ),
      titleLarge: RtcType.lg.copyWith(
        color: foreground,
        fontWeight: RtcType.semibold,
      ),
      titleMedium: RtcType.base.copyWith(
        color: foreground,
        fontWeight: RtcType.medium,
      ),
      titleSmall: RtcType.sm.copyWith(
        color: foreground,
        fontWeight: RtcType.medium,
      ),
      bodyLarge: RtcType.base.copyWith(color: foreground),
      bodyMedium: RtcType.sm.copyWith(color: foreground),
      bodySmall: RtcType.xs.copyWith(color: mutedForeground),
      labelLarge: RtcType.sm.copyWith(
        color: foreground,
        fontWeight: RtcType.medium,
      ),
      labelMedium: RtcType.xs.copyWith(color: mutedForeground),
      labelSmall: RtcType.xs.copyWith(color: mutedForeground),
    );
  }
}
