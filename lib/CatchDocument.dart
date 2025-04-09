import 'dart:io';
import 'package:image/image.dart' as imge;
import 'DocumentScanner.dart';
import 'DocDetector.dart';

class CatchDocument {
  final File _imageFile;
  late DocumentScanner _scanner;
  late DocDetector _detector;
  late imge.Image? originalImage;

  CatchDocument(this._imageFile);

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

  Future<void> initialize() async {
    try {
      print('Inicializando CatchDocument para ${_imageFile.path}');
      _scanner = await DocumentScanner.create(_imageFile);
      double angle = await _scanner.getMostFreqAngle();
      print('Ângulo mais frequente detectado: $angle');

      final imageBytes = _imageFile.readAsBytesSync();
      originalImage = imge.decodeImage(imageBytes);
      if (originalImage == null || originalImage!.width <= 0 || originalImage!.height <= 0) {
        throw Exception('Imagem inválida: Não foi possível decodificar ou dimensões inválidas (${originalImage?.width}x${originalImage?.height})');
      }
      print('Imagem original carregada: ${originalImage!.width}x${originalImage!.height}');

      imge.Image? rotatedImage = await rotateImage(originalImage!, angle);
      if (rotatedImage == null) {
        print('Rotação falhou, usando imagem original');
      }
      _detector = DocDetector(image: rotatedImage ?? originalImage!);
      print('Detector inicializado com imagem: ${_detector.imageResult!.width}x${_detector.imageResult!.height}');
    } catch (e) {
      print('Erro durante inicialização: $e');
      rethrow;
    }
  }

  Future<imge.Image?> getCroppedDocument() async {
    try {
      print('Obtendo documento recortado');
      final coordinates = await _scanner.getTextAreaCoordinates();
      if (coordinates == null) {
        print('Nenhuma área de texto detectada');
        return null;
      }
      print('Coordenadas da área de texto: $coordinates');

      final int xTopLeft = coordinates[0];
      final int yTopLeft = coordinates[1];
      final int xBottomRight = coordinates[2];
      final int yBottomRight = coordinates[3];

      final int textBoxWidth = xBottomRight - xTopLeft;
      final int textBoxHeight = yBottomRight - yTopLeft;
      final int imageWidth = _detector.imageResult!.width;
      final int imageHeight = _detector.imageResult!.height;
      print('Dimensões calculadas: $textBoxWidth x $textBoxHeight');
      print('Dimensões da imagem: $imageWidth x $imageHeight');

      if (textBoxWidth <= 0 || textBoxHeight <= 0) {
        print('Erro: Dimensões do recorte inválidas: $textBoxWidth x $textBoxHeight');
        return null;
      }
      if (xTopLeft < 0 || yTopLeft < 0 || xBottomRight > imageWidth || yBottomRight > imageHeight) {
        print('Erro: Coordenadas fora dos limites: ($xTopLeft, $yTopLeft) - ($xBottomRight, $yBottomRight)');
        return null;
      }

      final List<int> startPointTop = [(xTopLeft + xBottomRight) ~/ 2, yTopLeft];
      final List<int> startPointBottom = [(xTopLeft + xBottomRight) ~/ 2, yBottomRight];
      final List<int> startPointLeft = [xTopLeft, (yTopLeft + yBottomRight) ~/ 2];
      final List<int> startPointRight = [xBottomRight, (yTopLeft + yBottomRight) ~/ 2];
      print('Pontos iniciais: Top=$startPointTop, Bottom=$startPointBottom, Left=$startPointLeft, Right=$startPointRight');

      try {
        _detector.catchDocument(
          image: _detector.imageResult!,
          width: imageWidth,
          height: imageHeight,
          startPointLeft: startPointLeft,
          startPointTop: startPointTop,
          startPointRight: startPointRight,
          startPointBottom: startPointBottom,
        );
      } catch (e) {
        print('Erro em catchDocument: $e');
        // Fallback para recorte básico
        final croppedImage = imge.copyCrop(
          _detector.imageResult!,
          x: xTopLeft,
          y: yTopLeft,
          width: textBoxWidth,
          height: textBoxHeight,
        );
        if (croppedImage.width > 0 && croppedImage.height > 0) {
          print('Fallback bem-sucedido: ${croppedImage.width}x${croppedImage.height}');
          return croppedImage;
        } else {
          print('Fallback falhou: dimensões inválidas');
          return null;
        }
      }

      if (_detector.imageResult == null || _detector.imageResult!.width <= 0 || _detector.imageResult!.height <= 0) {
        print('Erro: Imagem recortada inválida: ${_detector.imageResult?.width}x${_detector.imageResult?.height}');
        return null;
      }
      print('Documento recortado com sucesso: ${_detector.imageResult!.width}x${_detector.imageResult!.height}');
      return _detector.imageResult;
    } catch (e) {
      print('Erro ao obter documento recortado: $e');
      return null;
    }
  }

  Future<imge.Image?> cropWithCustomCorners(List<List<int>> customCorners) async {
    try {
      if (customCorners.length != 4) {
        print('Erro: São necessários exatamente 4 cantos para o recorte');
        return null;
      }
      print('Recortando com cantos personalizados: $customCorners');

      final imageWidth = originalImage!.width;
      final imageHeight = originalImage!.height;

      for (var corner in customCorners) {
        if (corner[0] < 0 || corner[0] >= imageWidth || corner[1] < 0 || corner[1] >= imageHeight) {
          print('Erro: Canto fora dos limites: ${corner[0]}, ${corner[1]}');
          return null;
        }
      }

      final int minX = customCorners.map((c) => c[0]).reduce((a, b) => a < b ? a : b);
      final int maxX = customCorners.map((c) => c[0]).reduce((a, b) => a > b ? a : b);
      final int minY = customCorners.map((c) => c[1]).reduce((a, b) => a < b ? a : b);
      final int maxY = customCorners.map((c) => c[1]).reduce((a, b) => a > b ? a : b);

      if (maxX - minX <= 0 || maxY - minY <= 0) {
        print('Erro: Dimensões do recorte inválidas: ${(maxX - minX)}x${(maxY - minY)}');
        return null;
      }

      final List<int> startPointTop = [
        (customCorners[0][0] + customCorners[1][0]) ~/ 2,
        customCorners[0][1]
      ];
      final List<int> startPointBottom = [
        (customCorners[2][0] + customCorners[3][0]) ~/ 2,
        customCorners[2][1]
      ];
      final List<int> startPointLeft = [
        customCorners[0][0],
        (customCorners[0][1] + customCorners[3][1]) ~/ 2
      ];
      final List<int> startPointRight = [
        customCorners[1][0],
        (customCorners[1][1] + customCorners[2][1]) ~/ 2
      ];
      print('Pontos iniciais personalizados: Top=$startPointTop, Bottom=$startPointBottom, Left=$startPointLeft, Right=$startPointRight');

      _detector.catchDocument(
        image: originalImage!,
        width: imageWidth,
        height: imageHeight,
        startPointLeft: startPointLeft,
        startPointTop: startPointTop,
        startPointRight: startPointRight,
        startPointBottom: startPointBottom,
      );

      if (_detector.imageResult == null || _detector.imageResult!.width <= 0 || _detector.imageResult!.height <= 0) {
        print('Erro: Imagem recortada personalizada inválida: ${_detector.imageResult?.width}x${_detector.imageResult?.height}');
        return null;
      }
      print('Recorte personalizado bem-sucedido: ${_detector.imageResult!.width}x${_detector.imageResult!.height}');
      return _detector.imageResult;
    } catch (e) {
      print('Erro ao recortar com cantos personalizados: $e');
      return null;
    }
  }

  void dispose() {
    _scanner.dispose();
  }
}