import 'package:flutter/material.dart';

import 'package:ayosuruh/l10n/ayo_localization.dart';

enum AyoSnackType { success, error, info }

abstract final class AyoSnackBar {
  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      message,
      AyoSnackType.success,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      message,
      AyoSnackType.error,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void info(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      message,
      AyoSnackType.info,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void _show(
    BuildContext context,
    String message,
    AyoSnackType type, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final Color background;
    final Color foreground;
    final Color iconBackground;
    final IconData icon;

    switch (type) {
      case AyoSnackType.error:
        background = const Color(0xFFC94E45);
        foreground = Colors.white;
        iconBackground = Colors.white.withValues(alpha: 0.16);
        icon = Icons.error_outline_rounded;
        break;
      case AyoSnackType.info:
        background = const Color(0xFF4D7EA8);
        foreground = Colors.white;
        iconBackground = Colors.white.withValues(alpha: 0.16);
        icon = Icons.info_outline_rounded;
        break;
      case AyoSnackType.success:
        background = Theme.of(context).colorScheme.surface;
        foreground = Theme.of(context).colorScheme.onSurface;
        iconBackground = Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF3A2B24)
            : const Color(0xFFFFF1E7);
        icon = Icons.check_circle_outline_rounded;
        break;
    }

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 9,
        backgroundColor: background,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  'assets/images/Logo_Ayo_Suruh.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    icon,
                    color: foreground,
                    size: 23,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: AyoText(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(width: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: foreground,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    onAction();
                  },
                  child: AyoText(
                    actionLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
              IconButton(
                tooltip: AyoI18n.t('Tutup'),
                visualDensity: VisualDensity.compact,
                onPressed: () => messenger.hideCurrentSnackBar(),
                icon: Icon(Icons.close_rounded, color: foreground, size: 19),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
