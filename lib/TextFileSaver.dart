import 'dart:io';
import 'package:path_provider/path_provider.dart';

class TextFileSaver {
  static Future<void> save(String content) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/docs_texts_map.txt';
      final file = File(filePath);
      await file.writeAsString(content, mode: FileMode.writeOnlyAppend);
      print('Texto guardado com sucesso em $filePath');
    } catch (e) {
      print('Erro ao guardar o ficheiro: $e');
    }
  }
}
