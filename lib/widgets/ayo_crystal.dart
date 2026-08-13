import 'dart:ui';

import 'package:flutter/material.dart';

import '../l10n/ayo_localization.dart';
import '../theme/ayo_theme.dart';

/// Shared glass/crystal surface used by the vNext UI refinement.
///
/// The effect intentionally stays subtle so text remains readable in both
/// light and dark themes while still allowing scrolling content/gradients to
/// softly bleed through the surface.
class AyoCrystalSurface extends StatelessWidget {
  const AyoCrystalSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.blurSigma = 16,
    this.intensity = 1,
    this.elevated = true,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blurSigma;
  final double intensity;
  final bool elevated;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final double strength = intensity.clamp(0.0, 1.0).toDouble();

    final List<Color> colors = dark
        ? <Color>[
            const Color(0xFF2C2522).withValues(alpha: 0.82 * strength),
            const Color(0xFF1C1816).withValues(alpha: 0.76 * strength),
            const Color(0xFF33251F).withValues(alpha: 0.62 * strength),
          ]
        : <Color>[
            Colors.white.withValues(alpha: 0.88 * strength),
            const Color(0xFFFFF7F1).withValues(alpha: 0.76 * strength),
            const Color(0xFFFFE9E2).withValues(alpha: 0.58 * strength),
          ];

    final Color borderColor = dark
        ? Colors.white.withValues(alpha: 0.10 + (0.08 * strength))
        : Colors.white.withValues(alpha: 0.70 + (0.20 * strength));

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurSigma * strength,
          sigmaY: blurSigma * strength,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
              stops: const <double>[0, 0.56, 1],
            ),
            borderRadius: borderRadius,
            border: border ? Border.all(color: borderColor, width: 1) : null,
            boxShadow: elevated
                ? <BoxShadow>[
                    BoxShadow(
                      color: dark
                          ? Colors.black.withValues(alpha: 0.28 * strength)
                          : const Color(0xFF7A4B35)
                              .withValues(alpha: 0.10 * strength),
                      blurRadius: 24,
                      spreadRadius: -8,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class AyoCrystalBarLayer extends StatelessWidget {
  const AyoCrystalBarLayer({
    super.key,
    this.scrolled = false,
  });

  final bool scrolled;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final double intensity = scrolled ? 0.96 : 0.58;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: scrolled ? 0.10 : 0.04)
                : const Color(0xFF6E481F)
                    .withValues(alpha: scrolled ? 0.08 : 0.025),
          ),
        ),
        boxShadow: scrolled
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.22 : 0.06),
                  blurRadius: 20,
                  spreadRadius: -12,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: AyoCrystalSurface(
        intensity: intensity,
        blurSigma: scrolled ? 20 : 8,
        borderRadius: BorderRadius.zero,
        elevated: false,
        border: false,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class AyoGradientBackground extends StatelessWidget {
  const AyoGradientBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const <Color>[
                  Color(0xFF100F0E),
                  Color(0xFF171210),
                  Color(0xFF111715),
                  Color(0xFF1A1210),
                ]
              : const <Color>[
                  Color(0xFFFFFBF8),
                  Color(0xFFFFF4EC),
                  Color(0xFFF7FBF4),
                  Color(0xFFFFF6F0),
                ],
          stops: const <double>[0, 0.35, 0.68, 1],
        ),
      ),
      child: child,
    );
  }
}

class AyoSeeAllButton extends StatelessWidget {
  const AyoSeeAllButton({
    super.key,
    required this.onPressed,
    this.label = 'Lihat semua',
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).brightness == Brightness.dark
        ? AyoColors.amber
        : AyoColors.brown;

    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          splashColor: AyoColors.coral.withValues(alpha: 0.14),
          highlightColor: AyoColors.coral.withValues(alpha: 0.06),
          child: AyoCrystalSurface(
            intensity: 0.82,
            blurSigma: 12,
            elevated: false,
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            padding: const EdgeInsets.fromLTRB(13, 7, 10, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AyoText(
                  label,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 5),
                Icon(Icons.arrow_forward_rounded, size: 15, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
