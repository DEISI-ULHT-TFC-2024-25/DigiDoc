import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/current_state_processing.dart';
import '../widgets/DocumentImageViewer.dart';
import 'info_confirmation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/color_app.dart';

class CaptureDocumentPhotoScreen extends StatefulWidget {
  final int dossierId;
  final String dossierName;
  final CameraDescription camera;

  const CaptureDocumentPhotoScreen({
    Key? key,
    required this.dossierId,
    required this.dossierName,
    required this.camera,
  }) : super(key: key);

  @override
  _CaptureDocumentPhotoScreenState createState() => _CaptureDocumentPhotoScreenState();
}

class _CaptureDocumentPhotoScreenState extends State<CaptureDocumentPhotoScreen> {
  CameraController? _cameraController;
  List<XFile> _capturedImages = [];
  bool _isCameraInitialized = false;
  File? _imgJustCaptured;
  final GlobalKey<DocumentImageViewerState> _viewerKey = GlobalKey<DocumentImageViewerState>();

  @override
  void initState() {
    super.initState();
    if (widget.dossierId <= 0) {
      print('CaptureDocumentPhotoScreen iniciado com dossierId inválido: ${widget.dossierId}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: ID do dossiê inválido')),
        );
        Navigator.pop(context);
      });
      return;
    }
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameraController = CameraController(
        widget.camera,
        ResolutionPreset.max,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao inicializar câmera: $e')),
      );
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final state = Provider.of<CurrentStateProcessing>(context, listen: false);
        state.setProcessing(true);
        final XFile image = await _cameraController!.takePicture();
        setState(() {
          _imgJustCaptured = File(image.path);
        });
        state.setProcessing(false);
      } catch (e) {
        Provider.of<CurrentStateProcessing>(context, listen: false).setProcessing(false);
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

  void _handleClose() {
    setState(() {
      _imgJustCaptured = null;
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
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkBackground
          : Colors.black,
      appBar: AppBar(
        title: Text(
          "Tirar Foto do Documento",
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkPrimaryGradientStart.withAlpha(250)
            : Colors.black,
        iconTheme: IconThemeData(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkTextPrimary
              : Colors.white,
        ),
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
              onAdd: _addImage,
              onImageProcessed: (file) {
                setState(() {
                  _imgJustCaptured = file;
                });
                Provider.of<CurrentStateProcessing>(context, listen: false)
                    .setProcessing(false);
              },
              onClose: _handleClose,
            )
                : Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkPrimaryGradientStart
                    : Colors.white,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkBackground
                : Colors.black,
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
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? AppColors.darkBackground
                                        : Colors.black,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? AppColors.darkTextPrimary
                                        : Colors.white,
                                    size: 20,
                                  ),
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
                            color: _imgJustCaptured == null
                                ? (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextSecondary
                                : Colors.grey)
                                : (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextPrimary
                                : Colors.white),
                            size: 50,
                          ),
                          onPressed: _imgJustCaptured == null ? null : _startCorrection,
                        ),
                        Text(
                          "Corrigir",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _imgJustCaptured == null
                                ? (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextSecondary
                                : Colors.grey)
                                : (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextPrimary
                                : Colors.white),
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
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextPrimary
                                : Colors.white,
                            size: 50,
                          ),
                          onPressed: _imgJustCaptured == null ? _captureImage : _addImage,
                        ),
                        Text(
                          _imgJustCaptured == null ? "Capturar" : "Adicionar",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextPrimary
                                : Colors.white,
                          ),
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
                                ? (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextPrimary
                                : Colors.white)
                                : (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextSecondary
                                : Colors.grey),
                            size: 50,
                          ),
                          onPressed: _capturedImages.isNotEmpty && _imgJustCaptured == null
                              ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InfoConfirmationScreen(
                                  imagesList: _capturedImages,
                                  dossierId: widget.dossierId,
                                  dossierName: widget.dossierName,
                                ),
                              ),
                            );
                          }
                              : null,
                        ),
                        Text(
                          "Pronto",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _capturedImages.isNotEmpty && _imgJustCaptured == null
                                ? (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextPrimary
                                : Colors.white)
                                : (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextSecondary
                                : Colors.grey),
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