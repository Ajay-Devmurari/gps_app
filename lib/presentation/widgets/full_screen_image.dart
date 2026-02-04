import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';

class FullScreenGallery extends StatefulWidget {
  final List<AssetEntity> images;
  final int initialIndex;

  const FullScreenGallery({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> with TickerProviderStateMixin{
  late PageController _pageController;
  late int _currentIndex;
  bool _showUI = true;
  late TransformationController _controller;
  TapDownDetails? _doubleTapDetails;
  bool _isZoomed = false;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _controller = TransformationController();
    _controller = TransformationController();

    // 🔥 Ye listener detect karega ki pinch se zoom level kya hai
    _controller.addListener(() {
      double currentScale = _controller.value.getMaxScaleOnAxis();
      if (currentScale <= 1.0 && _isZoomed) {
        setState(() => _isZoomed = false);
      } else if (currentScale > 1.0 && !_isZoomed) {
        setState(() => _isZoomed = true);
      }
    });

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220), // 👈 smooth feel
    );

    _animationController.addListener(() {
      _controller.value = _animation!.value;
    });

  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final Matrix4 begin = _controller.value;
    late Matrix4 end;

    if (_isZoomed) {
      end = Matrix4.identity();
    } else {
      final position = _doubleTapDetails!.localPosition;
      end = Matrix4.identity()
        ..translate(-position.dx * 2, -position.dy * 2)
        ..scale(3.0);
    }

    _animation = Matrix4Tween(
      begin: begin,
      end: end,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic, // 🔥 premium feel
      ),
    );

    _animationController.forward(from: 0);
    _isZoomed = !_isZoomed;
  }


  void _toggleUI() => setState(() => _showUI = !_showUI);

  Future<void> _share() async {
    final file = await widget.images[_currentIndex].file;
    if (file != null) {
      await Share.shareXFiles([XFile(file.path)], text: 'Check out this photo');
    }
  }

// FullScreenGallery ke andar _deleteImage function ko aise update karein:
  Future<void> _deleteImage() async {
    final asset = widget.images[_currentIndex];

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Photo?"),
        content: const Text("Are you sure you want to delete this photo?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final List<String> result = await PhotoManager.editor.deleteWithIds([asset.id]);

      if (result.isNotEmpty) {
        // ✅ SUCCESS: Seedha piche Gallery par chale jayein
        // isse index range ka error kabhi nahi aayega
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Deleted successfully"))
          );
        }
      }
    }
  }

  void _showDetails() {
    final asset = widget.images[_currentIndex];
    final dt = asset.createDateTime;
    final size = asset.size;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _infoItem(
              Icons.calendar_today,
              'Date',
              DateFormat('MMM d, y').format(dt),
            ),
            _infoItem(
              Icons.access_time,
              'Time',
              DateFormat('hh:mm a').format(dt),
            ),
            _infoItem(
              Icons.photo_size_select_large,
              'Dimensions',
              '${size.width.toInt()} × ${size.height.toInt()} px',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 22),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox();

    final asset = widget.images[_currentIndex];
    final dateText = DateFormat('MMM d, y').format(asset.createDateTime);
    final timeText = DateFormat('hh:mm a').format(asset.createDateTime);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image PageView
          PageView.builder(
            controller: _pageController,
            // 🔥 Agar zoomed hai toh swipe band kar dein taaki user zoom mein pan kar sake
            physics: _isZoomed ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _controller.value = Matrix4.identity();
                _isZoomed = false;
              });
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: _toggleUI,
                onDoubleTapDown: _handleDoubleTapDown,
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  transformationController: _controller,
                  minScale: 1.0,
                  maxScale: 5.0, // Thoda extra zoom limit
                  panEnabled: _isZoomed, // Sirf zoom hone par move karne dein
                  scaleEnabled: true,    // 🔥 Pinch zoom ON
                  child: Center(
                    child: AssetEntityImage(
                      widget.images[index],
                      isOriginal: true,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),


          // Top Bar
          if (_showUI)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                  bottom: 10,
                  left: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          timeText,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Bar
          if (_showUI)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _bottomAction(Icons.share_outlined, "Share", _share),
                    _bottomAction(Icons.delete_outline, "Delete", _deleteImage),
                    _bottomAction(Icons.info_outline, "Info", _showDetails),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
