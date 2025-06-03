import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imge;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../constants/color_app.dart';
import '../services/text_based_document_image_processor.dart';
import '../services/current_state_processing.dart';

class DocumentImageViewer extends StatefulWidget {
  final File? imageFile;
  final VoidCallback? onAdd;
  final Function(File)? onImageProcessed;
  final VoidCallback? onStartCorrection;
  final VoidCallback? onClose;

  const DocumentImageViewer({
    Key? key,
    this.imageFile,
    this.onAdd,
    this.onImageProcessed,
    this.onStartCorrection,
    this.onClose,
  }) : super(key: key);

  @override
  DocumentImageViewerState createState() => DocumentImageViewerState();
}

class DocumentImageViewerState extends State<DocumentImageViewer> {
  File? _selectedImage;
  File? _originalImage;
  TextBasedDocumentImageProcessor? _catchDoc;
  File? _lastProcessedImage;
  final double _cornerDetectionRadius = 20.0;
  List<Offset> _corners = [Offset.zero, Offset.zero, Offset.zero, Offset.zero];
  int? _activeCornerIndex;
  bool _isDraggingPolygon = false;
  Offset? _dragStartPosition;
  Offset? _magnifierPosition;
  final double _magnifierRadius = 50.0;
  final double _magnifierZoom = 2.0;
  ui.Image? _cachedImage;

  @override
  void initState() {
    super.initState();
    if (widget.imageFile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processImage(widget.imageFile!);
      });
    }
  }

  @override
  void didUpdateWidget(DocumentImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageFile != oldWidget.imageFile &&
        widget.imageFile != null &&
        widget.imageFile != _lastProcessedImage &&
        !widget.imageFile!.path.contains('final_')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processImage(widget.imageFile!);
      });
    }
  }

  Future<void> _processImage(File imageFile) async {
    final state = Provider.of<CurrentStateProcessing>(context, listen: false);
    state.setInternalProcessing(true);

    try {
      _catchDoc = TextBasedDocumentImageProcessor(imageFile);
      await _catchDoc!.initialize();

      if (_catchDoc!.finalImage == null || _catchDoc!.documentCorners == null) {
        throw Exception('Imagem final ou cantos não carregados');
      }

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/final_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final finalImageFile = File(tempPath)..writeAsBytesSync(imge.encodeJpg(_catchDoc!.finalImage!));

      final bytes = finalImageFile.readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      setState(() {
        _originalImage = imageFile;
        _selectedImage = finalImageFile;
        _lastProcessedImage = imageFile;
        _cachedImage = frame.image;
      });
      state.setCorrecting(false);
      state.setInternalProcessing(false);

      widget.onImageProcessed?.call(finalImageFile);
    } catch (e) {
      setState(() {
        _selectedImage = null;
        _originalImage = null;
        _lastProcessedImage = null;
        _cachedImage = null;
      });
      state.setInternalProcessing(false);
      _catchDoc?.dispose();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao processar imagem: $e')),
      );
    }
  }

  Future<void> startCorrection() async {
    final state = Provider.of<CurrentStateProcessing>(context, listen: false);
    if (_originalImage == null || state.isCorrecting || _catchDoc == null) return;

    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height * 0.8;
    final imageWidth = _catchDoc!.originalImage!.width.toDouble();
    final imageHeight = _catchDoc!.originalImage!.height.toDouble();

    final aspectRatio = imageWidth / imageHeight;
    final displayWidth = aspectRatio > screenWidth / screenHeight ? screenWidth : screenHeight * aspectRatio;
    final displayHeight = aspectRatio > screenWidth / screenHeight ? screenWidth / aspectRatio : screenHeight;
    final offsetX = (screenWidth - displayWidth) / 2;
    final offsetY = (screenHeight - displayHeight) / 2;
    final scale = displayWidth / imageWidth;

    setState(() {
      _corners = _catchDoc!.documentCorners != null
          ? _catchDoc!.documentCorners!.map((corner) => Offset(corner[0] * scale + offsetX, corner[1] * scale + offsetY)).toList()
          : [
        Offset(offsetX, offsetY),
        Offset(offsetX + displayWidth, offsetY),
        Offset(offsetX + displayWidth, offsetY + displayHeight),
        Offset(offsetX, offsetY + displayHeight),
      ];
      _selectedImage = _originalImage;
      _cachedImage = null;
    });

    final bytes = _originalImage!.readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    setState(() {
      _cachedImage = frame.image;
    });
    state.setCorrecting(true);
    state.setInternalProcessing(false);
    widget.onStartCorrection?.call();
  }

  Future<void> cancelCorrection() async {
    final state = Provider.of<CurrentStateProcessing>(context, listen: false);
    if (_catchDoc?.finalImage == null) {
      setState(() {
        _selectedImage = _originalImage;
        _cachedImage = null;
      });
      state.setCorrecting(false);
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/final_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final finalImageFile = File(tempPath)..writeAsBytesSync(imge.encodeJpg(_catchDoc!.finalImage!));

    final bytes = finalImageFile.readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    setState(() {
      _selectedImage = finalImageFile;
      _cachedImage = frame.image;
    });
    state.setCorrecting(false);
  }

  int? _findClosestCornerIndex(Offset position) {
    double minDistance = _cornerDetectionRadius;
    int? closestCornerIndex;

    for (int i = 0; i < _corners.length; i++) {
      final distance = (_corners[i] - position).distance;
      if (distance < minDistance) {
        minDistance = distance;
        closestCornerIndex = i;
      }
    }
    return closestCornerIndex;
  }

  bool _isInsidePolygon(Offset position) {
    int crossings = 0;
    for (int i = 0, j = 3; i < 4; j = i++) {
      final a = _corners[i];
      final b = _corners[j];
      if (((a.dy > position.dy) != (b.dy > position.dy)) &&
          (position.dx < (b.dx - a.dx) * (position.dy - a.dy) / (b.dy - a.dy) + a.dx)) {
        crossings++;
      }
    }
    return crossings % 2 == 1;
  }

  void _onPanStart(DragStartDetails details) {
    final position = details.localPosition;
    final closestCornerIndex = _findClosestCornerIndex(position);
    final isInside = _isInsidePolygon(position);

    setState(() {
      if (closestCornerIndex != null) {
        _activeCornerIndex = closestCornerIndex;
        _isDraggingPolygon = false;
        _magnifierPosition = position;
      } else if (isInside) {
        _activeCornerIndex = null;
        _isDraggingPolygon = true;
        _dragStartPosition = position;
        _magnifierPosition = null;
      } else {
        _activeCornerIndex = null;
        _isDraggingPolygon = false;
        _magnifierPosition = null;
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final position = details.localPosition;
    final screenSize = MediaQuery.of(context).size;
    final clampedPosition = Offset(
      position.dx.clamp(0.0, screenSize.width),
      position.dy.clamp(0.0, screenSize.height * 0.8),
    );

    setState(() {
      if (_activeCornerIndex != null) {
        _corners[_activeCornerIndex!] = clampedPosition;
        _magnifierPosition = clampedPosition;
      } else if (_isDraggingPolygon && _dragStartPosition != null) {
        final delta = clampedPosition - _dragStartPosition!;
        _corners = _corners.map((corner) => corner + delta).toList();
        _dragStartPosition = clampedPosition;
        _magnifierPosition = null;
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _activeCornerIndex = null;
      _isDraggingPolygon = false;
      _dragStartPosition = null;
      _magnifierPosition = null;
    });
  }

  Future<void> applyManualCrop() async {
    final state = Provider.of<CurrentStateProcessing>(context, listen: false);
    if (_originalImage == null || _catchDoc?.originalImage == null) {
      state.setInternalProcessing(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagem original inválida')),
      );
      return;
    }

    state.setInternalProcessing(true);

    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height * 0.8;
    final imageWidth = _catchDoc!.originalImage!.width.toDouble();
    final imageHeight = _catchDoc!.originalImage!.height.toDouble();

    final aspectRatio = imageWidth / imageHeight;
    final displayWidth = aspectRatio > screenWidth / screenHeight ? screenWidth : screenHeight * aspectRatio;
    final displayHeight = aspectRatio > screenWidth / screenHeight ? screenWidth / aspectRatio : screenHeight;
    final offsetX = (screenWidth - displayWidth) / 2;
    final offsetY = (screenHeight - displayHeight) / 2;
    final scale = imageWidth / displayWidth;

    final corners = _corners.map((corner) => [
      ((corner.dx - offsetX) * scale).clamp(0.0, imageWidth - 1),
      ((corner.dy - offsetY) * scale).clamp(0.0, imageHeight - 1),
    ]).toList();

    if (corners.any((corner) => corner[0].isNaN || corner[1].isNaN)) {
      state.setInternalProcessing(false);
      state.setCorrecting(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cantos inválidos para recorte')),
      );
      return;
    }

    try {
      final correctedImage = await _catchDoc!.cropWithCorners(corners);
      if (correctedImage == null) throw Exception('Imagem recortada é nula');

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/corrected_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final correctedFile = File(tempPath)..writeAsBytesSync(imge.encodeJpg(correctedImage));

      final bytes = correctedFile.readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      setState(() {
        _selectedImage = correctedFile;
        _catchDoc!.finalImage = correctedImage;
        _cachedImage = frame.image;
      });
      state.setCorrecting(false);
      state.setInternalProcessing(false);
      widget.onImageProcessed?.call(correctedFile);
    } catch (e) {
      state.setInternalProcessing(false);
      state.setCorrecting(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao aplicar recorte: $e')),
      );
    }
  }

  void _closeImage() {
    final state = Provider.of<CurrentStateProcessing>(context, listen: false);
    setState(() {
      _selectedImage = null;
      _originalImage = null;
      _lastProcessedImage = null;
      _cachedImage = null;
    });
    state.setCorrecting(false);
    state.setInternalProcessing(false);
    _catchDoc?.dispose();
    widget.onClose?.call();
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
            Text('Nenhum documento selecionado', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    final imageWidth = _catchDoc?.originalImage?.width.toDouble() ?? 1.0;
    final imageHeight = _catchDoc?.originalImage?.height.toDouble() ?? 1.0;

    return GestureDetector(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            Image.file(_selectedImage!, fit: BoxFit.contain),
            if (state.isCorrecting)
              CustomPaint(
                painter: CornersPainter(
                  corners: _corners,
                  activeCornerIndex: _activeCornerIndex,
                  isDraggingPolygon: _isDraggingPolygon,
                  cachedImage: _cachedImage,
                  magnifierPosition: _magnifierPosition,
                  magnifierRadius: _magnifierRadius,
                  magnifierZoom: _magnifierZoom,
                  screenSize: screenSize,
                  imageWidth: imageWidth,
                  imageHeight: imageHeight,
                ),
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                ),
              ),
            if (state.isCorrecting)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: applyManualCrop,
                        icon: const Icon(Icons.crop, color: AppColors.calmWhite),
                        label: const Text('Recortar', style: TextStyle(color: AppColors.calmWhite)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lighterBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: cancelCorrection,
                        icon: const Icon(Icons.cancel, color: AppColors.calmWhite),
                        label: const Text('Cancelar', style: TextStyle(color: AppColors.calmWhite)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: _closeImage,
                icon: const Icon(Icons.close, size: 20, color: AppColors.calmWhite),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withAlpha(50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CornersPainter extends CustomPainter {
  final List<Offset> corners;
  final int? activeCornerIndex;
  final bool isDraggingPolygon;
  final ui.Image? cachedImage;
  final Offset? magnifierPosition;
  final double magnifierRadius;
  final double magnifierZoom;
  final Size screenSize;
  final double imageWidth;
  final double imageHeight;

  CornersPainter({
    required this.corners,
    this.activeCornerIndex,
    required this.isDraggingPolygon,
    this.cachedImage,
    this.magnifierPosition,
    required this.magnifierRadius,
    required this.magnifierZoom,
    required this.screenSize,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withAlpha(50)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    canvas.drawPath(path, paint);

    for (int i = 0; i < corners.length; i++) {
      final circlePaint = Paint()
        ..color = i == activeCornerIndex ? Colors.blue : Colors.red
        ..style = PaintingStyle.fill;
      final radius = i == activeCornerIndex ? 12.0 : 10.0;
      canvas.drawCircle(corners[i], radius, circlePaint);

      canvas.drawCircle(corners[i], radius, Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke);
    }

    if (isDraggingPolygon) {
      final center = Offset(
        corners.map((c) => c.dx).reduce((a, b) => a + b) / 4,
        corners.map((c) => c.dy).reduce((a, b) => a + b) / 4,
      );
      canvas.drawCircle(center, 10.0, Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill);
      canvas.drawCircle(center, 10.0, Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke);
    }

    if (activeCornerIndex != null && magnifierPosition != null && cachedImage != null) {
      final magnifierCenter = Offset(magnifierPosition!.dx, magnifierPosition!.dy - magnifierRadius - 20);

      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: magnifierCenter, radius: magnifierRadius)));

      final screenWidth = screenSize.width;
      final screenHeight = screenSize.height * 0.8;
      final aspectRatio = imageWidth / imageHeight;
      final displayWidth = aspectRatio > screenWidth / screenHeight ? screenWidth : screenHeight * aspectRatio;
      final displayHeight = aspectRatio > screenWidth / screenHeight ? screenWidth / aspectRatio : screenHeight;
      final offsetX = (screenWidth - displayWidth) / 2;
      final offsetY = (screenHeight - displayHeight) / 2;
      final scale = displayWidth / imageWidth;

      final imageX = (magnifierPosition!.dx - offsetX) / scale;
      final imageY = (magnifierPosition!.dy - offsetY) / scale;

      final matrix = Matrix4.identity()
        ..translate(magnifierCenter.dx - imageX * magnifierZoom * scale, magnifierCenter.dy - imageY * magnifierZoom * scale)
        ..scale(magnifierZoom * scale);
      final imageShader = ImageShader(cachedImage!, TileMode.clamp, TileMode.clamp, matrix.storage);

      canvas.drawCircle(magnifierCenter, magnifierRadius, Paint()..shader = imageShader);
      canvas.restore();

      canvas.drawCircle(magnifierCenter, magnifierRadius, Paint()
        ..color = Colors.black
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke);

      final cornerInMagnifier = corners[activeCornerIndex!];
      final relativePos = Offset(
        magnifierCenter.dx + (cornerInMagnifier.dx - magnifierPosition!.dx) * magnifierZoom,
        magnifierCenter.dy + (cornerInMagnifier.dy - magnifierPosition!.dy) * magnifierZoom,
      );
      canvas.drawCircle(relativePos, 7.0, Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill);
      canvas.drawCircle(relativePos, 7.0, Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}