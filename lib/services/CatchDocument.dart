import 'dart:io';
import 'dart:math' as math;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as imge;
import 'package:path_provider/path_provider.dart';

class CatchDocument {
  final File _imageFile;
  late imge.Image? originalImage;
  late imge.Image? modifiedImage;
  imge.Image? finalImage;
  List<List<int>>? documentCorners;

  final TextRecognizer _textRecognizer = TextRecognizer();
  RecognizedText? _recognizedText;
  List<TextBlock> textGroup = [];

  CatchDocument(this._imageFile);

  Future<void> initialize() async {
    try {
      final imageBytes = _imageFile.readAsBytesSync();
      originalImage = imge.decodeImage(imageBytes);
      if (originalImage == null || originalImage!.width <= 0 || originalImage!.height <= 0) {
        throw Exception('Imagem inválida: Não foi possível decodificar ou dimensões inválidas');
      }
      print('Imagem original carregada: ${originalImage!.width}x${originalImage!.height}');

      await _processImage();

      if (_recognizedText == null || _recognizedText!.blocks.isEmpty) {
        throw Exception('Nenhum documento detectado: Nenhum texto encontrado na imagem');
      }

      double? angle = await getMostFreqAngle();
      if (angle == null || angle == 0.0) {
        modifiedImage = originalImage;
      } else {
        modifiedImage = await rotateImage(originalImage!, angle);
        if (modifiedImage == null) {
          modifiedImage = originalImage;
        }
      }
      print('Imagem modificada: ${modifiedImage?.width}x${modifiedImage?.height}');

      if (angle != null && angle != 0.0) {
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/rotated_${DateTime.now().millisecondsSinceEpoch}.jpg';
        File(tempPath).writeAsBytesSync(imge.encodeJpg(modifiedImage!));
        await _processImage(tempPath);
        if (_recognizedText == null || _recognizedText!.blocks.isEmpty) {
          throw Exception('Nenhum texto detectado na imagem rotacionada');
        }
        await getMostFreqAngle();
      }

      documentCorners = await _getDocumentCorners();
      print('Cantos detectados: $documentCorners');

      if (documentCorners != null) {
        final croppedImage = await cropWithCustomCorners(documentCorners!);
        if (croppedImage != null) {
          modifiedImage = croppedImage;
        }
      }

      finalImage = modifiedImage;
      print('Imagem final definida: ${finalImage?.width}x${finalImage?.height}');
    } catch (e) {
      print('Erro na inicialização: $e');
      rethrow;
    }
  }

  Future<void> _processImage([String? imagePath]) async {
    try {
      final path = imagePath ?? _imageFile.path;
      print('Processando imagem: $path');
      final inputImage = InputImage.fromFilePath(path);
      _recognizedText = await _textRecognizer.processImage(inputImage);
      print('Texto reconhecido: ${_recognizedText?.blocks.length ?? 0} blocos');
    } catch (e) {
      print('Erro ao processar imagem: $e');
      _recognizedText = null;
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

    double mostFreqAngle = angleFrequency.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    print('Ângulo mais frequente: $mostFreqAngle, com ${angleFrequency[mostFreqAngle]} blocos');

    const angleTolerance = 5.0;
    textGroup = _recognizedText!.blocks.where((block) {
      if (block.cornerPoints.length < 2) return false;
      final p1 = block.cornerPoints[0];
      final p2 = block.cornerPoints[1];
      double dx = (p2.x - p1.x).toDouble();
      double dy = (p2.y - p1.y).toDouble();
      double angle = math.atan2(dy, dx) * 180 / math.pi;

      if (angle > 90) angle -= 180;
      if (angle < -90) angle += 180;
      angle = (angle * 10).round() / 10.0;

      return (angle - mostFreqAngle).abs() <= angleTolerance;
    }).toList();
    print('Blocos em textGroup: ${textGroup.length}');

    return mostFreqAngle;
  }

  Future<imge.Image?> rotateImage(imge.Image originalImg, double angleDegrees) async {
    try {
      print('Rotacionando imagem: ${originalImg.width}x${originalImg.height}, ângulo: $angleDegrees');
      final rotated = imge.copyRotate(originalImg, angle: -angleDegrees);
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

  Future<List<List<int>>?> _getDocumentCorners() async {
    if (textGroup.isEmpty) {
      print('Nenhum bloco de texto para determinar cantos');
      return null;
    }

    int minX = textGroup[0].cornerPoints[0].x;
    int maxX = minX;
    int minY = textGroup[0].cornerPoints[0].y;
    int maxY = minY;

    for (var block in textGroup) {
      for (var point in block.cornerPoints) {
        minX = math.min(minX, point.x);
        maxX = math.max(maxX, point.x);
        minY = math.min(minY, point.y);
        maxY = math.max(maxY, point.y);
      }
    }

    const margin = 20;
    minX = math.max(0, minX - margin);
    maxX = math.min(modifiedImage!.width, maxX + margin);
    minY = math.max(0, minY - margin);
    maxY = math.min(modifiedImage!.height, maxY + margin);

    print('Cantos calculados: [[$minX, $minY], [$maxX, $minY], [$maxX, $maxY], [$minX, $maxY]]');
    return [
      [minX, minY], // Top-left
      [maxX, minY], // Top-right
      [maxX, maxY], // Bottom-right
      [minX, maxY], // Bottom-left
    ];
  }

  Future<imge.Image?> cropWithCustomCorners(List<List<int>> customCorners) async {
    try {
      if (customCorners.length != 4) {
        print('Erro: São necessários exatamente 4 cantos, mas recebidos ${customCorners.length}');
        return null;
      }
      if (modifiedImage == null) {
        print('Erro: Imagem modificada é nula');
        return null;
      }

      final imageWidth = modifiedImage!.width;
      final imageHeight = modifiedImage!.height;
      print('Recortando imagem: ${imageWidth}x${imageHeight}, Cantos=$customCorners');

      for (var corner in customCorners) {
        if (corner.length != 2) {
          print('Erro: Canto inválido: $corner');
          return null;
        }
        final x = corner[0];
        final y = corner[1];
        if (x < 0 || x >= imageWidth || y < 0 || y >= imageHeight) {
          print('Erro: Canto fora dos limites: [$x, $y], Limites=[0, ${imageWidth-1}]x[0, ${imageHeight-1}]');
          return null;
        }
      }

      final minX = customCorners.map((c) => c[0]).reduce((a, b) => a < b ? a : b);
      final maxX = customCorners.map((c) => c[0]).reduce((a, b) => a > b ? a : b);
      final minY = customCorners.map((c) => c[1]).reduce((a, b) => a < b ? a : b);
      final maxY = customCorners.map((c) => c[1]).reduce((a, b) => a > b ? a : b);

      final cropWidth = maxX - minX;
      final cropHeight = maxY - minY;

      if (cropWidth <= 0 || cropHeight <= 0) {
        print('Erro: Dimensões do recorte inválidas: ${cropWidth}x${cropHeight}');
        return null;
      }

      print('Executando recorte: x=$minX, y=$minY, width=$cropWidth, height=$cropHeight');
      final croppedImage = imge.copyCrop(
        modifiedImage!,
        x: minX,
        y: minY,
        width: cropWidth,
        height: cropHeight,
      );

      if (croppedImage.width <= 0 || croppedImage.height <= 0) {
        print('Erro: Imagem recortada inválida: ${croppedImage.width}x${croppedImage.height}');
        return null;
      }

      print('Recorte bem-sucedido: ${croppedImage.width}x${croppedImage.height}');
      return croppedImage;
    } catch (e) {
      print('Erro ao recortar com cantos personalizados: $e');
      return null;
    }
  }

  Future<imge.Image?> cropWithCorners(List<List<double>> corners) async {
    try {
      if (corners.length != 4) {
        print('Erro: São necessários exatamente 4 cantos, mas recebidos ${corners.length}');
        return null;
      }
      if (originalImage == null) {
        print('Erro: Imagem original é nula');
        return null;
      }

      final imageWidth = originalImage!.width;
      final imageHeight = originalImage!.height;
      print('Iniciando recorte com cantos: Imagem=${imageWidth}x${imageHeight}, Cantos=$corners');

      // Validate corners
      for (var corner in corners) {
        if (corner.length != 2) {
          print('Erro: Canto inválido: $corner');
          return null;
        }
        final x = corner[0];
        final y = corner[1];
        if (x.isNaN || y.isNaN || x < 0 || x >= imageWidth || y < 0 || y >= imageHeight) {
          print('Erro: Canto fora dos limites ou inválido: [$x, $y], Limites=[0, ${imageWidth-1}]x[0, ${imageHeight-1}]');
          return null;
        }
      }

      // Calculate bounding box from the four points
      final minX = corners.map((c) => c[0]).reduce((a, b) => a < b ? a : b);
      final maxX = corners.map((c) => c[0]).reduce((a, b) => a > b ? a : b);
      final minY = corners.map((c) => c[1]).reduce((a, b) => a < b ? a : b);
      final maxY = corners.map((c) => c[1]).reduce((a, b) => a > b ? a : b);

      final cropWidth = (maxX - minX).ceil();
      final cropHeight = (maxY - minY).ceil();

      if (cropWidth <= 0 || cropHeight <= 0) {
        print('Erro: Dimensões do recorte inválidas: ${cropWidth}x${cropHeight}');
        return null;
      }

      // Ensure crop parameters are within bounds
      final cropX = minX.round().clamp(0, imageWidth - 1);
      final cropY = minY.round().clamp(0, imageHeight - 1);
      final safeWidth = math.min(cropWidth, imageWidth - cropX);
      final safeHeight = math.min(cropHeight, imageHeight - cropY);

      if (safeWidth <= 0 || safeHeight <= 0) {
        print('Erro: Dimensões seguras do recorte inválidas: ${safeWidth}x${safeHeight}');
        return null;
      }

      // Perform crop
      print('Executando recorte: x=$cropX, y=$cropY, width=$safeWidth, height=$safeHeight');
      final croppedImage = imge.copyCrop(
        originalImage!,
        x: cropX,
        y: cropY,
        width: safeWidth,
        height: safeHeight,
      );

      if (croppedImage.width <= 0 || croppedImage.height <= 0) {
        print('Erro: Imagem recortada inválida: ${croppedImage.width}x${croppedImage.height}');
        return null;
      }

      // Save debug image
      final tempDir = await getTemporaryDirectory();
      final debugPath = '${tempDir.path}/debug_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      File(debugPath).writeAsBytesSync(imge.encodeJpg(croppedImage));
      print('Imagem de depuração salva: $debugPath');

      print('Recorte bem-sucedido: ${croppedImage.width}x${croppedImage.height}');
      return croppedImage;
    } catch (e) {
      print('Erro ao aplicar recorte com cantos: $e');
      return null;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}