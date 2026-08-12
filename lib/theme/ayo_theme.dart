import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../settings/app_settings.dart';

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

abstract final class AyoDarkColors {
  static const Color canvas = Color(0xFF12100F);
  static const Color surface = Color(0xFF1D1917);
  static const Color surfaceRaised = Color(0xFF27211E);
  static const Color border = Color(0xFF40352F);
  static const Color onSurface = Color(0xFFF7EEE9);
  static const Color muted = Color(0xFFB9AAA2);
  static const Color warm = Color(0xFFEBC8B0);
  static const Color navigation = Color(0xFF181412);
}

abstract final class AyoAdaptiveColors {
  static bool get isDark => AppSettingsController.instance.isDarkMode;

  static Color get canvas => isDark ? AyoDarkColors.canvas : AyoColors.canvas;
  static Color get surface => isDark ? AyoDarkColors.surface : AyoColors.surface;
  static Color get surfaceRaised =>
      isDark ? AyoDarkColors.surfaceRaised : AyoColors.surface;
  static Color get border => isDark ? AyoDarkColors.border : AyoColors.border;
  static Color get brown => isDark ? AyoDarkColors.warm : AyoColors.brown;
  static Color get brownDark =>
      isDark ? AyoDarkColors.onSurface : AyoColors.brownDark;
  static Color get muted => isDark ? AyoDarkColors.muted : AyoColors.muted;
  static Color get green => isDark ? AyoColors.green : AyoColors.greenDark;
}

abstract final class AyoTypography {
  /// Fredoka dipakai hemat: maskot AYOS, tutorial, success/empty state, dan
  /// headline promosi. UI utama memakai Plus Jakarta Sans dari [AyoTheme].
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
          color: color ?? Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationThickness: 1.2,
        );
  }
}

abstract final class AyoTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
    );

    final Color canvas = dark ? AyoDarkColors.canvas : AyoColors.canvas;
    final Color surface = dark ? AyoDarkColors.surface : AyoColors.surface;
    final Color surfaceRaised =
        dark ? AyoDarkColors.surfaceRaised : AyoColors.surface;
    final Color onSurface = dark ? AyoDarkColors.onSurface : AyoColors.brownDark;
    final Color muted = dark ? AyoDarkColors.muted : AyoColors.muted;
    final Color border = dark ? AyoDarkColors.border : AyoColors.border;
    final Color secondary = dark ? AyoColors.green : AyoColors.greenDark;

    final TextTheme jakarta = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
    final TextTheme textTheme = jakarta.copyWith(
      displaySmall: jakarta.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: onSurface,
      ),
      headlineSmall: jakarta.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: onSurface,
        height: 1.15,
      ),
      titleLarge: jakarta.titleLarge?.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        color: onSurface,
        height: 1.2,
      ),
      titleMedium: jakarta.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: onSurface,
        height: 1.25,
      ),
      titleSmall: jakarta.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      bodyLarge: jakarta.bodyLarge?.copyWith(
        fontSize: 15,
        height: 1.48,
        color: onSurface,
      ),
      bodyMedium: jakarta.bodyMedium?.copyWith(
        fontSize: 13.5,
        height: 1.45,
        color: onSurface,
      ),
      bodySmall: jakarta.bodySmall?.copyWith(
        fontSize: 11.5,
        height: 1.38,
        color: muted,
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
      seedColor: AyoColors.coral,
      brightness: brightness,
    ).copyWith(
      primary: AyoColors.coral,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: dark ? AyoDarkColors.canvas : Colors.white,
      tertiary: AyoColors.orange,
      onTertiary: AyoColors.brownDark,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: muted,
      surfaceContainer: dark ? const Color(0xFF211C1A) : const Color(0xFFFFFCFA),
      surfaceContainerHigh: dark ? const Color(0xFF27211E) : const Color(0xFFFFF8F4),
      surfaceContainerHighest: dark ? const Color(0xFF302824) : const Color(0xFFF7F0EC),
      outline: border,
      outlineVariant: dark ? const Color(0xFF342C28) : const Color(0xFFF3ECE7),
      error: dark ? const Color(0xFFFF8A80) : const Color(0xFFC54D43),
      onError: dark ? const Color(0xFF4C0805) : Colors.white,
    );

    Color? pressedOverlay(Set<WidgetState> states, Color color) {
      if (states.contains(WidgetState.pressed)) {
        return color.withValues(alpha: dark ? 0.18 : 0.13);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return color.withValues(alpha: dark ? 0.11 : 0.07);
      }
      return null;
    }

    final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      cardColor: surface,
      dividerColor: border,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: onSurface, size: 22),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: muted.withValues(alpha: 0.65),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFFF1DFD3) : AyoColors.brownDark,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: dark ? const Color(0xFF2F2723) : Colors.white,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AyoDarkColors.surfaceRaised : Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: dark ? const Color(0xFF9F918A) : const Color(0xFF9A908A),
          fontWeight: FontWeight.w500,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: dark ? AyoColors.amber : AyoColors.brown,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AyoColors.coral, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
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
            (Set<WidgetState> states) => pressedOverlay(states, AyoColors.coral),
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
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: border, width: 1.2),
          ),
          textStyle: WidgetStatePropertyAll<TextStyle>(textTheme.labelLarge!),
          animationDuration: const Duration(milliseconds: 140),
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) => pressedOverlay(states, AyoColors.coral),
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
            (Set<WidgetState> states) => pressedOverlay(states, AyoColors.coral),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 120),
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) => pressedOverlay(states, AyoColors.coral),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: border, width: 1.4),
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected)
              ? secondary
              : (dark ? AyoDarkColors.surfaceRaised : Colors.white);
        }),
        checkColor: WidgetStatePropertyAll<Color>(
          dark ? AyoDarkColors.canvas : Colors.white,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected)
              ? (dark ? AyoDarkColors.canvas : Colors.white)
              : (dark ? AyoDarkColors.muted : const Color(0xFFF7F1ED));
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected)
              ? secondary
              : (dark ? const Color(0xFF544943) : const Color(0xFFD9D0CB));
        }),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: dark ? AyoDarkColors.warm : AyoColors.brown,
        textColor: onSurface,
        titleTextStyle: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: textTheme.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AyoColors.orange,
        foregroundColor: AyoColors.brownDark,
        elevation: dark ? 1 : 3,
        focusElevation: 4,
        hoverElevation: 4,
        highlightElevation: 1,
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? AyoDarkColors.navigation : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: dark ? const Color(0xFF33402E) : const Color(0xFFEAF0E5),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? secondary : muted,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? secondary : muted,
            size: selected ? 24 : 22,
          );
        }),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: dark ? AyoDarkColors.surfaceRaised : Colors.white,
        selectedColor: AyoColors.green.withValues(alpha: dark ? 0.22 : 0.28),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: dark ? 1 : 2,
        backgroundColor: dark ? AyoDarkColors.surfaceRaised : AyoColors.brownDark,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: dark ? onSurface : Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AyoColors.coral,
        linearTrackColor: dark ? const Color(0xFF4A2E29) : AyoColors.coralSoft,
        circularTrackColor: dark ? const Color(0xFF4A2E29) : AyoColors.coralSoft,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AyoColors.coral,
        selectionColor: AyoColors.coral.withValues(alpha: dark ? 0.32 : 0.2),
        selectionHandleColor: AyoColors.coral,
      ),
    );
  }
}
