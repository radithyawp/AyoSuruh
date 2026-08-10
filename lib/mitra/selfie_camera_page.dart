import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../widgets/ayo_snackbar.dart';

const Color _cameraOrange = Color(0xFFF39C12);
const Color _cameraBrown = Color(0xFF8B5A2B);

class SelfieCaptureResult {
  const SelfieCaptureResult({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

class SelfieCameraPage extends StatefulWidget {
  const SelfieCameraPage({super.key});

  @override
  State<SelfieCameraPage> createState() => _SelfieCameraPageState();
}

class _SelfieCameraPageState extends State<SelfieCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  CameraDescription? _frontCamera;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeFrontCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && _frontCamera != null) {
      _initializeController(_frontCamera!);
    }
  }

  Future<void> _initializeFrontCamera() async {
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });
    }

    try {
      final List<CameraDescription> cameras = await availableCameras();
      CameraDescription? front;
      for (final CameraDescription camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          front = camera;
          break;
        }
      }

      if (front == null) {
        throw StateError('Kamera depan tidak ditemukan pada perangkat ini.');
      }

      _frontCamera = front;
      await _initializeController(front);
    } on CameraException catch (error) {
      _showInitializationError(_cameraErrorMessage(error));
    } catch (error) {
      _showInitializationError(error.toString());
    }
  }

  Future<void> _initializeController(CameraDescription camera) async {
    final CameraController? previous = _controller;
    _controller = null;
    await previous?.dispose();

    final CameraController controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted || _controller != controller) {
        await controller.dispose();
        return;
      }
      setState(() {
        _isInitializing = false;
        _errorMessage = null;
      });
    } on CameraException catch (error) {
      await controller.dispose();
      if (_controller == controller) _controller = null;
      _showInitializationError(_cameraErrorMessage(error));
    }
  }

  void _showInitializationError(String message) {
    if (!mounted) return;
    setState(() {
      _isInitializing = false;
      _errorMessage = message;
    });
  }

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
        return 'Izin kamera ditolak. Izinkan akses kamera untuk mengambil selfie verifikasi.';
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Akses kamera dinonaktifkan. Aktifkan izin kamera Ayo Suruh dari pengaturan perangkat.';
      case 'CameraAccessRestricted':
        return 'Akses kamera dibatasi pada perangkat ini.';
      default:
        return error.description ?? 'Kamera depan belum dapat dibuka.';
    }
  }

  Future<void> _capture() async {
    final CameraController? controller = _controller;
    if (_isCapturing ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final XFile file = await controller.takePicture();
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;

      Navigator.of(context).pop<SelfieCaptureResult>(
        SelfieCaptureResult(bytes: bytes, name: file.name),
      );
    } on CameraException catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, _cameraErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Selfie Verifikasi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: _isInitializing
                  ? const Center(
                      child: CircularProgressIndicator(color: _cameraOrange),
                    )
                  : _errorMessage != null
                      ? _buildErrorState()
                      : controller == null || !controller.value.isInitialized
                          ? _buildErrorState()
                          : _buildPreview(controller),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              color: const Color(0xFF111111),
              child: Column(
                children: <Widget>[
                  const Text(
                    'Pastikan wajah terlihat jelas, pencahayaan cukup, dan seluruh wajah berada di dalam bingkai.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: ElevatedButton(
                      onPressed: _errorMessage == null && !_isInitializing
                          ? _capture
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _cameraBrown,
                        disabledBackgroundColor: Colors.white24,
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      child: _isCapturing
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: _cameraOrange,
                              ),
                            )
                          : const Icon(Icons.camera_alt_rounded, size: 34),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(CameraController controller) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double previewAspectRatio = controller.value.aspectRatio;
        final double screenAspectRatio = constraints.maxWidth / constraints.maxHeight;

        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            maxWidth: screenAspectRatio > previewAspectRatio
                ? constraints.maxWidth
                : constraints.maxHeight * previewAspectRatio,
            maxHeight: screenAspectRatio > previewAspectRatio
                ? constraints.maxWidth / previewAspectRatio
                : constraints.maxHeight,
            child: CameraPreview(controller),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white70,
              size: 54,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Kamera depan belum siap.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _initializeFrontCamera,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: FilledButton.styleFrom(backgroundColor: _cameraOrange),
            ),
          ],
        ),
      ),
    );
  }
}
