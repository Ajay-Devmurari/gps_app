import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:photo_manager/photo_manager.dart';

class FaceTestScreen extends StatefulWidget {
  const FaceTestScreen({super.key});

  @override
  State<FaceTestScreen> createState() => _FaceTestScreenState();
}

class _FaceTestScreenState extends State<FaceTestScreen> {
  String result = 'Waiting...';

  @override
  void initState() {
    super.initState();
    Future.microtask(pickAndTest);
  }

  Future<void> pickAndTest() async {
    final ps = await PhotoManager.requestPermissionExtend();

    if (!(ps.isAuth || ps.hasAccess)) {
      setState(() => result = 'Permission denied');
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
    );

    if (albums.isEmpty) {
      setState(() => result = 'No albums');
      return;
    }

    final assets = await albums.first.getAssetListPaged(
      page: 0,
      size: 5,
    );

    if (assets.isEmpty) {
      setState(() => result = 'No images');
      return;
    }

    final file = await assets.first.file;
    if (file == null) {
      setState(() => result = 'File null');
      return;
    }

    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.01,
      ),
    );

    final faces =
    await detector.processImage(InputImage.fromFile(file));

    await detector.close();

    setState(() {
      result = 'Faces found: ${faces.length}';
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Test')),
      body: Center(
        child: Text(
          result,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
