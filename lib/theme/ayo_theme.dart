import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AyoColors {
  static const Color coral = Color(0xFFF97465);
  static const Color coralSoft = Color(0xFFFFE5DE);
  static const Color orange = Color(0xFFF6990E);
  static const Color amber = Color(0xFFFBC85D);
  static const Color green = Color(0xFFA4B792);
  static const Color greenDark = Color(0xFF526846);
  static const Color brown = Color(0xFF6E481F);
  static const Color brownDark = Color(0xFF3F3027);
  static const Color canvas = Color(0xFFFFFAF7);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFECE2DC);
  static const Color muted = Color(0xFF746A64);
}

abstract final class AyoTypography {
  /// Fredoka dipakai hemat: maskot AYOS, tutorial, success/empty state, dan
  /// headline promosi. UI utama tetap memakai Plus Jakarta Sans dari [AyoTheme].
  static TextStyle accent({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AyoColors.brown,
    double height = 1.15,
  }) {
    return GoogleFonts.fredoka(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle link(BuildContext context, {Color? color}) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: color ?? AyoColors.coral,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationThickness: 1.2,
        );
  }
}

abstract final class AyoTheme {
  static ThemeData light() {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );

    final TextTheme jakarta = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
    final TextTheme textTheme = jakarta.copyWith(
      displaySmall: jakarta.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: AyoColors.brownDark,
      ),
      headlineSmall: jakarta.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AyoColors.brownDark,
        height: 1.15,
      ),
      titleLarge: jakarta.titleLarge?.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        color: AyoColors.brownDark,
        height: 1.2,
      ),
      titleMedium: jakarta.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AyoColors.brownDark,
        height: 1.25,
      ),
      titleSmall: jakarta.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AyoColors.brownDark,
      ),
      bodyLarge: jakarta.bodyLarge?.copyWith(
        fontSize: 15,
        height: 1.48,
        color: AyoColors.brownDark,
      ),
      bodyMedium: jakarta.bodyMedium?.copyWith(
        fontSize: 13.5,
        height: 1.45,
        color: AyoColors.brownDark,
      ),
      bodySmall: jakarta.bodySmall?.copyWith(
        fontSize: 11.5,
        height: 1.38,
        color: AyoColors.muted,
      ),
      labelLarge: jakarta.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.05,
      ),
      labelMedium: jakarta.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: jakarta.labelSmall?.copyWith(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
      ),
    );

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AyoColors.orange,
      brightness: Brightness.light,
    ).copyWith(
      primary: AyoColors.orange,
      onPrimary: Colors.white,
      secondary: AyoColors.greenDark,
      onSecondary: Colors.white,
      tertiary: AyoColors.coral,
      surface: AyoColors.surface,
      onSurface: AyoColors.brownDark,
      outline: AyoColors.border,
      outlineVariant: const Color(0xFFF3ECE7),
    );

    Color? pressedOverlay(Set<WidgetState> states, Color color) {
      if (states.contains(WidgetState.pressed)) {
        return color.withValues(alpha: 0.13);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return color.withValues(alpha: 0.07);
      }
      return null;
    }

    final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AyoColors.canvas,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: AyoColors.canvas,
        foregroundColor: AyoColors.brownDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: AyoColors.brownDark, size: 22),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF9A908A),
          fontWeight: FontWeight.w500,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: AyoColors.brown,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AyoColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AyoColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AyoColors.orange, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFC54D43)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFC54D43), width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 48)),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(buttonShape),
          textStyle: WidgetStatePropertyAll<TextStyle>(textTheme.labelLarge!),
          animationDuration: const Duration(milliseconds: 140),
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) => pressedOverlay(states, Colors.white),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 48)),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(buttonShape),
          textStyle: WidgetStatePropertyAll<TextStyle>(textTheme.labelLarge!),
          animationDuration: const Duration(milliseconds: 140),
          elevation: WidgetStateProperty.resolveWith<double>((states) {
            return states.contains(WidgetState.pressed) ? 0 : 1.5;
          }),
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) =>
                pressedOverlay(states, AyoColors.coral),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 48)),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(buttonShape),
          side: const WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: AyoColors.border, width: 1.2),
          ),
          textStyle: WidgetStatePropertyAll<TextStyle>(textTheme.labelLarge!),
          animationDuration: const Duration(milliseconds: 140),
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) =>
                pressedOverlay(states, AyoColors.coral),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll<TextStyle>(
            textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700),
          ),
          animationDuration: const Duration(milliseconds: 120),
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) =>
                pressedOverlay(states, AyoColors.coral),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 120),
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) =>
                pressedOverlay(states, AyoColors.coral),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: const BorderSide(color: AyoColors.border, width: 1.4),
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected)
              ? AyoColors.greenDark
              : Colors.white;
        }),
        checkColor: const WidgetStatePropertyAll<Color>(Colors.white),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFFF7F1ED);
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected)
              ? AyoColors.greenDark
              : const Color(0xFFD9D0CB);
        }),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AyoColors.brown,
        textColor: AyoColors.brownDark,
        titleTextStyle: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: textTheme.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AyoColors.orange,
        foregroundColor: AyoColors.brownDark,
        elevation: 3,
        focusElevation: 4,
        hoverElevation: 4,
        highlightElevation: 1,
        shape: StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: const Color(0xFFEAF0E5),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? AyoColors.greenDark : AyoColors.muted,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AyoColors.greenDark : AyoColors.muted,
            size: selected ? 24 : 22,
          );
        }),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: AyoColors.green.withValues(alpha: 0.28),
        side: const BorderSide(color: AyoColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFF0E8E3),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        backgroundColor: Colors.white,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AyoColors.brownDark,
          fontWeight: FontWeight.w600,
        ),
        insetPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AyoColors.coral,
        linearTrackColor: Color(0xFFFFE5DE),
        circularTrackColor: Color(0xFFFFE5DE),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AyoColors.coral,
        selectionColor: Color(0x55F97465),
        selectionHandleColor: AyoColors.coral,
      ),
    );
  }
}
