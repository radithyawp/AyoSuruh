import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Press feedback ringan untuk tappable surface yang sebelumnya hanya memakai
/// GestureDetector. Material buttons/InkWell tetap memakai ripple dari theme.
class AyoPressable extends StatefulWidget {
  const AyoPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.97,
    this.haptic = false,
    this.pressedOpacity = 0.78,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptic;
  final double pressedOpacity;
  final HitTestBehavior behavior;

  @override
  State<AyoPressable> createState() => _AyoPressableState();
}

class _AyoPressableState extends State<AyoPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  void _tap() {
    if (widget.haptic) {
      HapticFeedback.selectionClick();
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTap: widget.onTap == null ? null : _tap,
      child: AnimatedOpacity(
        opacity: _pressed ? widget.pressedOpacity : 1,
        duration: const Duration(milliseconds: 90),
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1,
          duration: Duration(milliseconds: _pressed ? 90 : 145),
          curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}
