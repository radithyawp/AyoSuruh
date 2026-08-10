import 'package:flutter/material.dart';

class NetworkPhotoGallery extends StatefulWidget {
  const NetworkPhotoGallery({
    super.key,
    required this.urls,
    this.aspectRatio = 16 / 10,
    this.borderRadius = 16,
  });

  final List<String> urls;
  final double aspectRatio;
  final double borderRadius;

  @override
  State<NetworkPhotoGallery> createState() => _NetworkPhotoGalleryState();
}

class _NetworkPhotoGalleryState extends State<NetworkPhotoGallery> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) return const SizedBox.shrink();

    return Column(
      children: <Widget>[
        AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                PageView.builder(
                  controller: _controller,
                  itemCount: widget.urls.length,
                  onPageChanged: (int value) => setState(() => _index = value),
                  itemBuilder: (BuildContext context, int index) {
                    final String url = widget.urls[index];
                    return GestureDetector(
                      onTap: () => _openViewer(context, index),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Color(0xFFF1ECE8),
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Color(0xFF9B8B82),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (widget.urls.length > 1)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${_index + 1}/${widget.urls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (widget.urls.length > 1) ...<Widget>[
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(widget.urls.length, (int index) {
              final bool active = index == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: active ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFFF9800)
                      : const Color(0xFFD9CEC6),
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Future<void> _openViewer(BuildContext context, int initialIndex) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (BuildContext dialogContext) {
        final PageController viewerController = PageController(
          initialPage: initialIndex,
        );
        int viewerIndex = initialIndex;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setViewerState) {
            return Dialog.fullscreen(
              backgroundColor: Colors.black,
              child: SafeArea(
                child: Stack(
                  children: <Widget>[
                    PageView.builder(
                      controller: viewerController,
                      itemCount: widget.urls.length,
                      onPageChanged: (int value) {
                        setViewerState(() => viewerIndex = value);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        return InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Center(
                            child: Image.network(
                              widget.urls[index],
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.broken_image_outlined,
                                size: 54,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: IconButton.filledTonal(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                    if (widget.urls.length > 1)
                      Positioned(
                        top: 16,
                        right: 18,
                        child: Text(
                          '${viewerIndex + 1}/${widget.urls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
