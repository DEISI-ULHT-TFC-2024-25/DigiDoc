import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'info_confirmation.dart';
import 'DocumentImageViewer.dart';

class CaptureDocumentPhotoScreen extends StatefulWidget {
  @override
  _CaptureDocumentPhotoScreenState createState() => _CaptureDocumentPhotoScreenState();
}

class _CaptureDocumentPhotoScreenState extends State<CaptureDocumentPhotoScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  List<XFile> _capturedImages = [];
  bool _isCameraInitialized = false;
  File? _imgJustCaptured;
  bool _isProcessing = false;
  final GlobalKey<DocumentImageViewerState> _viewerKey = GlobalKey<DocumentImageViewerState>();

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

  Future<void> _captureImage() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        setState(() => _isProcessing = true);
        final XFile image = await _cameraController!.takePicture();
        setState(() {
          _imgJustCaptured = File(image.path);
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao capturar imagem: $e")),
        );
      }
    }
  }

  void _addImage() {
    if (_imgJustCaptured != null) {
      setState(() {
        _capturedImages.add(XFile(_imgJustCaptured!.path));
        _imgJustCaptured = null;
      });
    }
  }

  void _startCorrection() {
    if (_imgJustCaptured != null) {
      _viewerKey.currentState?.startCorrection();
    }
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
        title: const Text("Tirar Foto do Documento", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isCameraInitialized
                ? _imgJustCaptured == null
                ? CameraPreview(_cameraController!)
                : DocumentImageViewer(
              key: _viewerKey,
              imageFile: _imgJustCaptured,
              isProcessing: _isProcessing,
              onAdd: _addImage,
              onImageProcessed: (file) {
                setState(() {
                  _imgJustCaptured = file;
                  _isProcessing = false;
                });
              },
            )
                : const Center(child: CircularProgressIndicator()),
          ),
          Container(
            padding: const EdgeInsets.all(10),
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
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.change_circle,
                            color: _imgJustCaptured == null ? Colors.grey : Colors.white,
                            size: 50,
                          ),
                          onPressed: _imgJustCaptured == null ? null : _startCorrection,
                        ),
                        Text(
                          "Corrigir",
                          style: TextStyle(
                            fontSize: 14,
                            color: _imgJustCaptured == null ? Colors.grey : Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 30),
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(
                            _imgJustCaptured == null ? Icons.circle : Icons.add_circle,
                            color: Colors.white,
                            size: 50,
                          ),
                          onPressed: _imgJustCaptured == null ? _captureImage : _addImage,
                        ),
                        Text(
                          _imgJustCaptured == null ? "Capturar" : "Adicionar",
                          style: const TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(width: 30),
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.check_circle,
                            color: _capturedImages.isNotEmpty && _imgJustCaptured == null
                                ? Colors.white
                                : Colors.grey,
                            size: 50,
                          ),
                          onPressed: _capturedImages.isNotEmpty && _imgJustCaptured == null
                              ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InfoConfirmationScreen(
                                  imagesList: _capturedImages,
                                ),
                              ),
                            );
                          }
                              : null,
                        ),
                        Text(
                          "Pronto",
                          style: TextStyle(
                            fontSize: 14,
                            color: _capturedImages.isNotEmpty && _imgJustCaptured == null
                                ? Colors.white
                                : Colors.grey,
                          ),
                        ),
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