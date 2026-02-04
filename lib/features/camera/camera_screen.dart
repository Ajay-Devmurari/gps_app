import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';

class CustomCameraScreen extends StatefulWidget {
  const CustomCameraScreen({
    super.key,
    required this.onPhotoTaken,
    required this.onGoToGallery,
  });

  final VoidCallback onPhotoTaken;
  final VoidCallback onGoToGallery;

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> cameras = [];
  CameraController? controller;
  bool _isCameraInitialized = false;
  bool _isRearCamera = true;
  FlashMode _currentFlashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint("No cameras available");
        return;
      }
      // Select rear camera by default if available
      final initialCamera = cameras
              .any((c) => c.lensDirection == CameraLensDirection.back)
          ? cameras
              .firstWhere((c) => c.lensDirection == CameraLensDirection.back)
          : cameras.first;
      _onNewCameraSelected(initialCamera);
    } catch (e) {
      debugPrint("Camera Init Error: $e");
    }
  }

  void _onNewCameraSelected(CameraDescription cameraDescription) async {
    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.max,
      enableAudio: false,
    );

    if (controller != null) {
      await controller!.dispose();
    }

    try {
      await cameraController.initialize();
      await cameraController.setFlashMode(_currentFlashMode);
    } catch (e) {
      debugPrint('Controller Init Error: $e');
    }

    if (mounted) {
      setState(() {
        controller = cameraController;
        _isCameraInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (controller == null || !controller!.value.isInitialized) return;
    try {
      final XFile photo = await controller!.takePicture();
      await Gal.putImage(photo.path);
      widget.onPhotoTaken();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Saved to Gallery'),
              duration: Duration(milliseconds: 700)),
        );
      }
    } catch (e) {
      debugPrint("Capture error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || controller == null) {
      return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: CameraPreview(controller!),
          ),
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _circleIconButton(_getFlashIcon(), () {
                    setState(() {
                      if (_currentFlashMode == FlashMode.off) {
                        _currentFlashMode = FlashMode.auto;
                      } else if (_currentFlashMode == FlashMode.auto)
                        _currentFlashMode = FlashMode.always;
                      else
                        _currentFlashMode = FlashMode.off;
                      controller!.setFlashMode(_currentFlashMode);
                    });
                  }),
                  const Text("PHOTO",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2)),
                  // ✅ Close button: Yeh specifically Gallery par wapas le jayega
                  _circleIconButton(Icons.close, widget.onGoToGallery),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _circleIconButton(Icons.photo_library, widget.onGoToGallery,
                    size: 55),
                GestureDetector(
                  onTap: _takePhoto,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4)),
                    child: const CircleAvatar(
                        radius: 32, backgroundColor: Colors.white),
                  ),
                ),
                _circleIconButton(Icons.flip_camera_android, () {
                  _isRearCamera = !_isRearCamera;
                  final newCamera = _isRearCamera
                      ? cameras.firstWhere(
                          (c) => c.lensDirection == CameraLensDirection.back)
                      : cameras.firstWhere(
                          (c) => c.lensDirection == CameraLensDirection.front);
                  _onNewCameraSelected(newCamera);
                }, size: 55),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleIconButton(IconData icon, VoidCallback onTap,
      {double size = 45}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
            color: Colors.black26,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24)),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }

  IconData _getFlashIcon() {
    if (_currentFlashMode == FlashMode.off) return Icons.flash_off;
    if (_currentFlashMode == FlashMode.auto) return Icons.flash_auto;
    return Icons.flash_on;
  }
}
