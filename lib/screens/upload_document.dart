import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/current_state_processing.dart';
import '../widgets/DocumentImageViewer.dart';
import 'info_confirmation.dart';
import '../constants/color_app.dart';

class UploadDocumentScreen extends StatefulWidget {
  final int dossierId;
  final String dossierName;

  const UploadDocumentScreen({Key? key, required this.dossierId, required this.dossierName}) : super(key: key);

  @override
  _UploadDocumentScreenState createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  File? _selectedImage;
  bool _imageAdded = false;
  List<File> _uploadedDocuments = [];
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<DocumentImageViewerState> _viewerKey = GlobalKey<DocumentImageViewerState>();

  @override
  void initState() {
    super.initState();
    if (widget.dossierId <= 0) {
      print('UploadDocumentScreen iniciado com dossierId inválido: ${widget.dossierId}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro: ID do dossiê inválido')),
          );
          Navigator.pop(context);
        }
      });
    }
  }

  Future<void> _uploadImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );

    if (image != null) {

      Provider.of<CurrentStateProcessing>(context, listen: false).setProcessing(true);
      setState(() {
        _selectedImage = File(image.path);
        _imageAdded = false;
      });
    }
  }

  void _addDocument() {
    if (_selectedImage != null) {
      setState(() {
        _uploadedDocuments.add(_selectedImage!);
        _selectedImage = null;
      });
      Provider.of<CurrentStateProcessing>(context, listen: false).setProcessing(false);
    }

    setState(() {
      _selectedImage = null;
      _imageAdded = true;
    });
  }

  void _deleteImage(int index) {
    setState(() {
      _uploadedDocuments.removeAt(index);
    });
  }

  void _startCorrection() {
    if (_selectedImage != null) {
      _viewerKey.currentState?.startCorrection();

    }
  }

  void _handleClose() {
    setState(() {
      _selectedImage = null;
      _imageAdded = true;

    });
    Provider.of<CurrentStateProcessing>(context, listen: false).setProcessing(false);
  }

  void _navigateToConfirmation() {
    if (_uploadedDocuments.isNotEmpty && _selectedImage == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InfoConfirmationScreen(
            imagesList: _uploadedDocuments.map((file) => XFile(file.path)).toList(),
            dossierId: widget.dossierId,
            dossierName: widget.dossierName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<CurrentStateProcessing>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? AppColors.darkPrimaryGradientStart : AppColors.darkerBlue,
        title: Text(
          'Carregar Documento',
          style: GoogleFonts.poppins(
            color: isDarkMode ? AppColors.darkTextPrimary : AppColors.calmWhite,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDarkMode ? AppColors.darkTextPrimary : AppColors.calmWhite,
        ),
      ),
      body: Container(
        color: isDarkMode ? AppColors.darkBackground : AppColors.background,
        child: Column(
          children: [
            Expanded(
              child: DocumentImageViewer(
                key: _viewerKey,
                imageFile: _selectedImage,
                onStartCorrection: _startCorrection,
                onAdd: _addDocument,
                onImageProcessed: (file) {
                  Provider.of<CurrentStateProcessing>(context, listen: false).setProcessing(false);
                  setState(() {
                    _selectedImage = file;
                  });
                },
                onClose: _handleClose,
              ),
            ),
            if (_uploadedDocuments.isNotEmpty)
              Container(
                height: 100,
                color: isDarkMode ? AppColors.darkCardBackground : AppColors.cardBackground,
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
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDarkMode ? AppColors.darkPrimaryGradientStart : AppColors.darkerBlue,
                              ),
                              child: Icon(
                                Icons.close,
                                color: isDarkMode ? AppColors.darkTextPrimary : AppColors.calmWhite,
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.change_circle,
                          color: _selectedImage == null
                              ? (isDarkMode ? AppColors.darkTextSecondary : AppColors.darkerBlue.withAlpha(100))
                              : (isDarkMode ? AppColors.darkTextPrimary : AppColors.darkerBlue),
                          size: 50,
                        ),
                        onPressed: _selectedImage == null ? null : _startCorrection,
                      ),
                      Text(
                        "Corrigir",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _selectedImage == null
                              ? (isDarkMode ? AppColors.darkTextSecondary : AppColors.darkerBlue.withAlpha(100))
                              : (isDarkMode ? AppColors.darkTextPrimary : AppColors.darkerBlue),
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
                          color: isDarkMode ? AppColors.darkTextPrimary : AppColors.darkerBlue,
                          size: 50,
                        ),
                        onPressed: _selectedImage == null ? _uploadImage : _addDocument,
                      ),
                      Text(
                        _selectedImage == null ? "Carregar" : "Adicionar",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: (isDarkMode ? AppColors.darkTextPrimary : AppColors.darkerBlue),
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
                          color: (_uploadedDocuments.isEmpty && _selectedImage != null) || (!_imageAdded || _uploadedDocuments.isEmpty)
                              ? (isDarkMode ? AppColors.darkTextSecondary : AppColors.darkerBlue.withAlpha(100))
                              : (isDarkMode ? AppColors.darkTextPrimary : AppColors.darkerBlue),
                          size: 50,
                        ),
                        onPressed: _uploadedDocuments.isNotEmpty && _selectedImage == null ? _navigateToConfirmation : null,
                      ),
                      Text(
                        "Pronto",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: (_uploadedDocuments.isEmpty && _selectedImage != null) || (!_imageAdded || _uploadedDocuments.isEmpty)
                              ? (isDarkMode ? AppColors.darkTextSecondary : AppColors.darkerBlue.withAlpha(100))
                              : (isDarkMode ? AppColors.darkTextPrimary : AppColors.darkerBlue),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}