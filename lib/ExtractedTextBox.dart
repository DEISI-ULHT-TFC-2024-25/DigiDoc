import 'dart:math';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ExtractedTextBox {
  String text = "";
  String imagePath = "";
  List<TextBlock> _recognizedBlocks = [];

  ExtractedTextBox(this.imagePath);

  Future<bool> extractText() async {
    final inputImage = InputImage.fromFile(File(imagePath));
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    textRecognizer.close();

    _recognizedBlocks = recognizedText.blocks;
    text = recognizedText.text;
    return text.isNotEmpty;
  }

  List<List<int>> findWordCoordinates(String targetWord) {
    final coordinates = <List<int>>[];

    for (final block in _recognizedBlocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          if (element.text.toLowerCase() == targetWord.toLowerCase()) {
            coordinates.add([
              element.boundingBox.left.toInt(),
              element.boundingBox.top.toInt(),
              element.boundingBox.right.toInt(),
              element.boundingBox.bottom.toInt()
            ]);
          }
        }
      }
    }
    return coordinates;
  }

  String getTextInArea(List<int> coordinates) {
    final rect = Rect.fromLTRB(
        coordinates[0].toDouble(),
        coordinates[1].toDouble(),
        coordinates[2].toDouble(),
        coordinates[3].toDouble()
    );

    final buffer = StringBuffer();

    for (final block in _recognizedBlocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          if (rect.overlaps(element.boundingBox)) {
            buffer.write("${element.text} ");
          }
        }
      }
    }
    return buffer.toString().trim();
  }

  double getMostCommonTextAngle() {
    final angleCounts = <double, int>{};
    const precision = 0.1;

    for (final block in _recognizedBlocks) {
      final angle = _calculateAngleFromCorners(block.cornerPoints);
      final roundedAngle = (angle * precision).round() / precision;

      angleCounts.update(roundedAngle, (count) => count + 1, ifAbsent: () => 1);
    }

    if (angleCounts.isEmpty) return 0;

    return angleCounts.entries.reduce(
            (a, b) => a.value > b.value ? a : b
    ).key;
  }

  double _calculateAngleFromCorners(List<Point<int>> corners) {
    if (corners.length < 2) return 0;

    final p1 = corners[2]; // Bottom-left
    final p2 = corners[3]; // Bottom-right

    final dx = p2.x - p1.x;
    final dy = p2.y - p1.y;

    return atan2(dy, dx) * (180 / pi);
  }
}