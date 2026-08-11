import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin/admin_navigation.dart';
import '../admin/admin_service.dart';
import '../navbar.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

class HomeShortcutButton extends StatelessWidget {
  const HomeShortcutButton({super.key, this.color});

  final Color? color;

  Future<void> _goHome(BuildContext context) async {
    if (Supabase.instance.client.auth.currentUser == null) return;
    bool isAdmin = false;
    try {
      isAdmin = await AdminService().isCurrentUserAdmin();
    } catch (_) {
      isAdmin = false;
    }
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => isAdmin ? const AdminNavigation() : const MainNavigation(),
      ),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Supabase.instance.client.auth.currentUser == null) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: AyoI18n.t('Ke Home'),
      onPressed: () => _goHome(context),
      icon: Icon(
        Icons.home_rounded,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
