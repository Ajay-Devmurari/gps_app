import 'dart:ui' as ui;

class FaceArranger {
  /// Arranges faces in a visually appealing grid layout
  ///
  /// [faces] - List of detected face bounding boxes
  /// [imageWidth] - Width of the original image
  /// [imageHeight] - Height of the original image
  ///
  /// Returns a list of arranged face positions optimized for display
  static List<ArrangedFace> arrangeFaces(
    List<ui.Rect> faces,
    double imageWidth,
    double imageHeight,
  ) {
    if (faces.isEmpty) return [];

    // Calculate face centers
    final faceCenters = faces
        .map((face) => ui.Offset(
              face.left + face.width / 2,
              face.top + face.height / 2,
            ))
        .toList();

    // Sort faces by vertical position first, then horizontal
    faceCenters.sort((a, b) {
      if (a.dy != b.dy) return a.dy.compareTo(b.dy);
      return a.dx.compareTo(b.dx);
    });

    // Group faces into rows based on vertical proximity
    final rows = _groupFacesIntoRows(faceCenters);

    // Arrange each row
    final arrangedFaces = <ArrangedFace>[];
    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];

      // Calculate horizontal spacing for this row
      final horizontalSpacing = _calculateHorizontalSpacing(row, imageWidth);

      // Arrange faces in this row
      for (int faceIndex = 0; faceIndex < row.length; faceIndex++) {
        final center = row[faceIndex];
        final originalFace = faces[faceCenters.indexOf(center)];

        // Calculate position in the arranged grid
        final x = faceIndex * horizontalSpacing;
        final y = rowIndex * (imageHeight / rows.length);

        // Calculate scaled size (maintain aspect ratio)
        final scaledWidth = originalFace.width * (imageWidth / faces.length);
        final scaledHeight = originalFace.height * (imageHeight / faces.length);

        arrangedFaces.add(ArrangedFace(
          originalRect: originalFace,
          arrangedPosition: ui.Offset(x, y),
          arrangedSize: ui.Size(scaledWidth, scaledHeight),
          personIndex: faceCenters.indexOf(center),
        ));
      }
    }

    return arrangedFaces;
  }

  /// Groups face centers into rows based on vertical proximity
  static List<List<ui.Offset>> _groupFacesIntoRows(List<ui.Offset> centers) {
    if (centers.isEmpty) return [];

    final rows = <List<ui.Offset>>[];
    var currentRow = <ui.Offset>[centers.first];
    var lastY = centers.first.dy;

    // Threshold for considering faces in the same row (10% of image height)
    final rowThreshold = 0.1;

    for (int i = 1; i < centers.length; i++) {
      final currentY = centers[i].dy;
      final distance = (currentY - lastY) / centers.first.dy;

      if (distance < rowThreshold) {
        // Face is in the same row
        currentRow.add(centers[i]);
        lastY = currentY;
      } else {
        // Face is in a new row
        rows.add(currentRow);
        currentRow = [centers[i]];
        lastY = currentY;
      }
    }

    // Add the last row
    if (currentRow.isNotEmpty) {
      rows.add(currentRow);
    }

    return rows;
  }

  /// Calculates horizontal spacing for faces in a row
  static double _calculateHorizontalSpacing(
    List<ui.Offset> row,
    double imageWidth,
  ) {
    if (row.isEmpty) return 0;

    // Use a fixed spacing that ensures faces don't overlap
    // Minimum spacing is 5% of image width
    final minSpacing = imageWidth * 0.05;
    final faceCount = row.length;

    // Calculate spacing based on number of faces
    if (faceCount == 1) {
      return imageWidth * 0.3; // Center single face
    } else {
      // Distribute faces evenly with minimum spacing
      final availableWidth = imageWidth - (minSpacing * (faceCount + 1));
      return (availableWidth / faceCount).clamp(minSpacing, imageWidth * 0.2);
    }
  }
}

/// Represents a face with its original position and arranged position
class ArrangedFace {
  final ui.Rect originalRect;
  final ui.Offset arrangedPosition;
  final ui.Size arrangedSize;
  final int personIndex;

  ArrangedFace({
    required this.originalRect,
    required this.arrangedPosition,
    required this.arrangedSize,
    required this.personIndex,
  });

  /// Get the arranged bounding box
  ui.Rect get arrangedRect => ui.Rect.fromLTWH(
        arrangedPosition.dx,
        arrangedPosition.dy,
        arrangedSize.width,
        arrangedSize.height,
      );
}
