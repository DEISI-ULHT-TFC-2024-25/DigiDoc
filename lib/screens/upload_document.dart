import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as imge;
import 'package:path_provider/path_provider.dart';
import 'info_confirmation.dart';
import '../CatchDocument.dart';

class UploadDocumentScreen extends StatefulWidget {
  @override
  _UploadDocumentScreenState createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  File? _selectedImage; // Imagem exibida (pode ser original ou recortada)
  File? _originalImage; // Imagem original antes do recorte
  List<File> _uploadedDocuments = [];
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  bool _isCorrecting = false; // Estado de correção manual
  List<Offset> _corners = []; // Cantos ajustáveis do retângulo

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
        final catchDoc = CatchDocument(imageFile);

        // Inicializar e capturar qualquer erro
        await catchDoc.initialize();

        // Verificar a imagem original
        if (catchDoc.originalImage == null) {
          throw Exception('Imagem original não carregada');
        }
        print('Imagem original pronta: ${catchDoc.originalImage!.width}x${catchDoc.originalImage!.height}');

        // Tentar recortar o documento
        final imge.Image? croppedImage = await catchDoc.getCroppedDocument();

        if (croppedImage != null) {
          final tempDir = await getTemporaryDirectory();
          final tempPath = '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final croppedFile = File(tempPath)..writeAsBytesSync(imge.encodeJpg(croppedImage));

          setState(() {
            _originalImage = imageFile;
            _selectedImage = croppedFile;
            _corners = [];
            _isCorrecting = false;
            _isProcessing = false;
          });
          print('Imagem recortada salva: ${croppedFile.path}');
        } else {
          setState(() {
            _selectedImage = imageFile;
            _originalImage = imageFile;
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao recortar o documento')),
          );
        }
        catchDoc.dispose();
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao processar documento: $e')),
      );
      print('Erro capturado em _pickImage: $e');
    }
  }

  void _addDocument() {
    if (_selectedImage != null && (!_isCorrecting || _corners.isNotEmpty)) {
      setState(() {
        _uploadedDocuments.add(_selectedImage!);
        _selectedImage = null;
        _originalImage = null;
        _corners = [];
        _isCorrecting = false;
      });
    } else if (_isCorrecting && _corners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, corrija o recorte antes de adicionar')),
      );
    }
  }
  void _deleteImage(int index) {
    setState(() {
      _uploadedDocuments.removeAt(index);
    });
  }

  void _toggleCorrection() {
    setState(() {
      if (_isCorrecting) {
        // Volta para a imagem recortada ao sair do modo de correção sem aplicar
        _selectedImage = _uploadedDocuments.isNotEmpty ? _uploadedDocuments.last : _selectedImage;
        _isCorrecting = false;
      } else if (_originalImage != null) {
        // Entra no modo de correção com a imagem original
        _selectedImage = _originalImage;
        _isCorrecting = true;
        _initializeDefaultCorners();
      }
    });
  }

  void _initializeDefaultCorners() {
    if (_selectedImage != null) {
      final size = MediaQuery.of(context).size;
      final imageWidth = size.width * 0.8;
      final imageHeight = imageWidth * 0.5;
      final centerX = size.width / 2;
      final centerY = size.height / 3;

      _corners = [
        Offset(centerX - imageWidth / 2, centerY - imageHeight / 2), // Top-left
        Offset(centerX + imageWidth / 2, centerY - imageHeight / 2), // Top-right
        Offset(centerX + imageWidth / 2, centerY + imageHeight / 2), // Bottom-right
        Offset(centerX - imageWidth / 2, centerY + imageHeight / 2), // Bottom-left
      ];
    }
  }

  Future<void> _applyManualCrop() async {
    if (_corners.length == 4 && _originalImage != null) {
      setState(() => _isProcessing = true);
      final catchDoc = CatchDocument(_originalImage!);
      await catchDoc.initialize();

      // Converter os cantos para a escala da imagem original
      final imageBytes = await _originalImage!.readAsBytes();
      final originalImage = imge.decodeImage(imageBytes)!;
      final scaleX = originalImage.width / MediaQuery.of(context).size.width;
      final scaleY = originalImage.height / (MediaQuery.of(context).size.height * 0.5);

      final scaledCorners = _corners
          .map((corner) => [
        (corner.dx * scaleX).round(),
        (corner.dy * scaleY).round(),
      ])
          .toList();

      final croppedImage = await catchDoc.cropWithCustomCorners(scaledCorners);

      if (croppedImage != null) {
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/corrected_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final correctedFile = File(tempPath)..writeAsBytesSync(imge.encodeJpg(croppedImage));

        setState(() {
          _selectedImage = correctedFile;
          _isCorrecting = false;
          _isProcessing = false;
        });
      } else {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao aplicar o recorte manual')),
        );
      }
      catchDoc.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Carregar Documento', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              child: _isProcessing
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedImage == null
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate, size: 80, color: Colors.grey),
                    const SizedBox(height: 20),
                    Text(
                      _uploadedDocuments.isEmpty ? 'Nenhum documento selecionado' : "",
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : InteractiveViewer(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.file(_selectedImage!),
                    if (_isCorrecting && _corners.isNotEmpty)
                      CustomPaint(
                        painter: RectanglePainter(_corners),
                        child: GestureDetector(
                          onPanUpdate: (details) => _updateCornerPosition(details),
                        ),
                      ),
                  ],
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
                            _uploadedDocuments[index],
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
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 20),
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
                      icon: Icon(
                        _isCorrecting ? Icons.check : Icons.change_circle,
                        color: _selectedImage == null ? Colors.grey : Colors.white,
                        size: 50,
                      ),
                      onPressed: _selectedImage == null
                          ? null
                          : _isCorrecting
                          ? _applyManualCrop
                          : _toggleCorrection,
                    ),
                    Text(
                      _isCorrecting ? "Confirmar" : _originalImage == null ? "Repetir" : "Corrigir",
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedImage == null ? Colors.grey : Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 30),
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        _selectedImage == null ? Icons.file_upload_outlined : Icons.add_photo_alternate,
                        color: Colors.white,
                        size: 50,
                      ),
                      onPressed: _selectedImage == null ? _pickImage : _addDocument,
                    ),
                    Text(
                      _selectedImage == null ? "Carregar" : "Adicionar",
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedImage == null ? Colors.grey : Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 30),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.white, size: 50),
                      onPressed: _uploadedDocuments.isNotEmpty && _selectedImage == null
                          ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InfoConfirmationScreen(
                              imagesList: _uploadedDocuments.map((file) => XFile(file.path)).toList(),
                            ),
                          ),
                        );
                      }
                          : null,
                    ),
                    const Text("Pronto", style: TextStyle(fontSize: 14, color: Colors.white)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateCornerPosition(DragUpdateDetails details) {
    setState(() {
      final position = details.localPosition;
      final closestCornerIndex = _corners.indexOf(_corners.reduce((a, b) =>
      (a - position).distance < (b - position).distance ? a : b));
      _corners[closestCornerIndex] = position;
    });
  }
}

// Widget para desenhar o retângulo ajustável
class RectanglePainter extends CustomPainter {
  final List<Offset> corners;

  RectanglePainter(this.corners);

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;

    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    canvas.drawPath(path, paint);

    final circlePaint = Paint()..color = Colors.red;
    for (var corner in corners) {
      canvas.drawCircle(corner, 10, circlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}