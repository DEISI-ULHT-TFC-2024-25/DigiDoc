import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as imge;
import 'package:path_provider/path_provider.dart';

class TextProcessor {
  String normalizeText(String text) {
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
        .replaceAll(RegExp(r'[żźžẑ]'), 'z')
        .replaceAll(RegExp(r'[\r]'), ' ')
        .replaceAll(RegExp(r'[\n]'), ' ')
        .replaceAll(RegExp(r'[\t]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    return normalized;
  }

  Future<void> processDocumentAndSaveTextMap({
    required String docTypeName,
    required XFile imageFile,
    required List<String> textsToFind,
  }) async {
    final textRecognizer = TextRecognizer();
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognizedText = await textRecognizer.processImage(inputImage);

      final imageBytes = await imageFile.readAsBytes();
      final image = imge.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Não foi possível decodificar a imagem');
      }
      final imageWidth = image.width;
      final imageHeight = image.height;

      final textCoordinatesMap = <String, List<double>>{};

      for (final text in textsToFind) {
        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
            String lineText = normalizeText(line.text);
            if (lineText.contains(text)) {
              final corners = line.cornerPoints;
              if (corners.length >= 2) {
                double xMin = corners[0].x.toDouble();
                double yMin = corners[0].y.toDouble();
                double xMax = corners[0].x.toDouble();
                double yMax = corners[0].y.toDouble();

                for (final point in corners) {
                  xMin = xMin < point.x ? xMin : point.x.toDouble();
                  yMin = yMin < point.y ? yMin : point.y.toDouble();
                  xMax = xMax > point.x ? xMax : point.x.toDouble();
                  yMax = yMax > point.y ? yMax : point.y.toDouble();
                }

                final normalizedCoords = [
                  xMin / imageWidth,
                  yMin / imageHeight,
                  xMax / imageWidth,
                  yMax / imageHeight,
                ];

                textCoordinatesMap[text] = normalizedCoords;
                break; // Sai do loop após encontrar o texto
              }
            }
          }
          if (textCoordinatesMap.containsKey(text)) break; // Sai do loop de blocos se já encontrou
        }
      }

      final entryParts = textCoordinatesMap.entries
          .map((e) => '${e.key}-${e.value.join(",")}')
          .join(';');

      final newEntry = '$docTypeName:$entryParts';

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/docs_texts_map.txt';
      final file = File(filePath);

      List<String> existingLines = [];
      if (await file.exists()) {
        existingLines = await file.readAsLines();
      }

      bool found = false;
      final updatedLines = existingLines.map((line) {
        if (line.startsWith('$docTypeName:')) {
          found = true;
          return '$line|$entryParts';
        }
        return line;
      }).toList();

      if (!found && entryParts.isNotEmpty) {
        updatedLines.add(newEntry);
      }

      await file.writeAsString(updatedLines.join('\n'));
      print('Arquivo atualizado: $filePath');
    } catch (e) {
      print('Erro ao processar a imagem e salvar as coordenadas: $e');
    } finally {
      textRecognizer.close();
    }
  }
}