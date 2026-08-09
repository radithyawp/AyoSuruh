import 'package:flutter/material.dart';

class AyoAvatar extends StatelessWidget {
  const AyoAvatar({
    super.key,
    this.imageUrl,
    this.size = 48,
    this.backgroundColor = const Color(0xFFFFF1E4),
    this.logoPadding = 7,
  });

  final String? imageUrl;
  final double size;
  final Color backgroundColor;
  final double logoPadding;

  @override
  Widget build(BuildContext context) {
    final String url = imageUrl?.trim() ?? '';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Padding(
              padding: EdgeInsets.all(logoPadding),
              child: Image.asset(
                'assets/images/Logo_Ayo_Suruh.png',
                fit: BoxFit.contain,
              ),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Padding(
                padding: EdgeInsets.all(logoPadding),
                child: Image.asset(
                  'assets/images/Logo_Ayo_Suruh.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
    );
  }
}
