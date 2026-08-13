import 'package:flutter/material.dart';

import '../jobs/job_helpers.dart';

LinearGradient ayoCategoryGradient(String name) {
  final String value = name.toLowerCase();
  if (value.contains('elektronik') || value.contains('administrasi')) {
    return const LinearGradient(
      colors: <Color>[Color(0xFFFBC85D), Color(0xFFF6990E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  if (value.contains('antar') ||
      value.contains('kurir') ||
      value.contains('kost')) {
    return const LinearGradient(
      colors: <Color>[Color(0xFFA4B792), Color(0xFFFBC85D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  if (value.contains('jasa titip') ||
      value.contains('design') ||
      value.contains('coding')) {
    return const LinearGradient(
      colors: <Color>[Color(0xFFF9BFBE), Color(0xFFF97465)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  if (value.contains('rumah tangga') ||
      value.contains('otomotif') ||
      value.contains('tukang')) {
    return const LinearGradient(
      colors: <Color>[Color(0xFFF97465), Color(0xFFFBC85D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  return const LinearGradient(
    colors: <Color>[Color(0xFFF9BFBE), Color(0xFFA4B792)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}


String categoryHomeIconAsset(String value) {
  final String category = value.toLowerCase();
  if (category.contains('elektronik')) {
    return 'assets/images/categories/home_elektronik.png';
  }
  if (category.contains('antar-jemput')) {
    return 'assets/images/categories/home_antar_jemput.png';
  }
  if (category.contains('jasa titip')) {
    return 'assets/images/categories/home_jasa_titip.png';
  }
  if (category.contains('kost')) {
    return 'assets/images/categories/home_survey_kost.png';
  }
  if (category.contains('administrasi')) {
    return 'assets/images/categories/home_administrasi.png';
  }
  if (category.contains('design') ||
      category.contains('coding') ||
      category.contains('desain') ||
      category.contains('pemrograman')) {
    return 'assets/images/categories/home_design_coding.png';
  }
  if (category.contains('rumah tangga') || category.contains('bersih')) {
    return 'assets/images/categories/home_rumah_tangga.png';
  }
  if (category.contains('otomotif')) {
    return 'assets/images/categories/home_otomotif.png';
  }
  if (category.contains('kurir')) {
    return 'assets/images/categories/home_kurir.png';
  }
  if (category.contains('tukang') || category.contains('perbaikan')) {
    return 'assets/images/categories/home_tukang.png';
  }
  if (category.contains('gaya hidup') ||
      category.contains('konsultasi') ||
      category.contains('wellness')) {
    return 'assets/images/categories/home_gaya_hidup.png';
  }
  return 'assets/images/categories/home_lainnya.png';
}

class AyoCategoryHomeIcon extends StatelessWidget {
  const AyoCategoryHomeIcon({
    super.key,
    required this.name,
    this.size = 72,
    this.radius = 20,
  });

  final String name;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? <Color>[
                  const Color(0xFF2B2421).withValues(alpha: 0.94),
                  categoryBackground(name).withValues(alpha: 0.72),
                ]
              : <Color>[
                  Colors.white.withValues(alpha: 0.94),
                  categoryBackground(name).withValues(alpha: 0.84),
                ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.90),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.22)
                : const Color(0xFF8A5540).withValues(alpha: 0.10),
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Image.asset(
        categoryHomeIconAsset(name),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(
          categoryIcon(name),
          color: jobDarkBrownColor,
          size: size * 0.52,
        ),
      ),
    );
  }
}

class AyoGradientBorder extends StatelessWidget {
  const AyoGradientBorder({
    super.key,
    required this.child,
    required this.gradient,
    this.radius = 18,
    this.width = 1.4,
  });

  final Widget child;
  final Gradient gradient;
  final double radius;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(width),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - width),
        child: child,
      ),
    );
  }
}

class AyoCategoryImage extends StatelessWidget {
  const AyoCategoryImage({
    super.key,
    required this.name,
    required this.width,
    required this.height,
    this.radius = 15,
    this.gradientBorder = true,
  });

  final String name;
  final double width;
  final double height;
  final double radius;
  final bool gradientBorder;

  @override
  Widget build(BuildContext context) {
    final String? asset = categoryImageAsset(name);
    final Widget visual = ColoredBox(
      color: categoryBackground(name),
      child: asset == null
          ? Center(
              child: Icon(
                categoryIcon(name),
                color: jobDarkBrownColor,
                size: height * 0.42,
              ),
            )
          : Image.asset(
              asset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Icon(
                  categoryIcon(name),
                  color: jobDarkBrownColor,
                  size: height * 0.42,
                ),
              ),
            ),
    );

    final Widget clipped = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: width, height: height, child: visual),
    );

    if (!gradientBorder) return clipped;

    return SizedBox(
      width: width,
      height: height,
      child: AyoGradientBorder(
        gradient: ayoCategoryGradient(name),
        radius: radius,
        width: 1.5,
        child: visual,
      ),
    );
  }
}
