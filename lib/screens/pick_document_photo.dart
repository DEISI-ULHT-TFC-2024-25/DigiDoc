import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imge;
import 'package:path_provider/path_provider.dart';

import 'info_confirmation.dart';

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