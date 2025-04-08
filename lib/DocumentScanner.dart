import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as imge;


class DocumentScanner {
  final TextRecognizer _textRecognizer = TextRecognizer();
  final File _imageFile;
  RecognizedText? _recognizedText;
  List<TextBlock> textGroup = [];


  DocumentScanner._(this._imageFile);

  DocumentScanner(this._imageFile) {
    _processImage();
  }

  static Future<DocumentScanner> create(File imageFile) async {
    final scanner = DocumentScanner._(imageFile);
    await scanner._processImage();

    return scanner;
  }

  Future<void> _processImage() async {
    try {
      final inputImage = InputImage.fromFilePath(_imageFile.path);
      _recognizedText = await _textRecognizer.processImage(inputImage);
    } catch (e) {
      print('Erro ao processar imagem: $e');
      _recognizedText = null;
    }
  }

  Future<String> extractTextAndNormalise() async {
    String normalisedTextBox;

    final inputImage = InputImage.fromFile(_imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    textRecognizer.close();

    normalisedTextBox = recognizedText.text;
    normalisedTextBox = _normalizeText(normalisedTextBox);

    return normalisedTextBox;
  }

  String _normalizeText(String text) {
    String normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãäåǎȁȃ]'), 'a')
        .replaceAll(RegExp(r'[éèêẽëėęěȩ]'), 'e')
        .replaceAll(RegExp(r'[íìîĩïıĩīĭ]'), 'i')
        .replaceAll(RegExp(r'[óòôõöȯȱőǒºøǿ]'), 'o')
        .replaceAll(RegExp(r'[úùûũüůűųȕȗ]'), 'u')
        .replaceAll(RegExp(r'[çćĉċč]'), 'c')
        .replaceAll(RegExp(r'[ñńňņṅṇṉǹ]'), 'n')
        .replaceAll(RegExp(r'[ḧĥħḩḥ]'), 'h')
        .replaceAll(RegExp(r'[ĵǰǰ]'), 'j')
        .replaceAll(RegExp(r'[ķĺľļŗ]'), 'l')
        .replaceAll(RegExp(r'[ḿṅṇ]'), 'm')
        .replaceAll(RegExp(r'[ṕp̌ḧ]'), 'p')
        .replaceAll(RegExp(r'[śšṡṧẛ]'), 's')
        .replaceAll(RegExp(r'[ťţṫṯ]'), 't')
        .replaceAll(RegExp(r'[ẃẇẅẉŵ]'), 'w')
        .replaceAll(RegExp(r'[x̌x̱ẋ]'), 'x')
        .replaceAll(RegExp(r'[ýŷỳỹẏ]'), 'y')
        .replaceAll(RegExp(r'[żźžẑ]'), 'z');

    return normalized;
  }

  Future getTextCoordinatesAtImage(String text) async {
    if (_recognizedText == null) return null;
    for (TextBlock block in _recognizedText!.blocks) {
      if (block.text.toLowerCase().contains(text.toLowerCase())) {
        final points = block.cornerPoints;
        int xTopLeft = points.map((p) => p.x).reduce(math.min);
        int yTopLeft = points.map((p) => p.y).reduce(math.min);
        int xBottomRight = points.map((p) => p.x).reduce(math.max);
        int yBottomRight = points.map((p) => p.y).reduce(math.max);
        return [xTopLeft, yTopLeft, xBottomRight, yBottomRight];
      }
    }
    return null;
  }

  Future getCroppedImageByCoordinates(List<int> coordinates) async {
    if (coordinates.length != 4) return null;

    final int xTopLeft = coordinates[0];
    final int yTopLeft = coordinates[1];
    final int xBottomRight = coordinates[2];
    final int yBottomRight = coordinates[3];

    try {
      final imge.Image? originalImage = imge.decodeImage(_imageFile.readAsBytesSync());
      if (originalImage == null) return null;

      final int width = xBottomRight - xTopLeft;
      final int height = yBottomRight - yTopLeft;

      if (width <= 0 || height <= 0 || xTopLeft < 0 || yTopLeft < 0 ||
          xBottomRight > originalImage.width || yBottomRight > originalImage.height) {
        return null; // Coordenadas inválidas
      }

      return imge.copyCrop(
        originalImage,
        x: xTopLeft,
        y: yTopLeft,
        width: width,
        height: height,
      );
    } catch (e) {
      print('Erro ao recortar imagem: $e');
      return null;
    }
  }

  Future getMostFreqAngle() async{
    if (_recognizedText == null || _recognizedText!.blocks.isEmpty) return null;

    Map<double, int> angleFrequency = {};
    Map<double, List<TextBlock>> angleBlocks = {};

    for (TextBlock block in _recognizedText!.blocks) {
      if (block.cornerPoints.length >= 2) {
        final p1 = block.cornerPoints[0];
        final p2 = block.cornerPoints[1];
        double dx = (p2.x - p1.x).toDouble();
        double dy = (p2.y - p1.y).toDouble();
        double angle = math.atan2(dy, dx) * 180 / math.pi;

        // Normaliza o ângulo para [-90, 90]
        if (angle > 90) angle -= 180;
        if (angle < -90) angle += 180;

        angle = (angle * 10).round() / 10.0;

        angleFrequency[angle] = (angleFrequency[angle] ?? 0) + 1;
        angleBlocks[angle] ??= [];
        angleBlocks[angle]!.add(block);
      }
    }

    if (angleFrequency.isEmpty) return null;

    // Encontra o ângulo mais frequente
    double mostFreqAngle = angleFrequency.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // Popula textGroup com os blocos que têm o ângulo mais frequente
    textGroup = angleBlocks[mostFreqAngle] ?? [];

    return mostFreqAngle;
  }

  Future getTextAreaCoordinates() async {

    if (_recognizedText == null || _recognizedText!.blocks.isEmpty) return null;

    List<ui.Offset> points = [];
    for (TextBlock block in _recognizedText!.blocks) {
      points.addAll(block.cornerPoints.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())));
    }

    if (points.isEmpty) return null;

    // Encontra os pontos extremos
    int xTopLeft = points.map((p) => p.dx.toInt()).reduce(math.min);
    int yTopLeft = points.map((p) => p.dy.toInt()).reduce(math.min);
    int xBottomRight = points.map((p) => p.dx.toInt()).reduce(math.max);
    int yBottomRight = points.map((p) => p.dy.toInt()).reduce(math.max);

    return [xTopLeft, yTopLeft, xBottomRight, yBottomRight];
  }

  void dispose() {
    _textRecognizer.close();
  }
}