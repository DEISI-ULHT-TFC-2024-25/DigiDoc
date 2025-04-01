import 'dart:io';
import 'package:digidoc/ExtractedTextBox.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imge;
import 'package:path_provider/path_provider.dart';
import 'DataBaseHelper.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:math' as math;

Color _mainSolidDarkerColor = Color.fromARGB(255, 26, 30, 59);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Mensagem recebida em segundo plano: ${message.notification?.title}");
}

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
        backgroundColor:_mainSolidDarkerColor,
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

  Widget dossiersScreen() { //TODO
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
    loadDossiers();
  }

  void loadDossiers() async {
    List<Map<String, dynamic>> loadedDossiers = await DataBaseHelper().getDossiers();
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
                    child: Icon(Icons.folder, size: 40, color: _mainSolidDarkerColor),
                  ),
                  SizedBox(height: 5),
                  Text(dossiers[index]['name'],
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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

  const DossierScreen({Key? key, required this.dossierId, required this.dossierName}) : super(key: key);

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
                style: TextStyle(color: _mainSolidDarkerColor, fontSize: 12),
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
                child: Icon(Icons.photo, color: Colors.white,),
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
                style: TextStyle(color: _mainSolidDarkerColor, fontSize: 12),
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
                child: Icon(Icons.camera_alt, color: Colors.white,),
                backgroundColor:_mainSolidDarkerColor,
                heroTag: null,
              ),
            ],
          ),
          SizedBox(height: 20),
          FloatingActionButton(
            onPressed: _toggleExpand,
            child: Icon(Icons.close, color: Colors.white),
            backgroundColor:_mainSolidDarkerColor,
          ),
        ],
      )
          :
      Column(
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
  File? _image;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Carregar Documento')),
      body: Center(
        child: _image == null
            ? Text('Nenhuma imagem selecionada.')
            : Image.file(_image!),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => {},
        child: Icon(Icons.photo, color: Colors.white,),
        backgroundColor: _mainSolidDarkerColor,
      ),
    );
  }
}

class PickDocumentPhotoScreen extends StatefulWidget {
  @override
  _PickDocumentPhotoScreenState createState() => _PickDocumentPhotoScreenState();
}
class _PickDocumentPhotoScreenState extends State<PickDocumentPhotoScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  List<XFile> _capturedImages = [];
  bool _isCameraInitialized = false;
  XFile? _imgJustCaptured;
  File? _imgJustProcessed;

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

  void drawDiagonalLine(imge.Image image, int startX, int startY, double angle, int lineSize) {
    imge.fill(image, color: imge.ColorRgb8(255, 255, 255));

    double radian = angle * math.pi / 180;
    double cosAngle = math.cos(radian);
    double sinAngle = math.sin(radian);

    int width = image.width;
    int height = image.height;

    int xEnd = startX + (lineSize * cosAngle).toInt();
    int yEnd = startY - (lineSize * sinAngle).toInt();

    List<int> adjustedEnd = _clipToBounds(startX, startY, xEnd, yEnd, width, height);

    imge.drawLine(
      image,
      x1: startX,
      y1: startY,
      x2: adjustedEnd[0],
      y2: adjustedEnd[1],
      color: imge.ColorRgb8(255, 0, 0),
    );
  }

  List<int> _clipToBounds(int xStart, int yStart, int xEnd, int yEnd, int width, int height) {
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

      for(int y=0; y<image.height; y++){
        for(int x=0; x<image.width; x++){

        }
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
        //File imageFile = File(image.path);
        //File processedImage = await detectDocumentCorners(imageFile);
        if (mounted) {
          setState(() {
            _imgJustCaptured = image;
            //_imgJustProcessed = processedImage;
          });
        }
      } catch (e) {
        print("Erro ao capturar ou processar a imagem: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro ao processar a imagem. Tente novamente.")),
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
        title: Text("Tirar Foto do Documento", style: TextStyle(color: Colors.white)),
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
                    Positioned.fill(
                      child: Image.file(
                        File(_imgJustCaptured!.path),
                        fit: BoxFit.cover,
                      ),
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
                                  child: Icon(Icons.close, color: Colors.white, size: 20),
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
                          icon: Icon(Icons.change_circle, color: _imgJustCaptured == null ? Colors.grey : Colors.white, size: 50),
                          onPressed: _imgJustCaptured == null ? null : _retryCapture,
                        ),
                        Text("Repetir", style: TextStyle(fontSize: 14, color: _imgJustCaptured == null ? Colors.grey : Colors.white)),
                      ],
                    ),
                    SizedBox(width: 20),
                    IconButton(
                      icon: Icon(
                        _imgJustCaptured == null ? Icons.circle : Icons.add_circle,
                        color: Colors.white,
                        size: 75,
                      ),
                      onPressed: _imgJustCaptured == null ? _captureImage : _addImage,
                    ),
                    SizedBox(width: 20),
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(Icons.check_circle, color: _capturedImages.isNotEmpty ? Colors.white : Colors.grey, size: 50),
                          onPressed: _capturedImages.isNotEmpty
                              ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InfoConfirmationScreen(
                                  capturedImages: _capturedImages,
                                ),
                              ),
                            );
                          }
                              : null,
                        ),
                        Text("Pronto", style: TextStyle(fontSize: 14, color: _capturedImages.isNotEmpty ? Colors.white : Colors.grey)),
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
  final List<XFile> capturedImages;

  InfoConfirmationScreen({required this.capturedImages});

  @override
  _InfoConfirmationScreenState createState() => _InfoConfirmationScreenState();
}
class _InfoConfirmationScreenState extends State<InfoConfirmationScreen> {
  List<String> _extractedTextsList = [];
  List<String> _extractedAlertsList = [];

  @override
  void initState() {
    super.initState();
    _processImages();
  }
  int parseTwoDigitYear(String twoDigits) {
    final currentYear = DateTime.now().year;
    final century = (currentYear ~/ 100) * 100; // Século atual (ex: 2000)
    return century + int.parse(twoDigits);
  }

  Future<void> _processImages() async {
    for (var image in widget.capturedImages) {
      ExtractedTextBox etb = ExtractedTextBox(image.path);
      await etb.extractText();

      String extractedText = etb.text;
      List<DateTime>? futuresDate = extractFutureDate(extractedText);
      String extractedAlert = "";
      if(futuresDate!=null) {
        for (DateTime dt in futuresDate) {
          extractedAlert += "${dt.day}/${dt.month}/${dt.year}\n";
        }
      } else{
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
    for (int i = 1; i<patterns.length; i++){
      regex = RegExp(patterns[i]);
      matches = regex.allMatches(text);

      DateTime? validDate;
      int day, month, year = 0;
      for (var match in matches) {
        if(match.groupCount == 2){
          day = 1;
          month = int.parse(match.group(1)!);
          final anoRaw = match.group(2)!;
          year = anoRaw.length == 2 ? parseTwoDigitYear(anoRaw) : int.parse(anoRaw);
        } else {
          day = int.parse(match.group(1)!);
          month = int.parse(match.group(2)!);
          final anoRaw = match.group(2)!;
          year = anoRaw.length == 2 ? parseTwoDigitYear(anoRaw) : int.parse(anoRaw);
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
      "Cartão de Cidadão": ["citzen", "card", "cartao", "cidadao", "identity", "prt"],
      "Título de Residência": ["titulo", "residencia", "prt", "resid", "autoriz", "residence", "permit"],
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Confirmação das Imagens Processadas"),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Exibir todas as imagens capturadas
                for (int i = 0; i < widget.capturedImages.length; i++) ...[
                  Image.file(
                    File(widget.capturedImages[i].path),
                    fit: BoxFit.cover,
                    height: 200, // Ajuste conforme necessário
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        "Tipo de documento",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        guessDocType(_extractedTextsList),
                        style: TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Text(
                        "Texto extraído (Imagem ${i + 1})",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          _extractedTextsList.length > i
                              ? _extractedTextsList[i]
                              : "Processando...",
                          style: TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        "Alerta extraído (Imagem ${i + 1})",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          _extractedAlertsList.length > i
                              ? _extractedAlertsList[i]
                              : "Processando...",
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
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
