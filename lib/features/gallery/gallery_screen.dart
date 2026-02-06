import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../presentation/widgets/media_grid.dart';
import 'people_group_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, required this.onOpenCamera});

  final VoidCallback onOpenCamera;

  @override
  GalleryScreenState createState() => GalleryScreenState();
}

class GalleryScreenState extends State<GalleryScreen> {
  List<AssetEntity> images = [];
  Set<AssetEntity> selected = {};
  bool isGridView = true;

  @override
  void initState() {
    super.initState();
    fetchAssets();
  }

  Future<void> fetchAssets() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) {
      PhotoManager.openSetting();
      return;
    }
    await PhotoManager.clearFileCache();
    final albums = await PhotoManager.getAssetPathList(
        onlyAll: true, type: RequestType.image);
    if (albums.isEmpty) return;

    final assets = await albums.first.getAssetListPaged(page: 0, size: 1000);
    if (mounted) {
      setState(() => images = assets);
    }
  }

  void toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        selected.clear();
        selected.addAll(images);
      } else {
        selected.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isSelecting = selected.isNotEmpty;
    bool isAllSelected = selected.length == images.length && images.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(selected.isEmpty ? 'Gallery' : '${selected.length} Selected'),
        leading: isSelecting
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => selected.clear()))
            : null,
        actions: [
          if (isSelecting)
            Checkbox(value: isAllSelected, onChanged: toggleSelectAll),
          IconButton(
            icon: Icon(isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => isGridView = !isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PeopleGroupScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: widget.onOpenCamera,
          ),
        ],
      ),
      body: images.isEmpty
          ? const Center(child: Text("No Images Found"))
          : MediaGrid(
              images: images,
              selected: selected,
              isGridView: isGridView,
              onToggle: (asset) => setState(() => selected.contains(asset)
                  ? selected.remove(asset)
                  : selected.add(asset)),
              onToggleDate: (assets) {
                setState(() {
                  assets.every((a) => selected.contains(a))
                      ? selected.removeAll(assets)
                      : selected.addAll(assets);
                });
              },
              onDeleteDone: fetchAssets,
            ),
    );
  }
}
