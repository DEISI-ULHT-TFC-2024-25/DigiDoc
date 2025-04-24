import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as imge;
import 'package:path_provider/path_provider.dart';

class DocScanner {
  final TextRecognizer _textRecognizer = TextRecognizer();
  late File _imageFile;
  imge.Image? originalImage;
  imge.Image? modifiedImage;
  RecognizedText? _recognizedText;
  List<TextBlock> textGroup = [];

  DocScanner._(this._imageFile);

  static Future<DocScanner> create(File imageFile) async {
    final scanner = DocScanner._(imageFile);
    await scanner._initialize();
    return scanner;
  }

  Future<void> _initialize() async {
    try {
      print('Inicializando DocumentScanner para ${_imageFile.path}');
      // Carregar a imagem original
      final imageBytes = _imageFile.readAsBytesSync();
      originalImage = imge.decodeImage(imageBytes);
      if (originalImage == null || originalImage!.width <= 0 || originalImage!.height <= 0) {
        throw Exception('Imagem inválida: Não foi possível decodificar ou dimensões inválidas');
      }
      print('Imagem original carregada: ${originalImage!.width}x${originalImage!.height}');

      // Processar a imagem original para reconhecimento de texto
      await _processImage();

      // Obter o ângulo mais frequente e rotacionar a imagem
      double? angle = await getMostFreqAngle() ?? 0.0; // Fallback para 0
      print('Ângulo mais frequente (original): $angle');
      modifiedImage = _rotateImage(originalImage!, angle);
      if (modifiedImage == null) {
        print('Erro: Falha ao rotacionar a imagem, usando imagem original');
        modifiedImage = originalImage;
      }
      print('Imagem rotacionada: ${modifiedImage!.width}x${modifiedImage!.height}');

      // Salvar a imagem rotacionada em um arquivo temporário
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/rotated_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rotatedImageFile = File(tempPath)..writeAsBytesSync(imge.encodeJpg(modifiedImage!));
      print('Imagem rotacionada salva em: $tempPath');

      // Reprocessar a imagem rotacionada para atualizar _recognizedText e textGroup
      _imageFile = rotatedImageFile;
      await _processImage();
      angle = await getMostFreqAngle(); // Recalcular textGroup na imagem rotacionada
      print('Ângulo mais frequente (rotacionada): ${angle ?? 'Não calculado'}');
    } catch (e) {
      print('Erro ao inicializar DocumentScanner: $e');
      _recognizedText = null;
      modifiedImage = originalImage; // Fallback para imagem original
    }
  }

  Future<void> _processImage() async {
    try {
      print('Processando imagem: ${_imageFile.path}');
      final inputImage = InputImage.fromFilePath(_imageFile.path);
      _recognizedText = await _textRecognizer.processImage(inputImage);
      print('Texto reconhecido: ${_recognizedText?.blocks.length ?? 0} blocos');
    } catch (e) {
      print('Erro ao processar imagem: $e');
      _recognizedText = null;
    }
  }

  imge.Image? _rotateImage(imge.Image image, double angleDegrees) {
    try {
      print('Rotacionando imagem: ${image.width}x${image.height}, ângulo: $angleDegrees');
      final rotated = imge.copyRotate(image, angle: -angleDegrees);
      if (rotated.width <= 0 || rotated.height <= 0) {
        print('Erro: Imagem rotacionada com dimensões inválidas: ${rotated.width}x${rotated.height}');
        return null;
      }
      print('Rotação bem-sucedida: ${rotated.width}x${rotated.height}');
      return rotated;
    } catch (e) {
      print('Erro ao rotacionar imagem: $e');
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
      print('Nenhum texto reconhecido disponível');
      return null;
    }
    for (TextBlock block in _recognizedText!.blocks) {
      if (block.text.toLowerCase().contains(text.toLowerCase())) {
        final points = block.cornerPoints;
        int xTopLeft = points.map((p) => p.x).reduce(math.min);
        int yTopLeft = points.map((p) => p.y).reduce(math.min);
        int xBottomRight = points.map((p) => p.x).reduce(math.max);
        int yBottomRight = points.map((p) => p.y).reduce(math.max);
        print('Coordenadas encontradas para "$text": [$xTopLeft, $yTopLeft, $xBottomRight, $yBottomRight]');
        return [xTopLeft, yTopLeft, xBottomRight, yBottomRight];
      }
    }
    print('Texto "$text" não encontrado');
    return null;
  }

  Future<imge.Image?> getCroppedImageByCoordinates(List<int> coordinates) async {
    if (coordinates.length != 4) {
      print('Erro: Coordenadas inválidas, esperado 4 valores');
      return null;
    }

    final int xTopLeft = coordinates[0];
    final int yTopLeft = coordinates[1];
    final int xBottomRight = coordinates[2];
    final int yBottomRight = coordinates[3];

    try {
      if (modifiedImage == null) {
        print('Erro: Imagem modificada não disponível');
        return null;
      }

      final int width = xBottomRight - xTopLeft;
      final int height = yBottomRight - yTopLeft;

      if (width <= 0 || height <= 0 || xTopLeft < 0 || yTopLeft < 0 ||
          xBottomRight > modifiedImage!.width || yBottomRight > modifiedImage!.height) {
        print('Erro: Coordenadas inválidas: [$xTopLeft, $yTopLeft, $xBottomRight, $yBottomRight]');
        return null;
      }

      final croppedImage = imge.copyCrop(
        modifiedImage!,
        x: xTopLeft,
        y: yTopLeft,
        width: width,
        height: height,
      );
      print('Imagem recortada: ${croppedImage.width}x${croppedImage.height}');
      return croppedImage;
    } catch (e) {
      print('Erro ao recortar imagem: $e');
      return null;
    }
  }

  Future<double?> getMostFreqAngle() async {
    if (_recognizedText == null || _recognizedText!.blocks.isEmpty) {
      print('Nenhum bloco de texto encontrado');
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
      print('Nenhum ângulo válido encontrado');
      return null;
    }

    // Encontra o ângulo mais frequente
    double mostFreqAngle = angleFrequency.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    print('Ângulo mais frequente: $mostFreqAngle, com ${angleFrequency[mostFreqAngle]} blocos');

    // Popula textGroup com os blocos que têm o ângulo mais frequente
    textGroup = angleBlocks[mostFreqAngle] ?? [];
    print('Blocos em textGroup: ${textGroup.length}');

    return mostFreqAngle;
  }

  Future<List<int>?> getTextAreaCoordinates() async {
    if (_recognizedText == null) {
      print('Nenhum texto reconhecido disponível');
      return null;
    }

    // Usar textGroup se não estiver vazio, caso contrário usar todos os blocos
    List<TextBlock> blocks = textGroup.isNotEmpty ? textGroup : _recognizedText!.blocks;
    if (blocks.isEmpty) {
      print('Nenhum bloco de texto disponível');
      return null;
    }

    List<ui.Offset> points = [];
    for (TextBlock block in blocks) {
      points.addAll(block.cornerPoints.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())));
    }

    if (points.isEmpty) {
      print('Nenhum ponto de canto encontrado');
      return null;
    }

    // Encontra os pontos extremos
    int xTopLeft = points.map((p) => p.dx.toInt()).reduce(math.min);
    int yTopLeft = points.map((p) => p.dy.toInt()).reduce(math.min);
    int xBottomRight = points.map((p) => p.dx.toInt()).reduce(math.max);
    int yBottomRight = points.map((p) => p.dy.toInt()).reduce(math.max);
    print('Coordenadas brutas: [$xTopLeft, $yTopLeft, $xBottomRight, $yBottomRight]');

    // Adiciona uma margem de 15% da largura/altura da imagem
    if (modifiedImage == null) {
      print('Erro: Imagem modificada não disponível');
      return null;
    }

    final marginX = (modifiedImage!.width * 0.15).round();
    final marginY = (modifiedImage!.height * 0.15).round();

    xTopLeft = math.max(0, xTopLeft - marginX);
    yTopLeft = math.max(0, yTopLeft - marginY);
    xBottomRight = math.min(modifiedImage!.width, xBottomRight + marginX);
    yBottomRight = math.min(modifiedImage!.height, yBottomRight + marginY);

    print('Coordenadas com margem: [$xTopLeft, $yTopLeft, $xBottomRight, $yBottomRight]');
    return [xTopLeft, yTopLeft, xBottomRight, yBottomRight];
  }

  void dispose() {
    _textRecognizer.close();
  }
}