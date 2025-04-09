import 'package:digidoc/screens/capture_document_photo.dart';
import 'package:digidoc/screens/upload_document.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../DataBaseHelper.dart';
import '../main.dart';

class DossierScreen extends StatefulWidget {
  final int dossierId;
  final String dossierName;

  const DossierScreen(
      {Key? key, required this.dossierId, required this.dossierName})
      : super(key: key);

  @override
  _DossierScreenState createState() => _DossierScreenState();
}

class _DossierScreenState extends State<DossierScreen> {
  List<Map<String, dynamic>> documents = [];
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    loadDocuments();
  }

  Future<void> loadDocuments() async {
    List<Map<String, dynamic>> docs =
    await DataBaseHelper.instance.getDocuments(widget.dossierId);
    setState(() {
      documents = docs;
    });
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.dossierName,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.mainSolidDarkerColor,
        iconTheme: IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Documentos Salvos", style: TextStyle(fontSize: 20)),
            Expanded(
              child: documents.isEmpty
                  ? Center(child: Text("Nenhum documento adicionado."))
                  : GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  return Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.insert_drive_file,
                            size: 40, color: Colors.blueGrey),
                      ),
                      SizedBox(height: 5),
                      Text(documents[index]['name'],
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isExpanded
          ? Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Galeria",
                style:
                TextStyle(color: AppColors.mainSolidDarkerColor, fontSize: 12),
              ),
              FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UploadDocumentScreen(),
                    ),
                  ).then((_) => loadDocuments());
                },
                child: Icon(
                  Icons.photo,
                  color: Colors.white,
                ),
                backgroundColor: AppColors.mainSolidDarkerColor,
                heroTag: null,
              ),
            ],
          ),
          SizedBox(height: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Foto",
                style:
                TextStyle(color: AppColors.mainSolidDarkerColor, fontSize: 12),
              ),
              FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CaptureDocumentPhotoScreen(),
                    ),
                  ).then((_) => loadDocuments());
                },
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                ),
                backgroundColor: AppColors.mainSolidDarkerColor,
                heroTag: null,
              ),
            ],
          ),
          SizedBox(height: 20),
          FloatingActionButton(
            onPressed: _toggleExpand,
            child: Icon(Icons.close, color: Colors.white),
            backgroundColor: AppColors.mainSolidDarkerColor,
          ),
        ],
      )
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Adicionar\nDocumento",
            style: TextStyle(color: AppColors.mainSolidDarkerColor, fontSize: 12),
          ),
          SizedBox(height: 4),
          FloatingActionButton(
            onPressed: _toggleExpand,
            backgroundColor: AppColors.mainSolidDarkerColor,
            child: Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

