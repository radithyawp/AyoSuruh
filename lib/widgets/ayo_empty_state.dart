import 'package:flutter/material.dart';

import '../theme/ayo_theme.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

class AyoEmptyState extends StatelessWidget {
  const AyoEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.assetPath = 'assets/images/ayos/ayos_idea.png',
    this.badgeIcon,
    this.action,
    this.compact = false,
  });

  final String title;
  final String description;
  final String assetPath;
  final IconData? badgeIcon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double imageSize = compact ? 74 : 98;
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 18 : 30,
          vertical: compact ? 18 : 42,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: imageSize + 12,
              height: imageSize + 8,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Image.asset(
                    assetPath,
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.contain,
                  ),
                  if (badgeIcon != null)
                    Positioned(
                      right: 0,
                      bottom: 2,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.colorScheme.outline),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x18000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          badgeIcon,
                          size: 18,
                          color: AyoColors.orange,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: compact ? 10 : 14),
            AyoText(
              title,
              textAlign: TextAlign.center,
              style: AyoTypography.accent(
                fontSize: compact ? 16 : 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: AyoText(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 14),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
