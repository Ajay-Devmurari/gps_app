// ignore_for_file: unused_import

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:image/image.dart' as img;

class OpenCVFaceDetector {
  bool isInitialized = false;

  Future<void> initialize() async {
    try {
      // Initialize OpenCV face detector
      // In a real implementation, you would load the Haar cascade classifier here
      isInitialized = true;
    } catch (e) {
      print('Error initializing OpenCV face detector: $e');
      throw Exception('Failed to initialize OpenCV face detector');
    }
  }

  Future<List<ui.Rect>> detectFaces(String imagePath) async {
    if (!isInitialized) {
      throw Exception('Face detector not initialized');
    }

    try {
      // Load image
      final imageFile = File(imagePath);
      if (!imageFile.existsSync()) {
        throw Exception('Image file not found: $imagePath');
      }

      // Read image bytes
      final bytes = await imageFile.readAsBytes();

      // Decode image
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Convert to grayscale for face detection
      final gray = img.grayscale(image);

      // Simple face detection using edge detection and blob detection
      // This is a simplified implementation - in production, you would use
      // actual OpenCV functions or a dedicated face detection package
      final faces = _detectFacesSimple(gray);

      return faces;
    } catch (e) {
      print('Error detecting faces with OpenCV: $e');
      return [];
    }
  }

  List<ui.Rect> _detectFacesSimple(img.Image grayImage) {
    // This is a simplified face detection algorithm
    // In production, you would use actual OpenCV functions or a dedicated package

    final faces = <ui.Rect>[];

    // Simple edge detection using convolution
    final edges = _applySobelEdgeDetection(grayImage);

    // Find potential face regions (simplified)
    // This would normally use more sophisticated algorithms
    final faceWidth = grayImage.width ~/ 6;
    final faceHeight = grayImage.height ~/ 6;

    // Sample some regions to find potential faces
    for (int y = faceHeight;
        y < grayImage.height - faceHeight;
        y += faceHeight) {
      for (int x = faceWidth; x < grayImage.width - faceWidth; x += faceWidth) {
        // Check if this region has enough edge content (simplified face detection)
        final hasFace = _checkForFace(grayImage, x, y, faceWidth, faceHeight);

        if (hasFace) {
          faces.add(ui.Rect.fromLTWH(
            x.toDouble(),
            y.toDouble(),
            faceWidth.toDouble(),
            faceHeight.toDouble(),
          ));
        }
      }
    }

    return faces;
  }

  img.Image _applySobelEdgeDetection(img.Image image) {
    // Apply Sobel edge detection
    final sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1]
    ];

    final sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1]
    ];

    final output = img.Image.from(image);

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        int gx = 0;
        int gy = 0;

        // Apply convolution kernels
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final gray = (pixel.r + pixel.g + pixel.b) ~/ 3;
            gx += gray * sobelX[ky + 1][kx + 1];
            gy += gray * sobelY[ky + 1][kx + 1];
          }
        }

        // Calculate magnitude
        final magnitude = (sqrt(gx * gx + gy * gy)).clamp(0, 255).toInt();
        output.setPixelRgba(x, y, magnitude, magnitude, magnitude, 255);
      }
    }

    return output;
  }

  bool _checkForFace(img.Image image, int x, int y, int width, int height) {
    // Simplified face detection check
    // In production, this would use more sophisticated algorithms

    // Sample pixels in the region
    int edgeCount = 0;
    int totalPixels = 0;

    for (int cy = y; cy < y + height && cy < image.height; cy++) {
      for (int cx = x; cx < x + width && cx < image.width; cx++) {
        final pixel = image.getPixel(cx, cy);
        // Check if pixel has significant edge content
        if (pixel.r > 100 || pixel.g > 100 || pixel.b > 100) {
          edgeCount++;
        }
        totalPixels++;
      }
    }

    // Simple threshold for face detection
    return edgeCount > totalPixels * 0.1;
  }

  Future<String?> cropFace(String imagePath, ui.Rect boundingBox) async {
    try {
      // Load image
      final imageFile = File(imagePath);
      final bytes = await imageFile.readAsBytes();

      // Decode image
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) return null;

      // Convert coordinates to integers
      final x = boundingBox.left.round();
      final y = boundingBox.top.round();
      final width = boundingBox.width.round();
      final height = boundingBox.height.round();

      // Add some padding
      final padding = 20;
      final cropX = (x - padding).clamp(0, originalImage.width - 1);
      final cropY = (y - padding).clamp(0, originalImage.height - 1);
      final cropWidth =
          (width + padding * 2).clamp(1, originalImage.width - cropX);
      final cropHeight =
          (height + padding * 2).clamp(1, originalImage.height - cropY);

      // Crop the face
      final cropped = img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      // Resize to standard size for face recognition
      final resized = img.copyResize(cropped, width: 112, height: 112);

      // Save cropped face
      final tempDir = await Directory.systemTemp.createTemp('faces');
      final facePath =
          '${tempDir.path}/face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      File(facePath).writeAsBytesSync(img.encodeJpg(resized));

      return facePath;
    } catch (e) {
      print('Error cropping face: $e');
      return null;
    }
  }

  void dispose() {
    // Clean up resources
    isInitialized = false;
  }
}
