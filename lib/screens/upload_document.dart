import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'info_confirmation.dart';

class UploadDocumentScreen extends StatefulWidget {
  @override
  _UploadDocumentScreenState createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  File? _selectedImage;
  List<File> _uploadedDocuments = [];
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

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
        
        setState(() {
          _selectedImage = imageFile;
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao processar documento: ${e.toString()}'),
          duration: Duration(seconds: 3),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Carregar Documento',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              child: _isProcessing
                  ? Center(child: CircularProgressIndicator())
                  : _selectedImage == null
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate,
                        size: 80, color: Colors.grey),
                    SizedBox(height: 20),
                    Text(
                      _uploadedDocuments.isEmpty
                          ? 'Nenhum documento selecionado'
                          : "",
                      style:
                      TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : InteractiveViewer(
                child: Center(
                  child: Image.file(_selectedImage!),
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
                            File(_uploadedDocuments[index].path),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    IconButton(
                      icon: Icon(Icons.change_circle,
                          color: _selectedImage == null
                              ? Colors.grey
                              : Colors.white,
                          size: 50),
                      onPressed: _selectedImage == null
                          ? null
                          : () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                    ),
                    Text("Repetir",
                        style: TextStyle(
                            fontSize: 14,
                            color: _selectedImage == null
                                ? Colors.grey
                                : Colors.white)),
                  ],
                ),
                SizedBox(width: 30),
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        _selectedImage == null
                            ? Icons.file_upload_outlined
                            : Icons.add_photo_alternate,
                        color: Colors.white,
                        size: 50,
                      ),
                      onPressed:
                      _selectedImage == null ? _pickImage : _addDocument,
                    ),
                    Text(_selectedImage == null ? "Carregar" : "Adicionar",
                        style: TextStyle(
                            fontSize: 14,
                            color: _selectedImage == null
                                ? Colors.grey
                                : Colors.white)),
                  ],
                ),
                SizedBox(width: 30),
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.check_circle,
                        color: _uploadedDocuments.isNotEmpty &&
                            _selectedImage == null
                            ? Colors.white
                            : Colors.grey,
                        size: 50,
                      ),
                      onPressed: _uploadedDocuments.isNotEmpty &&
                          _selectedImage == null
                          ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InfoConfirmationScreen(
                              imagesList: _uploadedDocuments
                                  .map((file) => XFile(file.path))
                                  .toList(),
                            ),
                          ),
                        );
                      }
                          : null,
                    ),
                    Text("Pronto",
                        style: TextStyle(
                            fontSize: 14,
                            color: _uploadedDocuments.isNotEmpty
                                ? Colors.white
                                : Colors.grey)),
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