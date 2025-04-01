import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DocumentDetectorScreen(),
    );
  }
}

class DocumentDetectorScreen extends StatefulWidget {
  @override
  _DocumentDetectorScreenState createState() => _DocumentDetectorScreenState();
}

class _DocumentDetectorScreenState extends State<DocumentDetectorScreen> {
  List<Offset> _corners = [];

  @override
  void initState() {
    super.initState();
    _loadAndDetectDocument();
  }

  Future<void> _loadAndDetectDocument() async {
    // Carregar a imagem dos assets
    final byteData = await rootBundle.load('assets/ff.jpg');
    final imageBytes = byteData.buffer.asUint8List();

    // Processar a imagem para detectar os cantos
    final corners = await detectDocumentCorners(imageBytes);
    setState(() {
      _corners = corners;
    });
  }

  Future<List<Offset>> detectDocumentCorners(Uint8List imageBytes) async {
    // Decodificar a imagem
    img.Image? image = img.decodeImage(imageBytes);

    if (image == null) {
      print("Erro: Não foi possível decodificar a imagem.");
      return [];
    }

    // Converter para escala de cinza
    img.Image grayImage = img.grayscale(image);

    // Aplicar filtro de bordas (Sobel)
    img.Image edges = img.sobel(grayImage);

    // Simulação de detecção de contornos
    final width = image.width.toDouble();
    final height = image.height.toDouble();

    // Cantos simulados como porcentagem da imagem
    final corners = [
      Offset(0.1 * width, 0.1 * height), // Superior esquerdo
      Offset(0.9 * width, 0.1 * height), // Superior direito
      Offset(0.9 * width, 0.9 * height), // Inferior direito
      Offset(0.1 * width, 0.9 * height), // Inferior esquerdo
    ];

    return corners;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Detecção de Documento")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Coordenadas dos cantos detectados:"),
            if (_corners.isNotEmpty)
              Column(
                children: _corners
                    .map((corner) => Text(corner.toString()))
                    .toList(),
              )
            else
              Text("Processando ou nenhum canto detectado..."),
          ],
        ),
      ),
    );
  }
}