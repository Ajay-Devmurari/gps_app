import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'full_screen_image.dart';

class MediaGrid extends StatelessWidget {
  final List<AssetEntity> images;
  final Set<AssetEntity> selected;
  final Function(AssetEntity) onToggle;
  final Function(List<AssetEntity>) onToggleDate;
  final bool isGridView;
  final VoidCallback onDeleteDone;

  const MediaGrid({
    super.key,
    required this.images,
    required this.selected,
    required this.onToggle,
    required this.onToggleDate,
    required this.isGridView,
    required this.onDeleteDone,
  });

  bool get isSelecting => selected.isNotEmpty;

  String _formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);

  Map<String, List<AssetEntity>> _groupByDate() {
    final map = <String, List<AssetEntity>>{};
    for (final asset in images) {
      final key = _formatDate(asset.createDateTime);
      map.putIfAbsent(key, () => []);
      map[key]!.add(asset);
    }
    return map;
  }

  Future<void> _shareSelected(BuildContext context) async {
    final files = <XFile>[];
    for (final asset in selected) {
      final file = await asset.file;
      if (file != null) files.add(XFile(file.path));
    }
    if (files.isNotEmpty) {
      await Share.shareXFiles(files);
    }
  }

  Future<void> _deleteSelected(BuildContext context) async {
    final ids = selected.map((e) => e.id).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete photos?'),
        content: Text('Are you sure you want to delete ${ids.length} photo(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (ok == true) {
      await PhotoManager.editor.deleteWithIds(ids);
      onDeleteDone(); // UI refresh
    }
  }

  // ✅ Full Screen open karne aur wapas aane par refresh karne ka logic
  Future<void> _handleNavigation(BuildContext context, AssetEntity asset) async {
    final index = images.indexOf(asset);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenGallery(
          images: images,
          initialIndex: index,
        ),
      ),
    );
    // Jab user wapas aaye, gallery ko refresh karein
    onDeleteDone();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDate();
    final dates = grouped.keys.toList();

    return Stack(
      children: [
        /// ================= GRID MODE =================
        if (isGridView)
          ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final assets = grouped[date]!;
              final allSelected = assets.every((a) => selected.contains(a));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Row(
                      children: [
                        Text(date, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        if (isSelecting)
                          Checkbox(
                            value: allSelected,
                            onChanged: (_) => onToggleDate(assets),
                          ),
                      ],
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: assets.length,
                    itemBuilder: (context, i) {
                      final asset = assets[i];
                      final isSel = selected.contains(asset);
                      return GestureDetector(
                        onLongPress: () => onToggle(asset),
                        onTap: () => isSelecting
                            ? onToggle(asset)
                            : _handleNavigation(context, asset), // ✅ Updated
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AssetEntityImage(asset, thumbnailSize: const ThumbnailSize.square(250), fit: BoxFit.cover),
                            if (isSel)
                              Container(
                                color: Colors.black45,
                                child: const Icon(Icons.check_circle, color: Colors.blue, size: 30),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          )
        else
        /// ================= LIST MODE =================
          ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final asset = images[index];
              final isSel = selected.contains(asset);
              return ListTile(
                leading: AssetEntityImage(asset, thumbnailSize: const ThumbnailSize.square(100), fit: BoxFit.cover, width: 50, height: 50),
                title: Text(_formatDate(asset.createDateTime)),
                trailing: isSelecting
                    ? Checkbox(value: isSel, onChanged: (_) => onToggle(asset))
                    : (isSel ? const Icon(Icons.check_circle, color: Colors.blue) : null),
                onLongPress: () => onToggle(asset),
                onTap: () => isSelecting
                    ? onToggle(asset)
                    : _handleNavigation(context, asset), // ✅ Updated
              );
            },
          ),

        /// ================= GLASS ACTION BAR =================
        if (isSelecting)
          Positioned(
            bottom: 30,
            left: 30,
            right: 30,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.share, color: Colors.white),
                          onPressed: () => _shareSelected(context)
                      ),
                      Text(
                          '${selected.length} selected',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(blurRadius: 10, color: Colors.black45)]
                          )
                      ),
                      IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _deleteSelected(context)
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}