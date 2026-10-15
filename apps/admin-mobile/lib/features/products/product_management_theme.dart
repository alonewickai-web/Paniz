import 'package:flutter/material.dart';

/// Product screens use a warm, quiet palette without changing the rest of the
/// admin app's theme.
class ProductManagementTheme extends StatelessWidget {
  const ProductManagementTheme({super.key, required this.child});

  final Widget child;

  static const plum = Color(0xFF795A87);
  static const canvas = Color(0xFFF8F7F4);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF29232D);
  static const muted = Color(0xFF716A74);
  static const line = Color(0xFFE8E3E9);

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final dark = base.brightness == Brightness.dark;
    final page = dark ? const Color(0xFF18151B) : canvas;
    final card = dark ? const Color(0xFF242029) : surface;
    final foreground = dark ? const Color(0xFFF4EFF5) : ink;
    final secondary = dark ? const Color(0xFFC7B9CE) : muted;
    final border = dark ? const Color(0xFF403A46) : line;
    final primary = dark ? const Color(0xFFC4A9D0) : plum;
    final primaryContainer =
        dark ? const Color(0xFF403347) : const Color(0xFFF0EAF3);

    final scheme = base.colorScheme.copyWith(
      primary: primary,
      onPrimary: dark ? const Color(0xFF281D2E) : Colors.white,
      primaryContainer: primaryContainer,
      onPrimaryContainer: dark ? const Color(0xFFF0E5F5) : plum,
      secondary: dark ? const Color(0xFFD9C2E3) : const Color(0xFF93779F),
      surface: card,
      onSurface: foreground,
      surfaceContainerLowest: card,
      surfaceContainerLow:
          dark ? const Color(0xFF211D25) : const Color(0xFFFCFBF9),
      surfaceContainer:
          dark ? const Color(0xFF2B2630) : const Color(0xFFF1EEF1),
      surfaceContainerHigh:
          dark ? const Color(0xFF332D38) : const Color(0xFFECE7ED),
      onSurfaceVariant: secondary,
      outline: secondary,
      outlineVariant: border,
    );

    final roundedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide(color: border),
    );

    return Theme(
      data: base.copyWith(
        colorScheme: scheme,
        scaffoldBackgroundColor: page,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: page,
          foregroundColor: foreground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 66,
        ),
        cardTheme: CardThemeData(
          color: card,
          surfaceTintColor: Colors.transparent,
          elevation: dark ? 0 : 1.5,
          shadowColor: const Color(0x120F0A14),
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: border),
          ),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: card,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 15,
          ),
          border: roundedBorder,
          enabledBorder: roundedBorder,
          focusedBorder: roundedBorder.copyWith(
            borderSide: BorderSide(color: primary, width: 1.6),
          ),
          errorBorder: roundedBorder.copyWith(
            borderSide: BorderSide(color: scheme.error),
          ),
          focusedErrorBorder: roundedBorder.copyWith(
            borderSide: BorderSide(color: scheme.error, width: 1.6),
          ),
          labelStyle: TextStyle(color: secondary),
          hintStyle: TextStyle(color: secondary.withValues(alpha: .8)),
        ),
        dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: card,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: border),
          ),
        ),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: card,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            side: BorderSide(color: border),
          ),
        ),
        dividerTheme: base.dividerTheme.copyWith(color: border),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: primary,
            side: BorderSide(color: border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
        chipTheme: base.chipTheme.copyWith(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: BorderSide(color: border),
          ),
          side: BorderSide(color: border),
          backgroundColor: card,
          selectedColor: primaryContainer,
          labelStyle: TextStyle(color: foreground),
          secondaryLabelStyle: TextStyle(color: primary),
        ),
      ),
      child: child,
    );
  }
}
