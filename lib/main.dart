import 'dart:io';
import 'dart:typed_data';
import 'package:digidoc/DocumentScanner.dart';
import 'package:digidoc/ExtractedTextBox.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as imge;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'DataBaseHelper.dart';
import 'package:camera/camera.dart';
import 'dart:math' as math;
import 'DocDetector.dart';
import 'TextFileSaver.dart';

Color _mainSolidDarkerColor = Color.fromARGB(255, 26, 30, 59);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DigiDoc',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _mainSolidDarkerColor),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Confirmação de dados'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

//____________

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 1;
  String imgPath = '';

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      Center(child: Text("Definições", style: TextStyle(fontSize: 20))),
      dossiersScreen(),
      Center(child: Text("Alertas", style: TextStyle(fontSize: 20))),
    ];
    final List<String> _titles = [
      "Definições",
      "Os meus dossiers",
      "Alertas",
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _mainSolidDarkerColor,
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Definições",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_shared),
            label: "Dossiers",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: "Alertas",
          ),
        ],
      ),
    );
  }

  Widget dossiersScreen() {
    return DossiersScreen();
  }
}

class DossiersScreen extends StatefulWidget {
  @override
  _DossiersScreenState createState() => _DossiersScreenState();
}

class _DossiersScreenState extends State<DossiersScreen> {
  TextEditingController dossierController = TextEditingController();
  List<Map<String, dynamic>> dossiers = [];

  @override
  void initState() {
    super.initState();
    saveData();
    loadDossiers();
  }
  Future<void> saveData() async{
    await TextFileSaver.save("TR-PT:prt-0.04090,0.00000,0.14315,0.12821;nomes-0.47648,0.20833,0.53783,0.22917;permit-0.61554,0.49840,0.67894,0.55288;titulo-0.46524,0.49840,0.53170,0.55288;residence-0.39366,0.92628,0.50204,0.95353;apelidos-0.38855,0.20673,0.46830,0.22917;resid-0.46626,0.01763,0.68303,0.08013;autoriz-0.39162,0.68750,0.50613,0.72596");
  }

  void loadDossiers() async {
    List<Map<String, dynamic>> loadedDossiers =
        await DataBaseHelper().getDossiers();
    setState(() {
      dossiers = loadedDossiers;
    });
  }

  void addDossier(BuildContext context) async {
    String dossierName = dossierController.text;
    if (dossierName.isNotEmpty) {
      await DataBaseHelper().createDossier(dossierName);
      dossierController.clear();
      loadDossiers();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Lista de Dossiers")),
      body: dossiers.isEmpty
          ? Center(child: Text("Nenhum dossier disponível."))
          : Padding(
              padding: EdgeInsets.all(10),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemCount: dossiers.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      final dossier = dossiers[index];
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DossierScreen(
                            dossierId: dossier['id'] ?? 0,
                            dossierName: dossier['name'] ?? "Sem Nome",
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.folder,
                              size: 40, color: _mainSolidDarkerColor),
                        ),
                        SizedBox(height: 5),
                        Text(dossiers[index]['name'],
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text("Novo Dossier"),
                content: TextField(
                  controller: dossierController,
                  autofocus: true,
                  decoration: InputDecoration(hintText: 'Nome do Dossier'),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      dossierController.clear();
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancelar"),
                  ),
                  TextButton(
                    onPressed: () => addDossier(context),
                    child: Text("Criar"),
                  ),
                ],
              );
            },
          );
        },
        backgroundColor: _mainSolidDarkerColor,
        child: Icon(Icons.create_new_folder, color: Colors.white),
      ),
    );
  }
}

class DossierScreen extends StatefulWidget {
  final int dossierId;
  final String dossierName;

  const DossierScreen(
      {Key? key, required this.dossierId, required this.dossierName})
      : super(key: key);

  @override
  _DossierScreenState createState() => _DossierScreenState();
}

class _DossierScreenState extends State<DossierScreen> {
  List<Map<String, dynamic>> documents = [];
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    loadDocuments();
  }

  Future<void> loadDocuments() async {
    List<Map<String, dynamic>> docs =
        await DataBaseHelper.instance.getDocuments(widget.dossierId);
    setState(() {
      documents = docs;
    });
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.dossierName,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: _mainSolidDarkerColor,
        iconTheme: IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Documentos Salvos", style: TextStyle(fontSize: 20)),
            Expanded(
              child: documents.isEmpty
                  ? Center(child: Text("Nenhum documento adicionado."))
                  : GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: documents.length,
                      itemBuilder: (context, index) {
                        return Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.insert_drive_file,
                                  size: 40, color: Colors.blueGrey),
                            ),
                            SizedBox(height: 5),
                            Text(documents[index]['name'],
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isExpanded
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Galeria",
                      style:
                          TextStyle(color: _mainSolidDarkerColor, fontSize: 12),
                    ),
                    FloatingActionButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UploadDocumentScreen(),
                          ),
                        ).then((_) => loadDocuments());
                      },
                      child: Icon(
                        Icons.photo,
                        color: Colors.white,
                      ),
                      backgroundColor: _mainSolidDarkerColor,
                      heroTag: null,
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Foto",
                      style:
                          TextStyle(color: _mainSolidDarkerColor, fontSize: 12),
                    ),
                    FloatingActionButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PickDocumentPhotoScreen(),
                          ),
                        ).then((_) => loadDocuments());
                      },
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                      ),
                      backgroundColor: _mainSolidDarkerColor,
                      heroTag: null,
                    ),
                  ],
                ),
                SizedBox(height: 20),
                FloatingActionButton(
                  onPressed: _toggleExpand,
                  child: Icon(Icons.close, color: Colors.white),
                  backgroundColor: _mainSolidDarkerColor,
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Adicionar\nDocumento",
                  style: TextStyle(color: _mainSolidDarkerColor, fontSize: 12),
                ),
                SizedBox(height: 4),
                FloatingActionButton(
                  onPressed: _toggleExpand,
                  backgroundColor: _mainSolidDarkerColor,
                  child: Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
    );
  }
}

class UploadDocumentScreen extends StatefulWidget {
  @override
  _UploadDocumentScreenState createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  File? _selectedImage;
  List<File> _uploadedDocuments = [];
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;


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

        // final processedImage = await _processDocument(imageFile);

        /*await processDocumentAndSaveTextMap(
            docTypeName: "TR-PT",
            imageFile: image,
            textsToFind: ["titulo", "residencia", "prt", "autoriz"]);
*/

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

      // Usa path_provider para obter um diretório onde possas escrever
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

class PickDocumentPhotoScreen extends StatefulWidget {
  @override
  _PickDocumentPhotoScreenState createState() =>
      _PickDocumentPhotoScreenState();
}

class _PickDocumentPhotoScreenState extends State<PickDocumentPhotoScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  List<XFile> _capturedImages = [];
  bool _isCameraInitialized = false;
  XFile? _imgJustCaptured;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      _cameraController = CameraController(
        _cameras[0],
        ResolutionPreset.max,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  void drawDiagonalLine(
      imge.Image image, int startX, int startY, double angle, int lineSize) {
    imge.fill(image, color: imge.ColorRgb8(255, 255, 255));

    double radian = angle * math.pi / 180;
    double cosAngle = math.cos(radian);
    double sinAngle = math.sin(radian);

    int width = image.width;
    int height = image.height;

    int xEnd = startX + (lineSize * cosAngle).toInt();
    int yEnd = startY - (lineSize * sinAngle).toInt();

    List<int> adjustedEnd =
        _clipToBounds(startX, startY, xEnd, yEnd, width, height);

    imge.drawLine(
      image,
      x1: startX,
      y1: startY,
      x2: adjustedEnd[0],
      y2: adjustedEnd[1],
      color: imge.ColorRgb8(255, 0, 0),
    );
  }

  List<int> _clipToBounds(
      int xStart, int yStart, int xEnd, int yEnd, int width, int height) {
    if (xEnd >= 0 && xEnd < width && yEnd >= 0 && yEnd < height) {
      return [xEnd, yEnd];
    }

    double dx = (xEnd - xStart).toDouble();
    double dy = (yEnd - yStart).toDouble();

    double t;
    if (dx > 0) {
      t = (width - 1 - xStart) / dx;
    } else if (dx < 0) {
      t = -xStart / dx;
    } else {
      t = double.infinity;
    }

    int x = dx != 0 ? (xStart + t * dx).toInt() : xStart;
    int y = (yStart + t * dy).toInt();

    if (y >= 0 && y < height) {
      return [x, y];
    }

    if (dy > 0) {
      t = (height - 1 - yStart) / dy;
    } else if (dy < 0) {
      t = -yStart / dy;
    } else {
      t = double.infinity;
    }

    x = (xStart + t * dx).toInt();
    y = dy != 0 ? (yStart + t * dy).toInt() : yStart;

    x = math.max(0, math.min(width - 1, x));
    y = math.max(0, math.min(height - 1, y));

    return [x, y];
  }

  Future<File> detectDocumentCorners(File imageFile) async {
    try {
      imge.Image? image = imge.decodeImage(await imageFile.readAsBytes());
      if (image == null) throw Exception("Falha ao decodificar a imagem");

      image = imge.copyResize(image, width: 800);

      image = imge.grayscale(image);
      image = imge.gaussianBlur(image, radius: 5);
      image = imge.sobel(image);

      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {}
      }

      List<int> encodedImage = imge.encodePng(image);

      String tempPath = (await getTemporaryDirectory()).path;
      File processedFile = File('$tempPath/processed.png');
      await processedFile.writeAsBytes(encodedImage);

      return processedFile;
    } catch (e) {
      print("Erro ao detectar cantos do documento: $e");
      rethrow;
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        XFile image = await _cameraController!.takePicture();
        /*final imageBytes = await image.readAsBytes();
        imge.Image? capturedImage = imge.decodeImage(imageBytes);
        if (capturedImage == null) {
          throw Exception("Não foi possível decodificar a imagem capturada.");
        }

        DocDetector detector = DocDetector(image: capturedImage);
        detector.catchDocument(
          image: capturedImage,
          width: capturedImage.width,
          height: capturedImage.height,
        );

        imge.Image? processedImage = detector.imageResult;
        if (processedImage == null) {
          throw Exception("Falha ao processar a imagem com DocDetector.");
        }

        File processedImageFile = await File(image.path)
            .writeAsBytes(imge.encodeJpg(processedImage));
        */
        if (mounted) {
          setState(() {
            _imgJustCaptured = image; //XFile(processedImageFile.path)
          });
        }
      } catch (e) {
        print("Erro ao capturar ou processar a imagem: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erro ao processar a imagem: $e. Tente novamente."),
            ),
          );
        }
      }
    }
  }

  Future<void> _addImage() async {
    if (_imgJustCaptured != null) {
      setState(() {
        _capturedImages.add(_imgJustCaptured!);
        _imgJustCaptured = null;
      });
    }
  }

  Future<void> _retryCapture() async {
    setState(() {
      _imgJustCaptured = null;
    });
  }

  void _deleteImage(int index) {
    setState(() {
      _capturedImages.removeAt(index);
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Tirar Foto do Documento",
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isCameraInitialized
                ? AspectRatio(
                    aspectRatio: _cameraController!.value.aspectRatio,
                    child: Stack(
                      children: [
                        if (_imgJustCaptured != null)
                          Image.file(
                            File(_imgJustCaptured!.path),
                            fit: BoxFit.cover,
                          )
                        else
                          CameraPreview(_cameraController!),
                      ],
                    ),
                  )
                : Center(child: CircularProgressIndicator()),
          ),
          Container(
            padding: EdgeInsets.all(10),
            color: Colors.black,
            child: Column(
              children: [
                if (_capturedImages.isNotEmpty)
                  Container(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _capturedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(3.0),
                              child: Image.file(
                                File(_capturedImages[index].path),
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
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(Icons.change_circle,
                              color: _imgJustCaptured == null
                                  ? Colors.grey
                                  : Colors.white,
                              size: 50),
                          onPressed:
                              _imgJustCaptured == null ? null : _retryCapture,
                        ),
                        Text("Repetir",
                            style: TextStyle(
                                fontSize: 14,
                                color: _imgJustCaptured == null
                                    ? Colors.grey
                                    : Colors.white)),
                      ],
                    ),
                    SizedBox(width: 30),
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(
                            _imgJustCaptured == null
                                ? Icons.circle
                                : Icons.add_circle,
                            color: Colors.white,
                            size: 50,
                          ),
                          onPressed: _imgJustCaptured == null
                              ? _captureImage
                              : _addImage,
                        ),
                        Text(
                            _imgJustCaptured == null ? "Capturar" : "Adicionar",
                            style:
                                TextStyle(fontSize: 14, color: Colors.white)),
                      ],
                    ),
                    SizedBox(width: 30),
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(Icons.check_circle,
                              color: _capturedImages.isNotEmpty &&
                                      _imgJustCaptured == null
                                  ? Colors.white
                                  : Colors.grey,
                              size: 50),
                          onPressed: _capturedImages.isNotEmpty &&
                                  _imgJustCaptured == null
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          InfoConfirmationScreen(
                                        imagesList: _capturedImages,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                        Text("Pronto",
                            style: TextStyle(
                                fontSize: 14,
                                color: _capturedImages.isNotEmpty
                                    ? Colors.white
                                    : Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InfoConfirmationScreen extends StatefulWidget {
  final List<XFile> imagesList;

  InfoConfirmationScreen({required this.imagesList});

  @override
  _InfoConfirmationScreenState createState() => _InfoConfirmationScreenState();
}

class _InfoConfirmationScreenState extends State<InfoConfirmationScreen> {
  List<String> _extractedTextsList = [];
  List<String> _extractedAlertsList = [];
  String text = "carta";
  List<int>? coords = [];
  double? angle;
  late DocumentScanner ds;
  String inferredDocTypeName = 'Tipo nao detetado';

  Future<String> _inferDocTypeName(XFile x_file_img) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/docs_texts_map.txt';
    final file = File(filePath);

    List<String> existingLines = [];
    if (await file.exists()) {
      existingLines = await file.readAsLines();
    }

    final textRecognizer = TextRecognizer();
    final inputImage = InputImage.fromFilePath(x_file_img.path);
    final recognizedText = await textRecognizer.processImage(inputImage);

    final imageBytes = await x_file_img.readAsBytes();
    final image = imge.decodeImage(imageBytes)!;
    final imageWidth = image.width;
    final imageHeight = image.height;

    final docTypesScore = <String, double>{};

    // Processar as linhas do arquivo de mapeamento
    for (var line in existingLines) {
      String docTypeName = line.split(":")[0];
      List<String> wordsAndCoords = line.split(":")[1].split("|");
      for (String wc in wordsAndCoords) {
        List<String> types = wc.split(";");
        for (String type in types) {
          List<String> parts = type.split("-");
          String docText = parts[0];
          List<double> coords = parts[1].split(",").map(double.parse).toList();

          double xTopLeft = coords[0];
          double yTopLeft = coords[1];
          double xBottomRight = coords[2];
          double yBottomRight = coords[3];

          // Convertendo as coordenadas normalizadas para coordenadas absolutas na imagem
          double xTopLeftAbs = xTopLeft * imageWidth;
          double yTopLeftAbs = yTopLeft * imageHeight;
          double xBottomRightAbs = xBottomRight * imageWidth;
          double yBottomRightAbs = yBottomRight * imageHeight;

          // Verifica a interseção e calcula o score
          double score = _getTextIntersectionScore(
            recognizedText,
            docText,
            xTopLeftAbs,
            yTopLeftAbs,
            xBottomRightAbs,
            yBottomRightAbs,
          );

          if (score > 0) {
            print("Score para $docText em $docTypeName: $score");
            docTypesScore[docTypeName] = (docTypesScore[docTypeName] ?? 0) + score;
          }
        }
      }
    }

    String inferredDocText = 'Nome não detectado';
    double maxScore = 0;

    print("GANHEIIIIIIIII");
    if (docTypesScore.isEmpty) {
      print("EMPTY");
    }
    docTypesScore.forEach((key, value) {
      print("key: $key value: $value");
      if (value > maxScore) {
        maxScore = value;
        inferredDocText = key;
      }
    });

    return inferredDocText;
  }

  /// Calcula o score de interseção entre a área fornecida e os retângulos de texto da imagem,
  /// retornando um valor entre 0 e 1 baseado na correspondência de sequência de texto.
  double _getTextIntersectionScore(
      RecognizedText recognizedText,
      String paramText,
      double xTopLeftAbs,
      double yTopLeftAbs,
      double xBottomRightAbs,
      double yBottomRightAbs,
      )
  {
    // Retângulo da área fornecida como parâmetro
    final paramRect = math.Rectangle<double>(
      xTopLeftAbs,
      yTopLeftAbs,
      xBottomRightAbs - xTopLeftAbs,
      yBottomRightAbs - yTopLeftAbs,
    );

    double bestScore = 0;
    math.Rectangle<double>? bestRect;

    // Itera sobre os retângulos de texto reconhecidos
    for (var block in recognizedText.blocks) {
      for (var line in block.lines) {
        for (var element in line.elements) {
          if (element.boundingBox != null) {
            final boundingBox = element.boundingBox!;
            final textRect = math.Rectangle<double>(
              boundingBox.left,
              boundingBox.top,
              boundingBox.width,
              boundingBox.height,
            );

            // Verifica se há interseção
            if (paramRect.intersects(textRect)) {
              // Calcula a área de interseção
              final intersection = paramRect.intersection(textRect);
              if (intersection != null) {
                double intersectionArea = intersection.width * intersection.height;
                double textRectArea = textRect.width * textRect.height;
                double overlapRatio = intersectionArea / textRectArea;

                // Só considera retângulos com interseção significativa
                if (overlapRatio > 0) {
                  if (overlapRatio > bestScore || (overlapRatio == bestScore && textRectArea < (bestRect?.width ?? double.infinity) * (bestRect?.height ?? double.infinity))) {
                    bestScore = overlapRatio;
                    bestRect = textRect;

                    // Calcula o score de correspondência de texto
                    String recognizedTextLower = element.text.toLowerCase();
                    String paramTextLower = paramText.toLowerCase();

                    if (recognizedTextLower.contains(paramTextLower)) {
                      // Score 1 se o texto do parâmetro está completamente contido
                      bestScore = 1.0;
                    } else {
                      // Calcula a maior subsequência comum (LCS - Longest Common Subsequence)
                      int lcsLength = _longestCommonSubsequence(recognizedTextLower, paramTextLower);
                      bestScore = lcsLength / paramTextLower.length;
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    return bestScore;
  }

  /// Calcula o comprimento da maior subsequência comum (LCS) entre duas strings
  int _longestCommonSubsequence(String text1, String text2) {
    int m = text1.length;
    int n = text2.length;
    List<List<int>> dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (text1[i - 1] == text2[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1]);
        }
      }
    }

    return dp[m][n];
  }

  @override
  void initState() {
    super.initState();
    _processImages();
    _initScanner();
  }

  Future<void> _initScanner() async {
    XFile image = widget.imagesList[0];
    inferredDocTypeName = await _inferDocTypeName(image);
    ds = await DocumentScanner.create(File(image.path));
    coords = await ds.getTextAreaCoordinates();
    angle = await ds.getMostFreqAngle();
    setState(() {});
  }

  int parseTwoDigitYear(String twoDigits) {
    final currentYear = DateTime.now().year;
    final century = (currentYear ~/ 100) * 100;
    return century + int.parse(twoDigits);
  }

  Future<void> _processImages() async {
    for (var image in widget.imagesList) {
      ExtractedTextBox etb = ExtractedTextBox(image.path);
      await etb.extractText();

      String extractedText = etb.text;
      List<DateTime>? futuresDate = extractFutureDate(extractedText);
      String extractedAlert = "";
      if (futuresDate != null) {
        for (DateTime dt in futuresDate) {
          extractedAlert += "${dt.day}/${dt.month}/${dt.year}\n";
        }
      } else {
        extractedAlert = "Nenhuma data válida encontrada";
      }

      setState(() {
        _extractedTextsList.add(extractedText);
        _extractedAlertsList.add(extractedAlert);
      });
    }
  }

  List<DateTime>? extractFutureDate(String text) {
    List<String> patterns = [
      r'(\d{2})\s*(\d{2})\s*(\d{4})',
      r'(\d{2})\.(\d{2})\.(\d{4})',
      r'(\d{2})\-(\d{2})\-(\d{4})',
      r'(\d{2})\\(\d{2})\\(\d{4})',
      r'(\d{2})\/(\d{2})\/(\d{4})',
      r'(\d{2})\/(\d{2})\/(\d{4})',
      r'(\d{2})\s*(\d{2})\s*(\d{2})',
      r'(\d{2})\.(\d{2})\.(\d{2})',
      r'(\d{2})\-(\d{2})\-(\d{2})',
      r'(\d{2})\\(\d{2})\\(\d{2})',
      r'(\d{2})\/(\d{2})\/(\d{2})',
      r'(\d{2})\s*(\d{4})',
      r'(\d{2})\.(\d{4})',
      r'(\d{2})\-(\d{4})',
      r'(\d{2})\\(\d{4})',
      r'(\d{2})\s*(\d{2})',
      r'(\d{2})\.(\d{2})',
      r'(\d{2})\-(\d{2})',
      r'(\d{2})\\(\d{2})',
    ];
    DateTime hoje = DateTime.now();
    hoje = hoje.subtract(Duration(days: 7));
    DateTime limite = hoje.add(Duration(days: 36500));
    RegExp regex = RegExp(patterns[0]);
    Iterable<Match> matches = regex.allMatches(text);
    List<DateTime> dates = [];
    for (int i = 1; i < patterns.length; i++) {
      regex = RegExp(patterns[i]);
      matches = regex.allMatches(text);

      DateTime? validDate;
      int day, month, year = 0;
      for (var match in matches) {
        if (match.groupCount == 2) {
          day = 1;
          month = int.parse(match.group(1)!);
          final anoRaw = match.group(2)!;
          year = anoRaw.length == 2
              ? parseTwoDigitYear(anoRaw)
              : int.parse(anoRaw);
        } else {
          day = int.parse(match.group(1)!);
          month = int.parse(match.group(2)!);
          final anoRaw = match.group(2)!;
          year = anoRaw.length == 2
              ? parseTwoDigitYear(anoRaw)
              : int.parse(anoRaw);
        }
        try {
          DateTime date = DateTime(year, month, day);
          if (date.isAfter(hoje) && date.isBefore(limite)) {
            dates.add(date);
          }
        } catch (e) {
          continue;
        }
      }
    }

    return dates;
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

  String guessDocType(List<String> texts) {
    String combinedText = texts.map(_normalizeText).join(" ");

    Map<String, List<String>> documents = {
      "Cartão de Cidadão": [
        "citzen",
        "card",
        "cartao",
        "cidadao",
        "identity",
        "prt"
      ],
      "Título de Residência": [
        "titulo",
        "residencia",
        "prt",
        "resid",
        "autoriz",
        "residence",
        "permit"
      ],
      "Carta de Condução": ["carta", "conducao", "imt", "b1", "b"]
    };

    String bestMatch = "Documento não identificado";
    int bestScore = 0;

    for (var entry in documents.entries) {
      int score = 0;
      for (String keyword in entry.value) {
        if (combinedText.contains(keyword)) {
          score++;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestMatch = entry.key;
      }
    }

    return bestMatch;
  }

  Future<XFile?> rotateXFileImage(XFile xfile, double angleDegrees) async {
    try {
      final Uint8List bytes = await xfile.readAsBytes();
      final imge.Image? image = imge.decodeImage(bytes);
      if (image == null) return null;
      final rotated = imge.copyRotate(image, angle: angleDegrees);

      final Uint8List rotatedBytes =
          Uint8List.fromList(imge.encodeJpg(rotated));

      // Guarda a imagem num ficheiro temporário
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/rotated_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = await File(path).writeAsBytes(rotatedBytes);

      return XFile(file.path);
    } catch (e) {
      print('Erro ao rotacionar imagem: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Confirmação dos dados"),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                height: 300,
                color: Colors.black,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.imagesList.length, (index) {
                      return FutureBuilder<XFile?>(
                        future:
                            rotateXFileImage(widget.imagesList[index], -angle!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox(
                              height: 300,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          } else if (snapshot.hasError ||
                              snapshot.data == null) {
                            return const SizedBox(
                              height: 300,
                              child:
                                  Center(child: Text('Erro a carregar imagem')),
                            );
                          } else {
                            return Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Image.file(
                                File(snapshot.data!.path),
                                height: 300,
                                fit: BoxFit.cover,
                              ),
                            );
                          }
                        },
                      );
                    }),
                  ),
                ),
              ),
              SizedBox(height: 30),
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      "Tipo do documento",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    SizedBox(height: 10),
                    Text(
                      inferredDocTypeName,//guessDocType(_extractedTextsList),
                      style: TextStyle(fontSize: 12),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "$text : $coords",
                      style: TextStyle(fontSize: 12),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Angle : $angle",
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RectangleOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color.fromARGB(100, 0, 0, 0)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTRB(
      size.width * 0.05,
      size.height * 0.02,
      size.width * 0.95,
      size.height * 0.77,
    );

    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(20),
    );

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
