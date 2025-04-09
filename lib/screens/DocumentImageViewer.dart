import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imge;
import 'package:path_provider/path_provider.dart';
import '../CatchDocument.dart';

class DocumentImageViewer extends StatefulWidget {
  final File? imageFile;
  final bool isProcessing;
  final VoidCallback? onAdd;
  final Function(File)? onImageProcessed;
  final VoidCallback? onStartCorrection;

  const DocumentImageViewer({
    Key? key,
    this.imageFile,
    this.isProcessing = false,
    this.onStartCorrection,
    this.onAdd,
    this.onImageProcessed,
  }) : super(key: key);

  @override
  DocumentImageViewerState createState() => DocumentImageViewerState();
}

class DocumentImageViewerState extends State<DocumentImageViewer> {
  File? _selectedImage;
  File? _originalImage;
  bool _isCorrecting = false;
  List<Offset> _corners = [];
  bool _internalProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.imageFile != null) {
      _processImage(widget.imageFile!);
    }
  }
  void startCorrection() {
    if (_originalImage != null && !_isCorrecting) {
      setState(() {
        _selectedImage = _originalImage;
        _isCorrecting = true;
        _initializeDefaultCorners();
      });
      if (widget.onStartCorrection != null) {
        widget.onStartCorrection!();
      }
    }
  }

  @override
  void didUpdateWidget(DocumentImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageFile != oldWidget.imageFile && widget.imageFile != null) {
      _processImage(widget.imageFile!);
    }
  }

  Future<void> _processImage(File imageFile) async {
    setState(() => _internalProcessing = true);

    try {
      final catchDoc = CatchDocument(imageFile);
      await catchDoc.initialize();

      if (catchDoc.originalImage == null) {
        throw Exception('Imagem original não carregada');
      }
      print('Imagem original pronta: ${catchDoc.originalImage!.width}x${catchDoc.originalImage!.height}');

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
          _internalProcessing = false;
        });
        if (widget.onImageProcessed != null) {
          widget.onImageProcessed!(croppedFile);
        }
        print('Imagem recortada salva: ${croppedFile.path}');
      } else {
        setState(() {
          _selectedImage = imageFile;
          _originalImage = imageFile;
          _internalProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao recortar o documento')),
        );
      }
      catchDoc.dispose();
    } catch (e) {
      setState(() {
        _selectedImage = imageFile;
        _originalImage = imageFile;
        _internalProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao processar documento: $e')),
      );
      print('Erro ao processar imagem: $e');
    }
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
      setState(() => _internalProcessing = true);

      final catchDoc = CatchDocument(_originalImage!);
      await catchDoc.initialize();

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
          _internalProcessing = false;
        });
        if (widget.onImageProcessed != null) {
          widget.onImageProcessed!(correctedFile);
        }
      } else {
        setState(() => _internalProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao aplicar o recorte manual')),
        );
      }
      catchDoc.dispose();
    }
  }

  void _updateCornerPosition(DragUpdateDetails details) {
    setState(() {
      final position = details.localPosition;
      final closestCornerIndex = _corners.indexOf(_corners.reduce((a, b) =>
      (a - position).distance < (b - position).distance ? a : b));
      _corners[closestCornerIndex] = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isProcessing || _internalProcessing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedImage == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add_photo_alternate, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'Nenhum documento selecionado',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return InteractiveViewer(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.file(_selectedImage!),
          if (_isCorrecting && _corners.isNotEmpty)
            CustomPaint(
              painter: RectanglePainter(_corners),
              child: GestureDetector(
                onPanUpdate: _updateCornerPosition,
              ),
            ),
          if (_isCorrecting)
            Positioned(
              bottom: 10,
              child: ElevatedButton(
                onPressed: _applyManualCrop,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }


}

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