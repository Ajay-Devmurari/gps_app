import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gps_app/features/gallery/person_detail_screen.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class PeopleGroupScreen extends StatefulWidget {
  const PeopleGroupScreen({super.key});

  @override
  State<PeopleGroupScreen> createState() => _PeopleGroupScreenState();
}

class _PeopleGroupScreenState extends State<PeopleGroupScreen> {
  late FaceDetector _faceDetector;
  Interpreter? _interpreter;

  bool loading = true;

  final Map<int, List<File>> groupedFaces = {};
  final List<List<double>> _faceEmbeddings = [];

  final Set<String> _processedIds = {};

  late Directory faceDir;
  late Directory tempDir;

  late File processedIdsFile;
  late File groupsFile;
  late File embeddingsFile;

  bool _processedDirty = false;
  bool _groupsDirty = false;
  bool _embeddingsDirty = false;

  int _embeddingSize = 192;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.10,
      ),
    );

    _interpreter =
        await Interpreter.fromAsset('assets/model/mobilefacenet.tflite');
    _embeddingSize = _interpreter!.getOutputTensor(0).shape.last;

    final appDir = await getApplicationDocumentsDirectory();

    faceDir = Directory('${appDir.path}/faces');
    tempDir = Directory('${appDir.path}/faces_tmp');

    if (!faceDir.existsSync()) faceDir.createSync(recursive: true);
    if (!tempDir.existsSync()) tempDir.createSync(recursive: true);

    processedIdsFile = File('${faceDir.path}/processed_ids.json');
    groupsFile = File('${faceDir.path}/groups.json');
    embeddingsFile = File('${faceDir.path}/embeddings.json');

    await _loadProcessedIds();
    await _loadGroups();
    await _loadEmbeddings();

    if (_faceEmbeddings.isEmpty && groupedFaces.isNotEmpty) {
      groupedFaces.clear();
      _processedIds.clear();
    }

    await _scanGallery();

    if (mounted) {
      setState(() => loading = false);
    }
  }

  // -------------------- Persistence --------------------

  Future<void> _loadProcessedIds() async {
    if (!await processedIdsFile.exists()) return;
    try {
      final List<dynamic> raw =
          jsonDecode(await processedIdsFile.readAsString());
      _processedIds
        ..clear()
        ..addAll(raw.whereType<String>());
    } catch (_) {}
  }

  Future<void> _saveProcessedIds() async {
    if (!_processedDirty) return;
    _processedDirty = false;
    await processedIdsFile.writeAsString(
      jsonEncode(_processedIds.toList()),
      flush: true,
    );
  }

  Future<void> _loadGroups() async {
    if (!await groupsFile.exists()) return;
    try {
      final Map<String, dynamic> raw =
          jsonDecode(await groupsFile.readAsString());
      groupedFaces.clear();
      raw.forEach((k, v) {
        final files = (v as List)
            .map((p) => File(p))
            .where((f) => f.existsSync())
            .toList();
        if (files.isNotEmpty) {
          groupedFaces[int.parse(k)] = files;
        }
      });
    } catch (_) {}
  }

  Future<void> _saveGroups() async {
    if (!_groupsDirty) return;
    _groupsDirty = false;
    final data = <String, List<String>>{};
    groupedFaces.forEach((k, v) {
      data[k.toString()] = v.map((f) => f.path).toList();
    });
    await groupsFile.writeAsString(jsonEncode(data), flush: true);
  }

  Future<void> _loadEmbeddings() async {
    if (!await embeddingsFile.exists()) return;
    try {
      final List raw = jsonDecode(await embeddingsFile.readAsString());
      _faceEmbeddings
        ..clear()
        ..addAll(
          raw.map<List<double>>(
            (e) => (e as List).map((v) => (v as num).toDouble()).toList(),
          ),
        );
    } catch (_) {}
  }

  Future<void> _saveEmbeddings() async {
    if (!_embeddingsDirty) return;
    _embeddingsDirty = false;
    await embeddingsFile.writeAsString(
      jsonEncode(_faceEmbeddings),
      flush: true,
    );
  }

  // -------------------- Gallery Scan --------------------

  Future<void> _scanGallery() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) return;

    final albums = await PhotoManager.getAssetPathList(
        onlyAll: true, type: RequestType.image);
    if (albums.isEmpty) return;

    int page = 0;
    const size = 50;

    while (true) {
      final assets =
          await albums.first.getAssetListPaged(page: page, size: size);
      if (assets.isEmpty) break;

      for (final asset in assets) {
        if (_processedIds.contains(asset.id)) continue;

        final bytes = await asset.thumbnailDataWithSize(
          const ThumbnailSize(1280, 1280),
          quality: 85,
        );
        if (bytes == null) continue;

        final tempFile = File(
            '${tempDir.path}/${DateTime.now().microsecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(bytes);

        try {
          final faces =
              await _faceDetector.processImage(InputImage.fromFile(tempFile));
          for (final face in faces) {
            await _processAndGroupFace(tempFile, face.boundingBox);
          }
        } catch (_) {
        } finally {
          _processedIds.add(asset.id);
          _processedDirty = true;
          await tempFile.delete();
        }

        await Future.delayed(const Duration(milliseconds: 60));
      }

      await _saveProcessedIds();
      page++;
    }

    await _saveGroups();
    await _saveEmbeddings();
  }

  // -------------------- Face Processing --------------------

  Future<void> _processAndGroupFace(File file, Rect box) async {
    final image = img.decodeImage(await file.readAsBytes());
    if (image == null) return;

    final x = max(0, box.left.toInt());
    final y = max(0, box.top.toInt());
    final w = min(image.width - x, box.width.toInt());
    final h = min(image.height - y, box.height.toInt());
    if (w < 40 || h < 40) return;

    final face = img.copyCrop(image, x: x, y: y, width: w, height: h);

    final resized = img.copyResize(face, width: 112, height: 112);
    final embedding = _getEmbedding(resized);

    int match = -1;
    double best = double.infinity;

    for (int i = 0; i < _faceEmbeddings.length; i++) {
      final d = _cosineDistance(embedding, _faceEmbeddings[i]);
      if (d < 0.40 && d < best) {
        best = d;
        match = i;
      }
    }

    final preview = img.copyResize(face, width: 200, height: 200);
    final outFile = File(
      '${faceDir.path}/${DateTime.now().microsecondsSinceEpoch}.jpg',
    )..writeAsBytesSync(img.encodeJpg(preview, quality: 90));

    if (!mounted) return;

    setState(() {
      if (match != -1) {
        groupedFaces[match]!.add(outFile);
      } else {
        final id = _faceEmbeddings.length;
        _faceEmbeddings.add(embedding);
        groupedFaces[id] = [outFile];
        _embeddingsDirty = true;
      }
      _groupsDirty = true;
    });
  }

  List<double> _getEmbedding(img.Image image) {
    final input = _imageToFloat32(image);
    final output =
        List.filled(_embeddingSize, 0.0).reshape([1, _embeddingSize]);
    _interpreter!.run(input, output);
    return List<double>.from(output[0]);
  }

  List<List<List<List<double>>>> _imageToFloat32(img.Image image) {
    return [
      List.generate(
        image.height,
        (y) => List.generate(
          image.width,
          (x) {
            final p = image.getPixel(x, y);
            return [
              (p.r - 127.5) / 128.0,
              (p.g - 127.5) / 128.0,
              (p.b - 127.5) / 128.0,
            ];
          },
        ),
      ),
    ];
  }

  double _cosineDistance(List<double> a, List<double> b) {
    double dot = 0, na = 0, nb = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    return 1.0 - (dot / (sqrt(na) * sqrt(nb)));
  }

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    final keys = groupedFaces.keys.toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('People Grouping (${keys.length})'),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: loading && keys.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: keys.length,
              itemBuilder: (_, i) {
                final id = keys[i];
                final images = groupedFaces[id]!;
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PersonDetailScreen(
                        personId: id + 1,
                        images: images,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            images.first,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Person ${id + 1} (${images.length})',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
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
    _saveEmbeddings();
    _interpreter?.close();
    _faceDetector.close();
    super.dispose();
  }
}
