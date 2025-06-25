import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../constants/color_app.dart';
import '../models/data_base_helper.dart';
import 'capture_document_photo.dart';
import 'upload_document.dart';
import 'document_viewer.dart';
import 'info_confirmation.dart';

class DossierScreen extends StatefulWidget {
  final int dossierId;
  final String dossierName;
  final CameraDescription camera;

  const DossierScreen({
    Key? key,
    required this.dossierId,
    required this.dossierName,
    required this.camera,
  }) : super(key: key);

  @override
  _DossierScreenState createState() => _DossierScreenState();
}

class _DossierScreenState extends State<DossierScreen> {
  List<Map<String, dynamic>> documents = [];
  List<Map<String, dynamic>> filteredDocuments = [];
  bool _isExpanded = false;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  static final Map<int, List<Map<String, dynamic>>> _documentsCache = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.dossierId <= 0) {
      print('DossierScreen iniciado com dossierId inválido: ${widget.dossierId}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: ID do dossiê inválido')),
        );
        Navigator.pop(context);
      });
      return;
    }
    DataBaseHelper.instance.diagnoseDatabase();
    loadDocuments();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> loadDocuments() async {
    print('Carregando documentos para dossierId: ${widget.dossierId}');
    try {
      if (_documentsCache.containsKey(widget.dossierId)) {
        setState(() {
          documents = _documentsCache[widget.dossierId]!;
          filteredDocuments = documents;
          _isLoading = false;
        });
        print('Documentos carregados do cache: ${documents.length}');
        return;
      }

      final docs = await DataBaseHelper.instance.getDocuments(widget.dossierId);
      setState(() {
        documents = docs;
        filteredDocuments = docs;
        _documentsCache[widget.dossierId] = docs;
        _isLoading = false;
        print('Carregados ${docs.length} documentos para dossierId: ${widget.dossierId}');
      });
    } catch (e) {
      print('Erro ao carregar documentos: $e');
      setState(() {
        documents = [];
        filteredDocuments = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar documentos: $e')),
      );
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _filterDocuments();
    });
  }

  Future<void> _filterDocuments() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        filteredDocuments = documents;
      });
      print('Busca vazia, resetando documentos');
      return;
    }

    try {
      final results = await DataBaseHelper.instance.searchDocumentsByText(query);
      setState(() {
        filteredDocuments = results;
      });
      print('Busca "$query": ${results.length} documentos encontrados');
    } catch (e) {
      print('Erro ao filtrar documentos: $e');
      setState(() {
        filteredDocuments = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar documentos: $e')),
      );
    }
  }

  Future<Color> _getDocumentStatusColor(int documentId) async {
    final alerts = await DataBaseHelper.instance.getAlertsForDocument(documentId);
    if (alerts.isEmpty) return Colors.grey;

    final now = DateTime.now();
    DateTime? nearestDate;
    for (var alert in alerts) {
      final alertDate = DateTime.parse(alert['date'] as String);
      if (alert['is_active'] == 1 && (nearestDate == null || alertDate.isBefore(nearestDate))) {
        nearestDate = alertDate;
      }
    }

    if (nearestDate == null) return Colors.grey;
    final daysUntilDue = nearestDate.difference(now).inDays;

    if (now.isAfter(nearestDate)) {
      return Colors.red;
    } else if (daysUntilDue <= 7) {
      return Colors.yellow;
    } else {
      return Colors.green;
    }
  }

  Future<void> _editDocumentName(int documentId, String currentName) async {
    final TextEditingController controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Nome do Documento'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nome do Documento',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context, controller.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('O nome não pode estar vazio')),
                );
              }
            },
            child: const Text('Salvar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkerBlue,
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final db = await DataBaseHelper.instance.database;
      await db.update(
        'Document',
        {'document_name': result},
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
      _documentsCache.remove(widget.dossierId);
      await loadDocuments();
    }
  }

  Future<void> _deleteDocument(int documentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Deseja excluir este documento? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DataBaseHelper.instance.deleteDocument(documentId);
      _documentsCache.remove(widget.dossierId);
      await loadDocuments();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documento excluído com sucesso')),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.dossierName,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.darkerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar documentos por palavras-chave',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Documentos Salvos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredDocuments.isEmpty
                  ? const Center(child: Text('Nenhum documento encontrado.'))
                  : ListView.builder(
                itemCount: filteredDocuments.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocuments[index];
                  final docTypeName = doc['document_type_name'] as String? ?? 'Não Definido';
                  final docName = doc['document_name'] as String? ?? 'Sem Nome';
                  final createdAt = doc['created_at'] != null
                      ? DateFormat('dd/MM/yyyy', 'pt_BR')
                      .format(DateTime.parse(doc['created_at']))
                      : 'Sem Data';
                  final thumbnailData = doc['file_data'] as Uint8List?;

                  return InkWell(
                    onTap: () async {
                      final fileData = await DataBaseHelper.instance
                          .getDocumentFileData(doc['document_id']);
                      if (fileData != null && fileData['file_data_print'] != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DocumentViewerScreen(
                              documentId: doc['document_id'],
                              documentName: docTypeName,
                              fileDataPrint: fileData['file_data_print'] as Uint8List,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nenhum PDF disponível')),
                        );
                      }
                    },
                    child: Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: thumbnailData != null
                                    ? DecorationImage(
                                  image: MemoryImage(thumbnailData),
                                  fit: BoxFit.cover,
                                )
                                    : null,
                                color: thumbnailData == null ? Colors.blue[100] : null,
                              ),
                              child: thumbnailData == null
                                  ? const Icon(
                                Icons.insert_drive_file,
                                size: 40,
                                color: Colors.blueGrey,
                              )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    docName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.darkerBlue,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Data de criação: $createdAt',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      FutureBuilder<Color>(
                                        future: _getDocumentStatusColor(doc['document_id']),
                                        builder: (context, snapshot) {
                                          return Container(
                                            width: 12,
                                            height: 12,
                                            margin: const EdgeInsets.only(right: 8),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: snapshot.data ?? Colors.grey,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          size: 20,
                                          color: AppColors.darkerBlue,
                                        ),
                                        onPressed: () => _editDocumentName(
                                            doc['document_id'], docName),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 20,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _deleteDocument(doc['document_id']),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                'Galeria',
                style: TextStyle(color: AppColors.darkerBlue, fontSize: 12),
              ),
              FloatingActionButton(
                heroTag: 'dossier_fab_upload',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UploadDocumentScreen(
                        dossierId: widget.dossierId,
                        dossierName: widget.dossierName,
                      ),
                    ),
                  ).then((_) {
                    _documentsCache.remove(widget.dossierId);
                    loadDocuments();
                  });
                },
                backgroundColor: AppColors.darkerBlue,
                child: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Foto',
                style: TextStyle(color: AppColors.darkerBlue, fontSize: 12),
              ),
              FloatingActionButton(
                heroTag: 'dossier_fab_photo',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CaptureDocumentPhotoScreen(
                        dossierId: widget.dossierId,
                        dossierName: widget.dossierName,
                        camera: widget.camera,
                      ),
                    ),
                  ).then((_) {
                    _documentsCache.remove(widget.dossierId);
                    loadDocuments();
                  });
                },
                backgroundColor: AppColors.darkerBlue,
                child: const Icon(Icons.camera_alt_outlined, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FloatingActionButton(
            heroTag: 'dossier_fab_main',
            onPressed: _toggleExpand,
            backgroundColor: AppColors.darkerBlue,
            child: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      )
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Adicionar\nDocumento',
            style: TextStyle(color: AppColors.darkerBlue, fontSize: 12),
          ),
          const SizedBox(height: 4),
          FloatingActionButton(
            heroTag: 'dossier_fab_main',
            onPressed: _toggleExpand,
            backgroundColor: AppColors.darkerBlue,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }
}