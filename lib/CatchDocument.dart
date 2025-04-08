import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as imge;
import 'DocumentScanner.dart'; // Importe o arquivo correto
import 'DocDetector.dart'; // Importe o arquivo correto

class CatchDocument {
  final File _imageFile;
  late DocumentScanner _scanner;
  late DocDetector _detector;
  late imge.Image? originalImage;

  CatchDocument(this._imageFile);

  Future<imge.Image?> rotateImage(imge.Image originalImg, double angleDegrees) async {
    try {
      final rotated = imge.copyRotate(originalImg, angle: -angleDegrees);
      return rotated;
    } catch (e) {
      print('Erro ao rotacionar imagem: $e');
      return null;
    }
  }


  /// Inicializa o scanner e o detector com a imagem fornecida
  Future<void> initialize() async {
    _scanner = await DocumentScanner.create(_imageFile);
    double angle = await _scanner.getMostFreqAngle();
    final imageBytes = _imageFile.readAsBytesSync();
    originalImage = imge.decodeImage(imageBytes);
    if (originalImage == null) {
      throw Exception('Não foi possível decodificar a imagem');
    } else {
      imge.Image? result = await rotateImage(originalImage!, angle);
      _detector = DocDetector(image: result??originalImage!);
    }
  }

  /// Retorna a imagem do documento recortada
  Future<imge.Image?> getCroppedDocument() async {
    // Passo 1: Obter as coordenadas da área de texto com DocumentScanner
    final coordinates = await _scanner.getTextAreaCoordinates();
    if (coordinates == null) {
      print('Nenhuma área de texto detectada');
      return null;
    }

    final int xTopLeft = coordinates[0];
    final int yTopLeft = coordinates[1];
    final int xBottomRight = coordinates[2];
    final int yBottomRight = coordinates[3];

    // Passo 2: Calcular os pontos centrais das arestas
    final int textBoxWidth = xBottomRight - xTopLeft;
    final int textBoxHeight = yBottomRight - yTopLeft;
    final int imageWidth = _detector.imageResult!.width;
    final int imageHeight = _detector.imageResult!.height;

    final List<int> startPointTop = [(xTopLeft + xBottomRight) ~/ 2, yTopLeft];
    final List<int> startPointBottom = [(xTopLeft + xBottomRight) ~/ 2, yBottomRight];
    final List<int> startPointLeft = [xTopLeft, (yTopLeft + yBottomRight) ~/ 2];
    final List<int> startPointRight = [xBottomRight, (yTopLeft + yBottomRight) ~/ 2];

    // Passo 3: Usar DocDetector para detectar e recortar o documento
    _detector.catchDocument(
      image: _detector.imageResult!,
      width: imageWidth,
      height: imageHeight,
      startPointLeft: startPointLeft,
      startPointTop: startPointTop,
      startPointRight: startPointRight,
      startPointBottom: startPointBottom,
    );

    // Passo 4: Retornar a imagem recortada
    if (_detector.imageResult != null) {
      return _detector.imageResult;
    } else {
      print('Falha ao recortar o documento');
      return null;
    }
  }

  /// Libera os recursos
  void dispose() {
    _scanner.dispose();
  }
}