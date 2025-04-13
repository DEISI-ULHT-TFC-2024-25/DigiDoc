import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/CurrentStateProcessing.dart';
import 'info_confirmation.dart';
import '../widgets/DocumentImageViewer.dart';

class UploadDocumentScreen extends StatefulWidget {
  @override
  _UploadDocumentScreenState createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  File? _selectedImage;
  List<File> _uploadedDocuments = [];
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<DocumentImageViewerState> _viewerKey = GlobalKey<DocumentImageViewerState>();

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
      });
    }
  }

  void _addDocument() {
    if (_selectedImage != null) {
      setState(() {
        _uploadedDocuments.add(_selectedImage!);
        _selectedImage = null;
      });
    }
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
    });
  }

  void _navigateToConfirmation() {
    if (_uploadedDocuments.isNotEmpty && _selectedImage == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InfoConfirmationScreen(
            imagesList: _uploadedDocuments.map((file) => XFile(file.path)).toList(),
          ),
        ),
      );
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
              child: DocumentImageViewer(
                key: _viewerKey,
                imageFile: _selectedImage,
                onStartCorrection: _startCorrection,
                onAdd: _addDocument,
                onImageProcessed: (file) {
                  setState(() {
                    _selectedImage = file;
                  });
                  Provider.of<CurrentStateProcessing>(context, listen: false).setProcessing(false);
                },
                onClose: _handleClose,
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
                        Icons.change_circle,
                        color: _selectedImage == null ? Colors.grey : Colors.white,
                        size: 50,
                      ),
                      onPressed: _selectedImage == null ? null : _startCorrection,
                    ),
                    Text(
                      "Corrigir",
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
                        color: _selectedImage == null ? Colors.white : Colors.white,
                        size: 50,
                      ),
                      onPressed: _selectedImage == null ? _uploadImage : _addDocument,
                    ),
                    Text(
                      _selectedImage == null ? "Carregar" : "Adicionar",
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedImage == null ? Colors.white : Colors.white,
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
                        color: _uploadedDocuments.isNotEmpty && _selectedImage == null ? Colors.white : Colors.grey,
                        size: 50,
                      ),
                      onPressed: _uploadedDocuments.isNotEmpty && _selectedImage == null ? _navigateToConfirmation : null,
                    ),
                    Text(
                      "Pronto",
                      style: TextStyle(
                        fontSize: 14,
                        color: _uploadedDocuments.isNotEmpty && _selectedImage == null ? Colors.white : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}