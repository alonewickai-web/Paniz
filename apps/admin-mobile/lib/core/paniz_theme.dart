import 'package:flutter/material.dart';

class PanizPalette extends ThemeExtension<PanizPalette> {
  const PanizPalette({
    required this.primary,
    required this.primarySoft,
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.muted,
    required this.line,
    required this.success,
    required this.warning,
    required this.error,
    required this.rose,
    required this.peach,
    required this.lilac,
    required this.mint,
    required this.coral,
  });

  final Color primary;
  final Color primarySoft;
  final Color canvas;
  final Color surface;
  final Color surfaceRaised;
  final Color ink;
  final Color muted;
  final Color line;
  final Color success;
  final Color warning;
  final Color error;
  final Color rose;
  final Color peach;
  final Color lilac;
  final Color mint;
  final Color coral;

  static const light = PanizPalette(
    primary: Color(0xFF0F766E),
    primarySoft: Color(0xFFD9F1EB),
    canvas: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    ink: Color(0xFF222936),
    muted: Color(0xFF5F6B78),
    line: Color(0xFFE3E8EC),
    success: Color(0xFF16803C),
    warning: Color(0xFF9A5B00),
    error: Color(0xFFB42318),
    rose: Color(0xFFF5C8D3),
    peach: Color(0xFFF2B66D),
    lilac: Color(0xFFC4B5FD),
    mint: Color(0xFF99F6E4),
    coral: Color(0xFFFDA4AF),
  );

  static const dark = PanizPalette(
    primary: Color(0xFF55B9AA),
    primarySoft: Color(0xFF1A3E39),
    canvas: Color(0xFF111917),
    surface: Color(0xFF1A2422),
    surfaceRaised: Color(0xFF222F2C),
    ink: Color(0xFFF2F7F6),
    muted: Color(0xFFB5C3C0),
    line: Color(0xFF384642),
    success: Color(0xFF69D3A4),
    warning: Color(0xFFFFC66E),
    error: Color(0xFFFF938D),
    rose: Color(0xFF855463),
    peach: Color(0xFF986638),
    lilac: Color(0xFF655B8D),
    mint: Color(0xFF386F66),
    coral: Color(0xFF9D5A65),
  );

  @override
  PanizPalette copyWith({
    Color? primary,
    Color? primarySoft,
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? ink,
    Color? muted,
    Color? line,
    Color? success,
    Color? warning,
    Color? error,
    Color? rose,
    Color? peach,
    Color? lilac,
    Color? mint,
    Color? coral,
  }) => PanizPalette(
    primary: primary ?? this.primary,
    primarySoft: primarySoft ?? this.primarySoft,
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    line: line ?? this.line,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    rose: rose ?? this.rose,
    peach: peach ?? this.peach,
    lilac: lilac ?? this.lilac,
    mint: mint ?? this.mint,
    coral: coral ?? this.coral,
  );

  @override
  PanizPalette lerp(ThemeExtension<PanizPalette>? other, double t) {
    if (other is! PanizPalette) return this;
    return PanizPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      rose: Color.lerp(rose, other.rose, t)!,
      peach: Color.lerp(peach, other.peach, t)!,
      lilac: Color.lerp(lilac, other.lilac, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
    );
  }
}

extension PanizThemeContext on BuildContext {
  PanizPalette get paniz => Theme.of(this).extension<PanizPalette>()!;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

class PanizTheme {
  static ThemeData get light => _build(PanizPalette.light, Brightness.light);
  static ThemeData get dark => _build(PanizPalette.dark, Brightness.dark);

  static ThemeData _build(PanizPalette palette, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
    ).copyWith(
      primary: palette.primary,
      onPrimary: isDark ? const Color(0xFF082C28) : Colors.white,
      primaryContainer: palette.primarySoft,
      onPrimaryContainer:
          isDark ? const Color(0xFFD7F4EE) : const Color(0xFF07564E),
      secondary: isDark ? const Color(0xFFF0AFC0) : const Color(0xFFB64565),
      onSecondary: isDark ? const Color(0xFF3D1422) : Colors.white,
      secondaryContainer:
          isDark ? const Color(0xFF492B35) : const Color(0xFFFBE8ED),
      onSecondaryContainer:
          isDark ? const Color(0xFFFFD9E2) : const Color(0xFF70283E),
      tertiary: isDark ? const Color(0xFFF2B66D) : const Color(0xFF9A5B00),
      onTertiary: isDark ? const Color(0xFF392100) : Colors.white,
      surface: palette.surface,
      onSurface: palette.ink,
      surfaceContainerLowest: palette.surface,
      surfaceContainerLow:
          isDark ? const Color(0xFF1D2926) : const Color(0xFFFCFDFD),
      surfaceContainer:
          isDark ? const Color(0xFF202C29) : const Color(0xFFF0F3F4),
      surfaceContainerHigh:
          isDark ? const Color(0xFF273531) : const Color(0xFFE9EEF0),
      outline: palette.muted,
      outlineVariant: palette.line,
      error: palette.error,
      onError: isDark ? const Color(0xFF4A0C09) : Colors.white,
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: palette.line),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      scaffoldBackgroundColor: palette.canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.canvas,
        foregroundColor: palette.ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        iconTheme: IconThemeData(color: palette.ink),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 1,
        shadowColor: const Color(0x1A17332E),
        shape: shape,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: palette.line,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? palette.surfaceRaised : palette.surface,
        labelStyle: TextStyle(color: palette.muted),
        hintStyle: TextStyle(color: palette.muted.withValues(alpha: .8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.primary, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        indicatorColor: palette.primarySoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color:
                states.contains(WidgetState.selected)
                    ? palette.primary
                    : palette.muted,
            fontSize: 11,
            fontWeight:
                states.contains(WidgetState.selected)
                    ? FontWeight.w800
                    : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color:
                states.contains(WidgetState.selected)
                    ? palette.primary
                    : palette.muted,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.primary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: palette.primary.withValues(alpha: .5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          minimumSize: const Size(48, 44),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? palette.primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? palette.primarySoft
                  : null,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceRaised,
        selectedColor: palette.primarySoft,
        side: BorderSide(color: palette.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        labelStyle: TextStyle(color: palette.ink, fontWeight: FontWeight.w600),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: palette.canvas,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadiusDirectional.horizontal(
            start: Radius.circular(24),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? const Color(0xFF29413B) : const Color(0xFF164E45),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.muted,
        textColor: palette.ink,
        selectedColor: palette.primary,
        selectedTileColor: palette.primarySoft.withValues(
          alpha: isDark ? .32 : .8,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minVerticalPadding: 8,
      ),
      textTheme: Typography.material2021(
        platform: TargetPlatform.android,
      ).black.apply(
        fontSizeFactor: 1.1,
        bodyColor: palette.ink,
        displayColor: palette.ink,
      ),
    );
  }
}
