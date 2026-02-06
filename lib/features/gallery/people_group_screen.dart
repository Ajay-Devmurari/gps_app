// import 'dart:io';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:photo_manager/photo_manager.dart';
// import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// import 'package:image/image.dart' as img;
// import 'package:path_provider/path_provider.dart';
//
// class PeopleGroupScreen extends StatefulWidget {
//   const PeopleGroupScreen({super.key});
//
//   @override
//   State<PeopleGroupScreen> createState() => _PeopleGroupScreenState();
// }
//
// class _PeopleGroupScreenState extends State<PeopleGroupScreen> {
//   late FaceDetector faceDetector;
//   bool loading = true;
//   final Map<int, List<File>> groupedFaces = {};
//   final List<List<int>> _faceHashes = [];
//   late Directory faceDir;
//
//   @override
//   void initState() {
//     super.initState();
//     _init();
//   }
//
//   Future<void> _init() async {
//     faceDetector = FaceDetector(
//       options: FaceDetectorOptions(
//         performanceMode: FaceDetectorMode.fast, // Fast mode memory kam leta hai
//         minFaceSize: 0.15,
//       ),
//     );
//
//     final appDir = await getApplicationDocumentsDirectory();
//     faceDir = Directory('${appDir.path}/faces');
//     if (!faceDir.existsSync()) faceDir.createSync(recursive: true);
//
//     await _scanGallery();
//   }
//
//   Future<void> _scanGallery() async {
//     final ps = await PhotoManager.requestPermissionExtend();
//     if (!ps.isAuth && !ps.hasAccess) {
//       setState(() => loading = false);
//       return;
//     }
//
//     final albums = await PhotoManager.getAssetPathList(onlyAll: true, type: RequestType.image);
//     if (albums.isEmpty) {
//       setState(() => loading = false);
//       return;
//     }
//
//     // Ek baar mein sirf 30 images process karein crash se bachne ke liye
//     final assets = await albums.first.getAssetListPaged(page: 0, size: 30);
//
//     for (final asset in assets) {
//       final file = await asset.file;
//       if (file == null) continue;
//
//       try {
//         final inputImage = InputImage.fromFile(file);
//         final faces = await faceDetector.processImage(inputImage);
//
//         for (final face in faces) {
//           await _processAndGroupFace(file, face.boundingBox);
//         }
//       } catch (e) {
//         debugPrint("Scan Error: $e");
//       }
//
//       // Har photo ke baad thoda gap dein taaki OS memory release kar sake
//       await Future.delayed(const Duration(milliseconds: 100));
//     }
//
//     if (mounted) setState(() => loading = false);
//   }
//
//   Future<void> _processAndGroupFace(File file, Rect box) async {
//     try {
//       // 1. Decode Image (Sirf ek baar)
//       final bytes = file.readAsBytesSync();
//       img.Image? fullImage = img.decodeImage(bytes);
//       if (fullImage == null) return;
//
//       // 2. Face Crop
//       int x = max(0, box.left.toInt());
//       int y = max(0, box.top.toInt());
//       int w = min(fullImage.width - x, box.width.toInt());
//       int h = min(fullImage.height - y, box.height.toInt());
//
//       if (w < 40 || h < 40) return;
//
//       img.Image faceCrop = img.copyCrop(fullImage, x: x, y: y, width: w, height: h);
//
//       // Memory bachane ke liye original image ko null kar dein
//       fullImage = null;
//
//       // 3. Create Hash (Grayscale sirf hash ke liye, original color rahega)
//       final hashImage = img.copyResize(faceCrop, width: 32, height: 32);
//       final currentHash = _imageHash(hashImage);
//
//       int personId = -1;
//       double minDistance = double.infinity;
//
//       for (int i = 0; i < _faceHashes.length; i++) {
//         double dist = _calculateDistance(currentHash, _faceHashes[i]);
//         // Threshold Tight: 10.0 se kam matlab same person
//         if (dist < 10.0) {
//           if (dist < minDistance) {
//             minDistance = dist;
//             personId = i;
//           }
//         }
//       }
//
//       // 4. Save Color Image
//       final previewImage = img.copyResize(faceCrop, width: 120, height: 120);
//       final path = '${faceDir.path}/f_${DateTime.now().microsecondsSinceEpoch}.jpg';
//       final outFile = File(path)..writeAsBytesSync(img.encodeJpg(previewImage, quality: 85));
//
//       if (mounted) {
//         setState(() {
//           if (personId != -1) {
//             groupedFaces[personId]!.add(outFile);
//           } else {
//             int newId = _faceHashes.length;
//             _faceHashes.add(currentHash);
//             groupedFaces[newId] = [outFile];
//           }
//         });
//       }
//     } catch (e) {
//       debugPrint("Crop Error: $e");
//     }
//   }
//
//   List<int> _imageHash(img.Image image) {
//     // Hash ke liye temp grayscale
//     final tempGray = img.grayscale(img.Image.from(image));
//     final List<int> pixels = [];
//     for (int y = 0; y < tempGray.height; y += 4) {
//       for (int x = 0; x < tempGray.width; x += 4) {
//         pixels.add(tempGray.getPixel(x, y).r.toInt());
//       }
//     }
//     return pixels;
//   }
//
//   double _calculateDistance(List<int> a, List<int> b) {
//     double sum = 0;
//     int length = min(a.length, b.length);
//     for (int i = 0; i < length; i++) {
//       int diff = a[i] - b[i];
//       sum += diff * diff;
//     }
//     return sqrt(sum) / length;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final personKeys = groupedFaces.keys.toList();
//
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(title: Text('People Grouping (${personKeys.length})'), backgroundColor: Colors.blueGrey[900]),
//       body: loading && personKeys.isEmpty
//           ? const Center(child: CircularProgressIndicator())
//           : GridView.builder(
//         padding: const EdgeInsets.all(10),
//         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.8
//         ),
//         itemCount: personKeys.length,
//         itemBuilder: (context, index) {
//           int id = personKeys[index];
//           return Column(
//             children: [
//               Expanded(
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(10),
//                   child: Image.file(groupedFaces[id]![0], fit: BoxFit.cover, width: double.infinity),
//                 ),
//               ),
//               Text("Person ${id + 1} (${groupedFaces[id]!.length})",
//                   style: const TextStyle(color: Colors.white, fontSize: 11)),
//             ],
//           );
//         },
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     faceDetector.close();
//     super.dispose();
//   }
// }
//
//
//
//

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gps_app/features/gallery/person_detail_screen.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class PeopleGroupScreen extends StatefulWidget {
  const PeopleGroupScreen({super.key});

  @override
  State<PeopleGroupScreen> createState() => _PeopleGroupScreenState();
}

class _PeopleGroupScreenState extends State<PeopleGroupScreen> {
  late FaceDetector faceDetector;
  bool loading = true;

  final Map<int, List<File>> groupedFaces = {};
  final List<List<int>> _faceHashes = [];
  late Directory faceDir;
  late Directory tempDir;
  late File processedIdsFile;
  late File groupsFile;
  late File hashesFile;
  final Set<String> _processedIds = {};
  bool _processedDirty = false;
  bool _groupsDirty = false;
  bool _hashesDirty = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );

    final appDir = await getApplicationDocumentsDirectory();
    faceDir = Directory('${appDir.path}/faces');
    if (!faceDir.existsSync()) {
      faceDir.createSync(recursive: true);
    }
    tempDir = Directory('${appDir.path}/faces_tmp');
    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }
    processedIdsFile = File('${appDir.path}/faces/processed_ids.json');
    groupsFile = File('${appDir.path}/faces/groups.json');
    hashesFile = File('${appDir.path}/faces/hashes.json');
    await _loadProcessedIds();
    await _loadGroups();
    await _loadHashes();
    if (mounted) {
      setState(() {});
    }

    // If we have no saved groups, reprocess everything.
    if (groupedFaces.isEmpty) {
      _processedIds.clear();
      _processedDirty = true;
    }

    await _scanGallery();

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _loadProcessedIds() async {
    if (!await processedIdsFile.exists()) return;
    try {
      final content = await processedIdsFile.readAsString();
      final List<dynamic> ids = jsonDecode(content);
      _processedIds
        ..clear()
        ..addAll(ids.whereType<String>());
    } catch (_) {
      // If corrupt, ignore and rebuild on next scan.
    }
  }

  Future<void> _saveProcessedIds() async {
    if (!_processedDirty) return;
    _processedDirty = false;
    try {
      final content = jsonEncode(_processedIds.toList(growable: false));
      await processedIdsFile.writeAsString(content, flush: true);
    } catch (_) {
      // Best-effort cache; ignore write errors.
    }
  }

  Future<void> _loadGroups() async {
    if (!await groupsFile.exists()) return;
    try {
      final content = await groupsFile.readAsString();
      final Map<String, dynamic> raw = jsonDecode(content);
      final Map<int, List<File>> loaded = {};
      raw.forEach((key, value) {
        if (value is List) {
          final files = value
              .whereType<String>()
              .map((p) => File(p))
              .where((f) => f.existsSync())
              .toList(growable: false);
          if (files.isNotEmpty) {
            loaded[int.parse(key)] = files;
          }
        }
      });
      if (loaded.isNotEmpty) {
        groupedFaces
          ..clear()
          ..addAll(loaded);
      }
    } catch (_) {
      // If corrupt, ignore and rebuild on next scan.
    }
  }

  Future<void> _saveGroups() async {
    if (!_groupsDirty) return;
    _groupsDirty = false;
    try {
      final Map<String, List<String>> data = {};
      groupedFaces.forEach((key, files) {
        data[key.toString()] =
            files.map((f) => f.path).toList(growable: false);
      });
      final content = jsonEncode(data);
      await groupsFile.writeAsString(content, flush: true);
    } catch (_) {
      // Best-effort cache; ignore write errors.
    }
  }

  Future<void> _loadHashes() async {
    if (!await hashesFile.exists()) return;
    try {
      final content = await hashesFile.readAsString();
      final List<dynamic> raw = jsonDecode(content);
      _faceHashes
        ..clear()
        ..addAll(
          raw.whereType<List>().map(
                (row) => row.whereType<int>().toList(growable: false),
              ),
        );
    } catch (_) {
      // If corrupt, ignore and rebuild on next scan.
    }
  }

  Future<void> _saveHashes() async {
    if (!_hashesDirty) return;
    _hashesDirty = false;
    try {
      final content = jsonEncode(_faceHashes);
      await hashesFile.writeAsString(content, flush: true);
    } catch (_) {
      // Best-effort cache; ignore write errors.
    }
  }

  // ✅ FIXED: PAGINATION (NO CRASH, ALL IMAGES)
  Future<void> _scanGallery() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) return;

    final albums = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
    );
    if (albums.isEmpty) return;

    int page = 0;
    const int size = 50;

    while (true) {
      final assets = await albums.first.getAssetListPaged(
        page: page,
        size: size,
      );

      if (assets.isEmpty) break;

      for (final asset in assets) {
        if (_processedIds.contains(asset.id)) {
          continue;
        }

        final thumbBytes = await asset.thumbnailDataWithSize(
          const ThumbnailSize(1024, 1024),
          quality: 85,
        );
        if (thumbBytes == null) continue;

        final tempFile = File(
          '${tempDir.path}/t_${DateTime.now().microsecondsSinceEpoch}.jpg',
        );
        await tempFile.writeAsBytes(thumbBytes, flush: true);

        try {
          final inputImage = InputImage.fromFile(tempFile);
          final faces = await faceDetector.processImage(inputImage);

          for (final face in faces) {
            await _processAndGroupFace(tempFile, face.boundingBox);
          }
        } catch (_) {
        } finally {
          _processedIds.add(asset.id);
          _processedDirty = true;
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }

        // memory safe delay
        await Future.delayed(const Duration(milliseconds: 60));
      }

      await _saveProcessedIds();
      page++;
    }

    await _saveProcessedIds();
    await _saveGroups();
    await _saveHashes();
  }

  Future<void> _processAndGroupFace(File file, Rect box) async {
    try {
      final bytes = await file.readAsBytes();
      img.Image? fullImage = img.decodeImage(bytes);
      if (fullImage == null) return;

      int x = max(0, box.left.toInt());
      int y = max(0, box.top.toInt());
      int w = min(fullImage.width - x, box.width.toInt());
      int h = min(fullImage.height - y, box.height.toInt());

      if (w < 40 || h < 40) return;

      img.Image faceCrop =
          img.copyCrop(fullImage, x: x, y: y, width: w, height: h);
      fullImage = null;

      // Resize to a standard size for consistent hashing
      final hashImage = img.copyResize(faceCrop, width: 64, height: 64);
      final currentHash = _imageHash(hashImage);

      int personId = -1;
      double minDistance = double.infinity;

      for (int i = 0; i < _faceHashes.length; i++) {
        double dist = _calculateDistance(currentHash, _faceHashes[i]);

        // Strict threshold (lower is more strict)
        if (dist < 7.5 && dist < minDistance) {
          minDistance = dist;
          personId = i;
        }
      }

      // Save a high-quality thumbnail for preview
      final previewImage = img.copyResize(faceCrop, width: 200, height: 200);
      final path =
          '${faceDir.path}/f_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final outFile = File(path)
        ..writeAsBytesSync(img.encodeJpg(previewImage, quality: 90));

      if (!mounted) return;

      setState(() {
        if (personId != -1) {
          // Add only if it's the same person
          groupedFaces[personId]!.add(outFile);
          _groupsDirty = true;
        } else {
          // New person detected
          final newId = _faceHashes.length;
          _faceHashes.add(currentHash);
          _hashesDirty = true;
          groupedFaces[newId] = [outFile];
          _groupsDirty = true;
        }
      });
    } catch (e) {
      debugPrint("Grouping Error: $e");
    }
  }

  // ✅ IMPROVED HASHING: Uses Luminance for better matching
  List<int> _imageHash(img.Image image) {
    final gray = img.grayscale(img.Image.from(image));
    final List<int> pixels = [];

    // Grid sampling (8x8 grid for 64 points)
    for (int y = 0; y < gray.height; y += 8) {
      for (int x = 0; x < gray.width; x += 8) {
        pixels.add(gray.getPixel(x, y).luminance.toInt());
      }
    }
    return pixels;
  }

  double _calculateDistance(List<int> a, List<int> b) {
    double sum = 0;
    int length = min(a.length, b.length);
    for (int i = 0; i < length; i++) {
      int diff = a[i] - b[i];
      sum += diff * diff;
    }
    return sqrt(sum) / length;
  }

  @override
  Widget build(BuildContext context) {
    final personKeys = groupedFaces.keys.toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        title: Text('People Grouping (${personKeys.length})'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // ✅ IMPORTANT: RETURN DATA
            Navigator.pop(context, groupedFaces);
          },
        ),
      ),
      body: loading && personKeys.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: personKeys.length,
              itemBuilder: (context, index) {
                final id = personKeys[index];
                final personImages =
                    groupedFaces[id]!; // Is person ki saari images
                if (personImages.isEmpty) return const SizedBox();

                return GestureDetector(
                  onTap: () {
                    // ✅ Click karne par detail screen par bhejein
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PersonDetailScreen(
                          personId: id + 1,
                          images: personImages,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                personImages.first, // Representative Photo
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                            // Optional: Ek chota badge dikhane ke liye kitni photos hain
                            Positioned(
                              right: 5,
                              bottom: 5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${personImages.length}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Person ${id + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _saveProcessedIds();
    _saveGroups();
    _saveHashes();
    faceDetector.close();
    super.dispose();
  }
}



