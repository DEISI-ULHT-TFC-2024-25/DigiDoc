import 'dart:io';
import 'dart:ui' as ui;
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
  CatchDocument? _catchDoc;
  File? _lastProcessedImage;
  final double _cornerDetectionRadius = 20.0;

  // Corner points (free points forming a polygon)
  List<Offset> _corners = [
    Offset.zero,
    Offset.zero,
    Offset.zero,
    Offset.zero,
  ];
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
      _catchDoc = CatchDocument(imageFile);
      await _catchDoc!.initialize();

      if (_catchDoc!.finalImage == null) {
        throw Exception('Imagem final não carregada');
      }
      if (_catchDoc!.documentCorners == null) {
        throw Exception('Nenhum documento detectado');
      }

      print('Imagem final pronta: ${_catchDoc!.finalImage!.width}x${_catchDoc!.finalImage!.height}');

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/final_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final finalImageFile = File(tempPath)..writeAsBytesSync(imge.encodeJpg(_catchDoc!.finalImage!));

      // Load image for magnifier
      final bytes = finalImageFile.readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _cachedImage = frame.image;

      setState(() {
        _originalImage = imageFile;
        _selectedImage = finalImageFile;
        _lastProcessedImage = imageFile;
        _activeCornerIndex = null;
        _isDraggingPolygon = false;
        _magnifierPosition = null;
      });
      state.setCorrecting(false);
      state.setInternalProcessing(false);

      if (widget.onImageProcessed != null) {
        widget.onImageProcessed!(finalImageFile);
      }
      print('Imagem processada salva: ${finalImageFile.path}, Original: ${_originalImage?.path}');
    } catch (e) {
      setState(() {
        _selectedImage = null;
        _originalImage = null;
        _lastProcessedImage = null;
        _magnifierPosition = null;
        _cachedImage = null;
      });
      state.setInternalProcessing(false);
      _catchDoc?.dispose();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao processar imagem: $e')),
      );
      print('DIV: Erro ao processar imagem: $e');
    }
  }

  Future<void> startCorrection() async {
    final state = Provider.of<CurrentStateProcessing>(context, listen: false);
    if (_originalImage != null && !state.isCorrecting && _catchDoc != null) {
      final screenSize = MediaQuery.of(context).size;
      final screenWidth = screenSize.width.toDouble();
      final screenHeight = (screenSize.height * 0.8).toDouble();
      final imageWidth = _catchDoc!.originalImage!.width.toDouble();
      final imageHeight = _catchDoc!.originalImage!.height.toDouble();

      final aspectRatio = imageWidth / imageHeight;
      final displayWidth = (aspectRatio > screenWidth / screenHeight
          ? screenWidth
          : screenHeight * aspectRatio)
          .toDouble();
      final displayHeight = (aspectRatio > screenWidth / screenHeight
          ? screenWidth / aspectRatio
          : screenHeight)
          .toDouble();
      final offsetX = ((screenWidth - displayWidth) / 2).toDouble();
      final offsetY = ((screenHeight - displayHeight) / 2).toDouble();

      final scale = (displayWidth / imageWidth).toDouble();

      // Initialize corners based on detected document corners
      if (_catchDoc!.documentCorners != null) {
        final corners = _catchDoc!.documentCorners!;
        final screenCorners = corners.map((corner) {
          final x = (corner[0] * scale + offsetX).toDouble();
          final y = (corner[1] * scale + offsetY).toDouble();
          return Offset(x, y);
        }).toList();

        setState(() {
          _corners = screenCorners;
        });
      } else {
        // Fallback to default corners at image borders
        setState(() {
          _corners = [
            Offset(offsetX, offsetY),
            Offset(offsetX + displayWidth, offsetY),
            Offset(offsetX + displayWidth, offsetY + displayHeight),
            Offset(offsetX, offsetY + displayHeight),
          ];
        });
      }

      // Load image for magnifier
      if (_selectedImage != null) {
        final bytes = _originalImage!.readAsBytesSync();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        setState(() {
          _cachedImage = frame.image;
        });
      }

      setState(() {
        _selectedImage = _originalImage;
        _activeCornerIndex = null;
        _isDraggingPolygon = false;
        _magnifierPosition = null;
      });
      state.setCorrecting(true);
      state.setInternalProcessing(false);
      if (widget.onStartCorrection != null) {
        widget.onStartCorrection!();
      }
      print('Correction Started: Corners=$_corners');
    }
  }

  Future<void> cancelCorrection() async {
    final state = Provider.of<CurrentStateProcessing>(context, listen: false);
    if (_catchDoc != null && _catchDoc!.finalImage != null) {
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/final_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final finalImageFile = File(tempPath)..writeAsBytesSync(imge.encodeJpg(_catchDoc!.finalImage!));

      // Load image for magnifier
      final bytes = finalImageFile.readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      setState(() {
        _selectedImage = finalImageFile;
        _activeCornerIndex = null;
        _isDraggingPolygon = false;
        _magnifierPosition = null;
        _cachedImage = frame.image;
      });
      state.setCorrecting(false);
      print('Correction Cancelled: Restored Image=${finalImageFile.path}');
    } else {
      setState(() {
        _selectedImage = _originalImage;
        _activeCornerIndex = null;
        _isDraggingPolygon = false;
        _magnifierPosition = null;
        _cachedImage = null;
      });
      state.setCorrecting(false);
      print('Correction Cancelled: No final image, restored original');
    }
  }

  int? _findClosestCornerIndex(Offset position) {
    double minDistance = _cornerDetectionRadius;
    int? closestCornerIndex;

    for (int i = 0; i < _corners.length; i++) {
      final distance = (_corners[i] - position).distance.toDouble();
      if (distance < minDistance) {
        minDistance = distance;
        closestCornerIndex = i;
      }
    }

    print('Find Closest Corner: Position=$position, ClosestCornerIndex=$closestCornerIndex, Distance=$minDistance');
    return closestCornerIndex;
  }

  bool _isInsidePolygon(Offset position) {
    // Ray-casting algorithm to check if point is inside polygon
    int crossings = 0;
    for (int i = 0; i < 4; i++) {
      final j = (i + 1) % 4;
      final a = _corners[i];
      final b = _corners[j];
      if (((a.dy > position.dy) != (b.dy > position.dy)) &&
          (position.dx <
              ((b.dx - a.dx) * (position.dy - a.dy) / (b.dy - a.dy) + a.dx).toDouble())) {
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
        _magnifierPosition = null; // Não mostrar lupa ao arrastar polígono
      } else {
        _activeCornerIndex = null;
        _isDraggingPolygon = false;
        _magnifierPosition = null;
      }
      print(
          'Pan Start: Corner=$_activeCornerIndex, DraggingPolygon=$_isDraggingPolygon, Position=$position');
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final position = details.localPosition;
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width.toDouble();
    final screenHeight = (screenSize.height * 0.8).toDouble();

    final clampedX = position.dx.clamp(0.0, screenWidth).toDouble();
    final clampedY = position.dy.clamp(0.0, screenHeight).toDouble();
    final clampedPosition = Offset(clampedX, clampedY);

    setState(() {
      if (_activeCornerIndex != null) {
        // Move the selected corner freely
        final newCorners = List<Offset>.from(_corners);
        newCorners[_activeCornerIndex!] = clampedPosition;
        _corners = newCorners;
        _magnifierPosition = clampedPosition;
        print(
            'Move Corner: Corner=$_activeCornerIndex, NewPosition=$clampedPosition, Corners=$_corners');
      } else if (_isDraggingPolygon && _dragStartPosition != null) {
        // Move the entire polygon
        final delta = Offset(
          (clampedPosition.dx - _dragStartPosition!.dx).toDouble(),
          (clampedPosition.dy - _dragStartPosition!.dy).toDouble(),
        );
        _corners = _corners.map((corner) {
          return Offset(
            (corner.dx + delta.dx).toDouble(),
            (corner.dy + delta.dy).toDouble(),
          );
        }).toList();
        _dragStartPosition = clampedPosition;
        _magnifierPosition = null; // Não mostrar lupa ao arrastar polígono
        print('Move Polygon: Delta=$delta, NewCorners=$_corners');
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _activeCornerIndex = null;
      _isDraggingPolygon = false;
      _dragStartPosition = null;
      _magnifierPosition = null;
      print('Pan End');
    });
  }

  Future<void> applyManualCrop() async {
    final state = Provider.of<CurrentStateProcessing>(context, listen: false);
    if (_originalImage == null || _catchDoc == null || _catchDoc!.originalImage == null) {
      state.setInternalProcessing(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao aplicar recorte: Imagem original inválida')),
      );
      print(
          'Crop Skipped: OriginalImage=${_originalImage != null}, CatchDoc=${_catchDoc != null}, CatchDocOriginalImage=${_catchDoc?.originalImage != null}');
      return;
    }

    state.setInternalProcessing(true);

    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width.toDouble();
    final screenHeight = (screenSize.height * 0.8).toDouble();
    final imageWidth = _catchDoc!.originalImage!.width.toDouble();
    final imageHeight = _catchDoc!.originalImage!.height.toDouble();

    final aspectRatio = imageWidth / imageHeight;
    final displayWidth = (aspectRatio > screenWidth / screenHeight
        ? screenWidth
        : screenHeight * aspectRatio)
        .toDouble();
    final displayHeight = (aspectRatio > screenWidth / screenHeight
        ? screenWidth / aspectRatio
        : screenHeight)
        .toDouble();
    final offsetX = ((screenWidth - displayWidth) / 2).toDouble();
    final offsetY = ((screenHeight - displayHeight) / 2).toDouble();

    final scale = (imageWidth / displayWidth).toDouble();

    // Convert corners to image space
    final corners = _corners.map((corner) {
      final x = ((corner.dx - offsetX) * scale).toDouble();
      final y = ((corner.dy - offsetY) * scale).toDouble();
      return [
        x.clamp(0.0, imageWidth - 1),
        y.clamp(0.0, imageHeight - 1),
      ];
    }).toList();

    // Validate corners
    if (corners.any((corner) => corner[0].isNaN || corner[1].isNaN || corner[0] < 0 || corner[1] < 0)) {
      state.setInternalProcessing(false);
      state.setCorrecting(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cantos inválidos para recorte')),
      );
      print('Crop Failed: Invalid Corners=$corners');
      return;
    }

    // Order corners: top-left, top-right, bottom-right, bottom-left
    final orderedCorners = [
      corners[0], // Top-left
      corners[1], // Top-right
      corners[2], // Bottom-right
      corners[3], // Bottom-left
    ];

    print('Applying Crop: Corners=$orderedCorners, ImageSize=${imageWidth}x$imageHeight');

    try {
      final correctedImage = await _catchDoc!.cropWithCorners(orderedCorners);

      if (correctedImage != null) {
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/corrected_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final correctedFile = File(tempPath)..writeAsBytesSync(imge.encodeJpg(correctedImage));

        // Load image for magnifier
        final bytes = correctedFile.readAsBytesSync();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();

        setState(() {
          _selectedImage = correctedFile;
          _catchDoc!.finalImage = correctedImage;
          _magnifierPosition = null;
          _cachedImage = frame.image;
        });
        state.setCorrecting(false);
        state.setInternalProcessing(false);
        if (widget.onImageProcessed != null) {
          widget.onImageProcessed!(correctedFile);
        }
        print('Crop Applied: New Image=${correctedFile.path}, Size=${correctedImage.width}x${correctedImage.height}');
      } else {
        throw Exception('Imagem recortada retornada é nula');
      }
    } catch (e) {
      state.setInternalProcessing(false);
      state.setCorrecting(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao aplicar recorte: $e')),
      );
      print('Crop Failed: Error=$e, Corners=$orderedCorners');
    }
  }

  void _closeImage() {
    print('Close Image');
    final state = Provider.of<CurrentStateProcessing>(context, listen: false);
    setState(() {
      _selectedImage = null;
      _originalImage = null;
      _lastProcessedImage = null;
      _activeCornerIndex = null;
      _isDraggingPolygon = false;
      _magnifierPosition = null;
      _cachedImage = null;
    });
    state.setCorrecting(false);
    state.setInternalProcessing(false);
    _catchDoc?.dispose();
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
                        icon: const Icon(Icons.crop),
                        label: const Text('Aplicar Recorte'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: cancelCorrection,
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancelar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
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
                icon: const Icon(Icons.close, size: 20, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
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
    // Draw lines connecting corners (visual aid)
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    canvas.drawPath(path, paint);

    // Draw corners
    for (int i = 0; i < corners.length; i++) {
      final corner = corners[i];
      final circlePaint = Paint()
        ..color = i == activeCornerIndex ? Colors.blue.withAlpha(40) : Colors.black87
        ..style = PaintingStyle.fill;

      final radius = (i == activeCornerIndex ? 60.0 : 10.0).toDouble();
      canvas.drawCircle(corner, radius, circlePaint);

    }

    // Draw magnifier only when dragging a corner
    if (activeCornerIndex != null && magnifierPosition != null && cachedImage != null) {
      final magnifierCenter = Offset(
        magnifierPosition!.dx,
        magnifierPosition!.dy - magnifierRadius - 20, // Position above finger
      );

      // Create a clip for the magnifier circle
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: magnifierCenter, radius: magnifierRadius)),
      );

      // Calculate image-to-screen transformation
      final screenWidth = screenSize.width;
      final screenHeight = screenSize.height * 0.8;
      final aspectRatio = imageWidth / imageHeight;
      final displayWidth = aspectRatio > screenWidth / screenHeight
          ? screenWidth
          : screenHeight * aspectRatio;
      final displayHeight = aspectRatio > screenWidth / screenHeight
          ? screenWidth / aspectRatio
          : screenHeight;
      final offsetX = (screenWidth - displayWidth) / 2;
      final offsetY = (screenHeight - displayHeight) / 2;
      final scale = displayWidth / imageWidth;

      // Convert magnifier position to image space
      final imageX = (magnifierPosition!.dx - offsetX) / scale;
      final imageY = (magnifierPosition!.dy - offsetY) / scale;

      // Create shader for zoomed image
      final matrix = Matrix4.identity();
      matrix.translate(
        magnifierCenter.dx - imageX * magnifierZoom * scale,
        magnifierCenter.dy - imageY * magnifierZoom * scale,
      );
      matrix.scale(magnifierZoom * scale);
      final imageShader = ImageShader(
        cachedImage!,
        TileMode.clamp,
        TileMode.clamp,
        matrix.storage,
      );

      // Draw the zoomed image using shader
      canvas.drawCircle(
        magnifierCenter,
        magnifierRadius,
        Paint()..shader = imageShader,
      );

      canvas.restore();

      // Draw magnifier border
      canvas.drawCircle(
        magnifierCenter,
        magnifierRadius,
        Paint()
          ..color = Colors.black
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );

      // Redraw the active corner in the magnifier area
      final cornerInMagnifier = corners[activeCornerIndex!];
      final relativePos = Offset(
        magnifierCenter.dx +
            (cornerInMagnifier.dx - magnifierPosition!.dx) * magnifierZoom,
        magnifierCenter.dy +
            (cornerInMagnifier.dy - magnifierPosition!.dy) * magnifierZoom,
      );
      canvas.drawCircle(
        relativePos,
        7.0,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}