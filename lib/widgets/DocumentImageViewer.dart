import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imge;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../services/CatchDocument.dart';
import '../services/CurrentStateProcessing.dart';

class DocumentImageViewer extends StatefulWidget {
  final File? imageFile;
  final VoidCallback? onAdd;
  final Function(File)? onImageProcessed;
  final VoidCallback? onStartCorrection;
  final VoidCallback? onClose;

  const DocumentImageViewer({
    Key? key,
    this.imageFile,
    this.onStartCorrection,
    this.onAdd,
    this.onImageProcessed,
    this.onClose,
  }) : super(key: key);

  @override
  DocumentImageViewerState createState() => DocumentImageViewerState();
}

class DocumentImageViewerState extends State<DocumentImageViewer> {
  File? _selectedImage;
  File? _originalImage;
  List<Offset> _corners = [];

  @override
  void initState() {
    super.initState();
    if (widget.imageFile != null) {
      _processImage(widget.imageFile!);
    }
  }

  void startCorrection() {
    final state = Provider.of<CurrentStateProcessing>(context, listen: false);
    if (_originalImage != null && !state.isCorrecting) {
      setState(() {
        _selectedImage = _originalImage;
        _corners.clear();
        _initializeDefaultCorners();
      });
      state.setCorrecting(true);
      state.setInternalProcessing(false);
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
    final state = Provider.of<CurrentStateProcessing>(context, listen: false);
    state.setInternalProcessing(true);

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
          _corners.clear();
        });
        state.setCorrecting(false);
        state.setInternalProcessing(false);
        if (widget.onImageProcessed != null) {
          widget.onImageProcessed!(croppedFile);
        }
        print('Imagem recortada salva: ${croppedFile.path}');
      } else {
        setState(() {
          _selectedImage = imageFile;
          _originalImage = imageFile;
        });
        state.setInternalProcessing(false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao recortar o documento')),
        );
      }
      catchDoc.dispose();
    } catch (e) {
      setState(() {
        _selectedImage = imageFile;
        _originalImage = imageFile;
      });
      state.setInternalProcessing(false);
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
        Offset(centerX - imageWidth / 2, centerY - imageHeight / 2),
        Offset(centerX + imageWidth / 2, centerY - imageHeight / 2),
        Offset(centerX + imageWidth / 2, centerY + imageHeight / 2),
        Offset(centerX - imageWidth / 2, centerY + imageHeight / 2),
      ];
    }
  }

  Future<void> _applyManualCrop() async {
    final state = Provider.of<CurrentStateProcessing>(context, listen: false);
    if (_corners.length == 4 && _originalImage != null) {
      state.setInternalProcessing(true);

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
        });
        state.setCorrecting(false);
        state.setInternalProcessing(false);
        if (widget.onImageProcessed != null) {
          widget.onImageProcessed!(correctedFile);
        }
      } else {
        state.setInternalProcessing(false);
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

  void _closeImage() {
    final state = Provider.of<CurrentStateProcessing>(context, listen: false);
    setState(() {
      _selectedImage = null;
      _originalImage = null;
      _corners.clear();
    });
    state.setCorrecting(false);
    state.setInternalProcessing(false);
    if (widget.onClose != null) {
      widget.onClose!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<CurrentStateProcessing>(context);

    if (state.isProcessing || state.internalProcessing) {
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
          if (state.isCorrecting && _corners.isNotEmpty)
            CustomPaint(
              painter: RectanglePainter(_corners),
              child: GestureDetector(
                onPanUpdate: _updateCornerPosition,
              ),
            ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              onPressed: _closeImage,
              icon: const Icon(Icons.close, size: 20, color: Colors.white),
            ),
          ),
          if (state.isCorrecting)
            Positioned(
              bottom: 10,
              child: ElevatedButton(
                onPressed: _applyManualCrop,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                child: const Text('Confirmar', style: TextStyle(color: Colors.black)),
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