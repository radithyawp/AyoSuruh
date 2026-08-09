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
