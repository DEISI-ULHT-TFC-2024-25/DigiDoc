import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as imge;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../DocDetector.dart';
import 'info_confirmation.dart';

class UploadDocumentScreen extends StatefulWidget {
  @override
  _UploadDocumentScreenState createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  File? _selectedImage;
  List<File> _uploadedDocuments = [];
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  Future<File> _processDocument(File imageFile) async {
    try {
      final imge.Image? image = imge.decodeImage(await imageFile.readAsBytes());
      if (image == null) throw Exception("Falha ao decodificar a imagem");

      final DocDetector detector = DocDetector(image: image);
      detector.catchDocument(
        image: image,
        width: image.width,
        height: image.height,
      );

      final imge.Image? processedImage = detector.imageResult;
      if (processedImage == null) throw Exception("Nenhum documento detectado");

      final String tempPath =
          '${(await getTemporaryDirectory()).path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      return await File(tempPath).writeAsBytes(imge.encodeJpg(processedImage));
    } catch (e) {
      print("Erro no processamento: $e");
      rethrow;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _isProcessing = true);

        final imageFile = File(image.path);

        //final processedImage = await _processDocument(imageFile);

        /*await processDocumentAndSaveTextMap(
            docTypeName: "TR-PT",
            imageFile: image,
            textsToFind: ["titulo", "nomes", "apelidos", "residencia", "residence", "prt", "autoriz", "permit", "resid"]);*/

        setState(() {
          _selectedImage = imageFile;
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao processar documento: ${e.toString()}'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _addDocument() {
    if (_selectedImage != null) {
      setState(() {
        _uploadedDocuments.add(_selectedImage!);
        _selectedImage = null;
      });
    }
  }

  void _deleteImage(int index) {
    setState(() {
      _uploadedDocuments.removeAt(index);
    });
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
  })
  async {
    final textRecognizer = TextRecognizer();
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognizedText = await textRecognizer.processImage(inputImage);

      final imageBytes = await imageFile.readAsBytes();
      final image = imge.decodeImage(imageBytes)!;
      final imageWidth = image.width;
      final imageHeight = image.height;

      final textCoordinatesMap = <String, List<double>>{};

      for (final text in textsToFind) {
        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
            String lineText = _normalizeText(line.text);
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
                break;
              }
            }
          }
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

      if (!found) {
        updatedLines.add(newEntry);
      }

      await file.writeAsString(updatedLines.join('\n'));
    } catch (e) {
      print('Erro ao processar a imagem e salvar as coordenadas: $e');
    } finally {
      textRecognizer.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Carregar Documento',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              child: _isProcessing
                  ? Center(child: CircularProgressIndicator())
                  : _selectedImage == null
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate,
                        size: 80, color: Colors.grey),
                    SizedBox(height: 20),
                    Text(
                      _uploadedDocuments.isEmpty
                          ? 'Nenhum documento selecionado'
                          : "",
                      style:
                      TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : InteractiveViewer(
                child: Center(
                  child: Image.file(_selectedImage!),
                ),
              ),
            ),
            if (_uploadedDocuments.isNotEmpty)
              Container(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _uploadedDocuments.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(3.0),
                          child: Image.file(
                            File(_uploadedDocuments[index].path),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => _deleteImage(index),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black,
                              ),
                              child: Icon(Icons.close,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    IconButton(
                      icon: Icon(Icons.change_circle,
                          color: _selectedImage == null
                              ? Colors.grey
                              : Colors.white,
                          size: 50),
                      onPressed: _selectedImage == null
                          ? null
                          : () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                    ),
                    Text("Repetir",
                        style: TextStyle(
                            fontSize: 14,
                            color: _selectedImage == null
                                ? Colors.grey
                                : Colors.white)),
                  ],
                ),
                SizedBox(width: 30),
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        _selectedImage == null
                            ? Icons.file_upload_outlined
                            : Icons.add_photo_alternate,
                        color: Colors.white,
                        size: 50,
                      ),
                      onPressed:
                      _selectedImage == null ? _pickImage : _addDocument,
                    ),
                    Text(_selectedImage == null ? "Carregar" : "Adicionar",
                        style: TextStyle(
                            fontSize: 14,
                            color: _selectedImage == null
                                ? Colors.grey
                                : Colors.white)),
                  ],
                ),
                SizedBox(width: 30),
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.check_circle,
                        color: _uploadedDocuments.isNotEmpty &&
                            _selectedImage == null
                            ? Colors.white
                            : Colors.grey,
                        size: 50,
                      ),
                      onPressed: _uploadedDocuments.isNotEmpty &&
                          _selectedImage == null
                          ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InfoConfirmationScreen(
                              imagesList: _uploadedDocuments
                                  .map((file) => XFile(file.path))
                                  .toList(),
                            ),
                          ),
                        );
                      }
                          : null,
                    ),
                    Text("Pronto",
                        style: TextStyle(
                            fontSize: 14,
                            color: _uploadedDocuments.isNotEmpty
                                ? Colors.white
                                : Colors.grey)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}