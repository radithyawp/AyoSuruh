import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeShortcutButton extends StatelessWidget {
  const HomeShortcutButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (Supabase.instance.client.auth.currentUser == null) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: 'Ke Home',
      onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (Route<dynamic> route) => false,
      ),
      icon: Icon(
        Icons.home_rounded,
        color: color ?? const Color(0xFF8B5A2B),
      ),
    );
  }
}
