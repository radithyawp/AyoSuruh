import 'dart:async';

import 'package:flutter/material.dart';


class HomeTriviaTicker extends StatefulWidget {
  const HomeTriviaTicker({
    super.key,
    required this.items,
  });

  final List<String> items;

  @override
  State<HomeTriviaTicker> createState() => _HomeTriviaTickerState();
}

class _HomeTriviaTickerState extends State<HomeTriviaTicker> {
  static const Color _sageColor = Color(0xFFA4B792);
  static const double _pixelsPerSecond = 33;
  static const double _loopGap = 88;
  final ScrollController _controller = ScrollController();
  final GlobalKey _cycleKey = GlobalKey();
  int _loopToken = 0;

  String get _tickerText {
    final List<String> safe = widget.items
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
    if (safe.isEmpty) {
      return 'Ada aja hal menarik di dunia. Siapa tahu ada yang bikin kamu bilang, "oh iya juga ya".';
    }
    return safe.join('     •     ');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restartLoop());
  }

  @override
  void didUpdateWidget(covariant HomeTriviaTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restartLoop());
    }
  }

  void _restartLoop() {
    _loopToken++;
    final int token = _loopToken;
    unawaited(_runLoop(token));
  }

  Future<void> _runLoop(int token) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    while (mounted && token == _loopToken) {
      if (!_controller.hasClients) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        continue;
      }

      final BuildContext? cycleContext = _cycleKey.currentContext;
      final double cycleWidth = cycleContext?.size?.width ?? 0;
      if (cycleWidth <= 4) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        continue;
      }

      if (_controller.offset != 0) {
        _controller.jumpTo(0);
      }

      final int milliseconds =
          ((cycleWidth / _pixelsPerSecond) * 1000).round().clamp(1000, 1 << 31);
      try {
        await _controller.animateTo(
          cycleWidth,
          duration: Duration(milliseconds: milliseconds),
          curve: Curves.linear,
        );
      } catch (_) {
        return;
      }
      if (!mounted || token != _loopToken) return;

      // The second copy is now in exactly the same visual position as the
      // first one was at offset 0, so this reset is invisible and the marquee
      // can continue without a pause or a visible snap.
      _controller.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _loopToken++;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.fromLTRB(6, 5, 0, 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _sageColor.withValues(alpha: 0.22),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: <Widget>[
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _sageColor,
              borderRadius: BorderRadius.circular(999),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _sageColor.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.bolt_rounded,
                  size: 15,
                  color: Colors.white,
                ),
                SizedBox(width: 4),
                Text(
                  'Sekilas',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.1,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRect(
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      key: _cycleKey,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _tickerText,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4E564A),
                          ),
                        ),
                        const SizedBox(width: _loopGap),
                      ],
                    ),
                    Text(
                      _tickerText,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4E564A),
                      ),
                    ),
                    const SizedBox(width: _loopGap),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
