
import 'package:gps_app/features/camera/camera_screen.dart';
import 'package:flutter/material.dart';
import '../../features/gallery/gallery_screen.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0; // Start on Gallery
  final GlobalKey<GalleryScreenState> _galleryKey = GlobalKey();

  void _switchTab(int i) {
    setState(() => index = i);
    if (i == 0) {
      // Refresh gallery when entering
      _galleryKey.currentState?.fetchAssets();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          GalleryScreen(
            key: _galleryKey,
            onOpenCamera: () => _switchTab(1), // ✅ opens camera
          ),
          CustomCameraScreen(
            onPhotoTaken: () => _galleryKey.currentState?.fetchAssets(),
            onGoToGallery: () => _switchTab(0),
          ),
        ],
      ),
    );
  }
}
