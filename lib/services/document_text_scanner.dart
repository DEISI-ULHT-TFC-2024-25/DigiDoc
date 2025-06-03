import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as imge;
import 'package:path_provider/path_provider.dart';

class DocumentTextScanner {
  final TextRecognizer _textRecognizer = TextRecognizer();
  late File _imageFile;
  imge.Image? originalImage;
  imge.Image? modifiedImage;
  RecognizedText? _recognizedText;
  List<TextBlock> textGroup = [];

  DocumentTextScanner._(this._imageFile);

  static Future<DocumentTextScanner> create(File imageFile) async {
    final scanner = DocumentTextScanner._(imageFile);
    await scanner._initialize();
    return scanner;
  }

  Future<void> _initialize() async {
    try {
      final imageBytes = _imageFile.readAsBytesSync();
      originalImage = imge.decodeImage(imageBytes);
      if (originalImage == null || originalImage!.width <= 0 || originalImage!.height <= 0) {
        throw Exception('Imagem inválida: Não foi possível decodificar ou dimensões inválidas');
      }

      // Processar a imagem original para reconhecimento de texto
      await _processImage();

      // Obter coordenadas do texto para estimar o contorno do documento
      final coordinates = await getTextAreaCoordinates();
      if (coordinates != null) {
        modifiedImage = await getCroppedImageByCoordinates(coordinates);
        if (modifiedImage == null) {
          modifiedImage = originalImage;
        } else {

          // Salvar a imagem recortada em um arquivo temporário
          final tempDir = await getTemporaryDirectory();
          final tempPath = '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final croppedImageFile = File(tempPath)..writeAsBytesSync(imge.encodeJpg(modifiedImage!));
          _imageFile = croppedImageFile;
          await _processImage(); // Reprocessar a imagem recortada
        }
      } else {
        modifiedImage = originalImage;
      }

      // Obter o ângulo mais frequente e rotacionar a imagem
      double? angle = await getMostFreqAngle() ?? 0.0;
      if (angle != 0.0) {
        modifiedImage = _rotateImage(modifiedImage!, angle);
        if (modifiedImage == null) {
          modifiedImage = originalImage;
        } else {
          // Salvar a imagem rotacionada
          final tempDir = await getTemporaryDirectory();
          final tempPath = '${tempDir.path}/rotated_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final rotatedImageFile = File(tempPath)..writeAsBytesSync(imge.encodeJpg(modifiedImage!));
          _imageFile = rotatedImageFile;
          await _processImage();
        }
      }
    } catch (e) {
      _recognizedText = null;
      modifiedImage = originalImage;
    }
  }

  Future<void> _processImage() async {
    try {
      final inputImage = InputImage.fromFilePath(_imageFile.path);
      _recognizedText = await _textRecognizer.processImage(inputImage);
    } catch (e) {
      _recognizedText = null;
    }
  }

  imge.Image? _rotateImage(imge.Image image, double angleDegrees) {
    try {
      final rotated = imge.copyRotate(image, angle: -angleDegrees);
      if (rotated.width <= 0 || rotated.height <= 0) {
        return null;
      }
      return rotated;
    } catch (e) {
      return null;
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

  Future<List<int>?> getTextCoordinatesAtImage(String text) async {
    if (_recognizedText == null) {
      return null;
    }
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

  Future<imge.Image?> getCroppedImageByCoordinates(List<int> coordinates) async {
    if (coordinates.length != 4) {
      return null;
    }

    final int xTopLeft = coordinates[0];
    final int yTopLeft = coordinates[1];
    final int xBottomRight = coordinates[2];
    final int yBottomRight = coordinates[3];

    try {
      if (modifiedImage == null) {
        return null;
      }

      final int width = xBottomRight - xTopLeft;
      final int height = yBottomRight - yTopLeft;

      if (width <= 0 || height <= 0 || xTopLeft < 0 || yTopLeft < 0 ||
          xBottomRight > modifiedImage!.width || yBottomRight > modifiedImage!.height) {
        return null;
      }

      final croppedImage = imge.copyCrop(
        modifiedImage!,
        x: xTopLeft,
        y: yTopLeft,
        width: width,
        height: height,
      );
      return croppedImage;
    } catch (e) {
      return null;
    }
  }

  Future<double?> getMostFreqAngle() async {
    if (_recognizedText == null || _recognizedText!.blocks.isEmpty) {
      return null;
    }

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

    if (angleFrequency.isEmpty) {
      return null;
    }

    // Encontra o ângulo mais frequente
    double mostFreqAngle = angleFrequency.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // Popula textGroup com os blocos que têm o ângulo mais frequente
    textGroup = angleBlocks[mostFreqAngle] ?? [];

    return mostFreqAngle;
  }

  Future<List<int>?> getTextAreaCoordinates() async {
    if (_recognizedText == null) {
      return null;
    }

    // Usar textGroup se não estiver vazio, caso contrário usar todos os blocos
    List<TextBlock> blocks = textGroup.isNotEmpty ? textGroup : _recognizedText!.blocks;
    if (blocks.isEmpty) {
      return null;
    }

    List<ui.Offset> points = [];
    for (TextBlock block in blocks) {
      points.addAll(block.cornerPoints.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())));
    }

    if (points.isEmpty) {
      return null;
    }

    // Encontra os pontos extremos
    int xTopLeft = points.map((p) => p.dx.toInt()).reduce(math.min);
    int yTopLeft = points.map((p) => p.dy.toInt()).reduce(math.min);
    int xBottomRight = points.map((p) => p.dx.toInt()).reduce(math.max);
    int yBottomRight = points.map((p) => p.dy.toInt()).reduce(math.max);

    // Adiciona uma margem de 15% da largura/altura da imagem
    if (modifiedImage == null) {
      return null;
    }

    final marginX = (modifiedImage!.width * 0.15).round();
    final marginY = (modifiedImage!.height * 0.15).round();

    xTopLeft = math.max(0, xTopLeft - marginX);
    yTopLeft = math.max(0, yTopLeft - marginY);
    xBottomRight = math.min(modifiedImage!.width, xBottomRight + marginX);
    yBottomRight = math.min(modifiedImage!.height, yBottomRight + marginY);

    return [xTopLeft, yTopLeft, xBottomRight, yBottomRight];
  }

  void dispose() {
    _textRecognizer.close();
  }
}