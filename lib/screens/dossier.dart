import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/color_app.dart';
import '../models/data_base_helper.dart';
import 'capture_document_photo.dart';
import 'upload_document.dart';
import 'document_viewer.dart';


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
  final GlobalKey<FormState> _alertFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.dossierId <= 0) {
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
    try {
      if (_documentsCache.containsKey(widget.dossierId)) {
        setState(() {
          documents = _documentsCache[widget.dossierId]!;
          filteredDocuments = documents;
          _isLoading = false;
        });
        return;
      }

      final docs = await DataBaseHelper.instance.getDocuments(widget.dossierId);
      setState(() {
        documents = docs;
        filteredDocuments = docs;
        _documentsCache[widget.dossierId] = docs;
        _isLoading = false;
      });
    } catch (e) {
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
      return;
    }

    try {
      final results = await DataBaseHelper.instance.searchDocumentsByText(widget.dossierId, query);
      setState(() {
        filteredDocuments = results.map((doc) {
          final originalDoc = documents.firstWhere((d) => d['document_id'] == doc['document_id'], orElse: () => {});
          return {
            ...doc,
            'file_data': originalDoc['file_data'],
          };
        }).toList();
      });
    } catch (e) {
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
    DateTime? farthestDate;
    for (var alert in alerts) {
      final alertDate = DateTime.parse(alert['date'] as String);
      if (alert['is_active'] == 1 && (farthestDate == null || alertDate.isAfter(farthestDate))) {
        farthestDate = alertDate;
      }
    }

    if (farthestDate == null) return Colors.grey;
    final daysUntilDue = farthestDate.difference(now).inDays;

    if (now.isAfter(farthestDate)) {
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCardBackground
            : AppColors.cardBackground,
        title: Text(
          'Editar Nome do Documento',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            labelText: 'Nome do Documento',
            labelStyle: GoogleFonts.poppins(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkCardBackground.withAlpha(240)
                : AppColors.cardBackground,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.calmWhite
                    : AppColors.primaryGradientStart,
              ),
            ),
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
            child: Text(
              'Salvar',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkPrimaryGradientStart
                  : AppColors.primaryGradientStart,
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCardBackground
            : AppColors.cardBackground,
        title: Text(
          'Confirmar Exclusão',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Deseja excluir este documento? Esta ação não pode ser desfeita.',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.calmWhite
                    : AppColors.primaryGradientStart,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Excluir',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
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

  Future<void> _addNewAlert(int documentId) async {
    final dateController = TextEditingController();
    final timeController = TextEditingController(text: TimeOfDay.now().format(context));
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCardBackground
            : AppColors.cardBackground,
        title: Text(
          'Adicionar Alerta',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
          ),
        ),
        content: Form(
          key: _alertFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: dateController,
                  decoration: InputDecoration(
                    labelText: 'Data (dd/mm/aaaa)',
                    labelStyle: GoogleFonts.poppins(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                    suffixIcon: Icon(
                      Icons.calendar_today,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.calmWhite
                          : AppColors.primaryGradientStart,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkCardBackground.withAlpha(240)
                        : AppColors.cardBackground,
                    border: const OutlineInputBorder(),
                  ),
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                  readOnly: true,
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      locale: const Locale('pt', 'PT'),
                      builder: (BuildContext context, Widget? child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: Theme.of(context).brightness == Brightness.dark
                                ? const ColorScheme.dark(
                              primary: AppColors.darkPrimaryGradientStart,
                              onPrimary: AppColors.darkTextPrimary,
                              onSurface: AppColors.darkTextPrimary,
                            )
                                : const ColorScheme.light(
                              primary: AppColors.primaryGradientStart,
                              onPrimary: Colors.white,
                              onSurface: Colors.black,
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.darkPrimaryGradientStart
                                    : AppColors.primaryGradientStart,
                              ),
                            ),
                          ),
                          child: Material(
                            child: child,
                          ),
                        );
                      },
                    );
                    if (pickedDate != null) {
                      dateController.text = DateFormat('dd/MM/yyyy', 'pt_PT').format(pickedDate);
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Selecione uma data';
                    try {
                      DateFormat('dd/MM/yyyy', 'pt_PT').parseStrict(value);
                      return null;
                    } catch (e) {
                      return 'Formato inválido (use dd/mm/aaaa)';
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: timeController,
                  decoration: InputDecoration(
                    labelText: 'Hora',
                    labelStyle: GoogleFonts.poppins(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                    suffixIcon: Icon(
                      Icons.access_time,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.calmWhite
                          : AppColors.primaryGradientStart,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkCardBackground.withAlpha(240)
                        : AppColors.cardBackground,
                    border: const OutlineInputBorder(),
                  ),
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                  readOnly: true,
                  onTap: () async {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                      builder: (BuildContext context, Widget? child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: Theme.of(context).brightness == Brightness.dark
                                ? const ColorScheme.dark(
                              primary: AppColors.darkPrimaryGradientStart,
                              onPrimary: AppColors.darkTextPrimary,
                              onSurface: AppColors.darkTextPrimary,
                            )
                                : const ColorScheme.light(
                              primary: AppColors.primaryGradientStart,
                              onPrimary: Colors.white,
                              onSurface: Colors.black,
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.darkPrimaryGradientStart
                                    : AppColors.primaryGradientStart,
                              ),
                            ),
                          ),
                          child: Material(
                            child: child,
                          ),
                        );
                      },
                    );
                    if (pickedTime != null) {
                      timeController.text = pickedTime.format(context);
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Selecione uma hora';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'Descrição',
                    labelStyle: GoogleFonts.poppins(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkCardBackground.withAlpha(240)
                        : AppColors.cardBackground,
                    border: const OutlineInputBorder(),
                  ),
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Insira uma descrição';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.calmWhite
                    : AppColors.primaryGradientStart,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_alertFormKey.currentState!.validate()) {
                final date = DateFormat('dd/MM/yyyy', 'pt_PT').parseStrict(dateController.text);
                final time = TimeOfDay.fromDateTime(
                  DateFormat.jm('pt_PT').parse(timeController.text),
                );
                final alertDate = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
                DataBaseHelper.instance.insertAlert(
                  descController.text,
                  alertDate,
                  documentId,
                ).then((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alerta adicionado com sucesso!')),
                  );
                  Navigator.pop(context, true);
                }).catchError((e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao adicionar alerta: $e')),
                  );
                });
              }
            },
            child: Text(
              'Salvar',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkPrimaryGradientStart
                  : AppColors.primaryGradientStart,
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {});
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
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.calmWhite,
          ),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkPrimaryGradientStart.withAlpha(250)
            : AppColors.primaryGradientStart,
        iconTheme: IconThemeData(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkTextPrimary
              : AppColors.calmWhite,
        ),
        centerTitle: true,
      ),
      body: Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkBackground
            : AppColors.background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por palavras-chave',
                    hintStyle: GoogleFonts.poppins(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.calmWhite
                          : AppColors.primaryGradientStart,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkCardBackground.withAlpha(240)
                        : AppColors.cardBackground,
                  ),
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Documentos Salvos',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.primaryGradientStart,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _isLoading
                      ? Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkPrimaryGradientStart
                          : AppColors.primaryGradientStart,
                    ),
                  )
                      : filteredDocuments.isEmpty
                      ? Center(
                    child: Text(
                      'Nenhum documento encontrado.',
                      style: GoogleFonts.poppins(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  )
                      : ListView.builder(
                    itemCount: filteredDocuments.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocuments[index];
                      final docTypeName = doc['document_type_name'] as String? ?? 'Não Definido';
                      final docName = doc['document_name'] as String? ?? 'Sem Nome';
                      final createdAt = doc['created_at'] != null
                          ? DateFormat('dd/MM/yyyy', 'pt_BR').format(DateTime.parse(doc['created_at']))
                          : 'Sem Data';
                      final thumbnailData = doc['file_data'] as Uint8List?;

                      return InkWell(
                        onTap: () async {
                          final fileData = await DataBaseHelper.instance.getDocumentFileData(doc['document_id']);
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
                          elevation: 2,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkCardBackground
                              : AppColors.cardBackground,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Stack(
                            children: [
                              Padding(
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
                                            ? DecorationImage(image: MemoryImage(thumbnailData), fit: BoxFit.cover)
                                            : null,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? AppColors.darkBackground
                                            : AppColors.background,
                                      ),
                                      child: thumbnailData == null
                                          ? Icon(
                                        Icons.insert_drive_file,
                                        size: 40,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.textSecondary,
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
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? AppColors.darkTextPrimary
                                                  : AppColors.textPrimary,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          FutureBuilder<Map<String, dynamic>>(
                                            future: _getDocumentDetails(doc['document_id']),
                                            builder: (context, snapshot) {
                                              if (!snapshot.hasData) {
                                                return const Text('Carregando...');
                                              }
                                              final details = snapshot.data!;
                                              final alertCount = details['alertCount'] as int;
                                              final imageCount = details['imageCount'] as int;

                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Alertas: $alertCount',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      color: Theme.of(context).brightness == Brightness.dark
                                                          ? AppColors.darkTextSecondary
                                                          : AppColors.textSecondary,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Criado em: $createdAt',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      color: Theme.of(context).brightness == Brightness.dark
                                                          ? AppColors.darkTextSecondary
                                                          : AppColors.textSecondary,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Páginas: $imageCount',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      color: Theme.of(context).brightness == Brightness.dark
                                                          ? AppColors.darkTextSecondary
                                                          : AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons.edit,
                                                  size: 20,
                                                  color: Theme.of(context).brightness == Brightness.dark
                                                      ? AppColors.calmWhite
                                                      : AppColors.primaryGradientStart,
                                                ),
                                                onPressed: () => _editDocumentName(doc['document_id'], docName),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.add_alert,
                                                  size: 20,
                                                  color: Theme.of(context).brightness == Brightness.dark
                                                      ? AppColors.calmWhite
                                                      : AppColors.primaryGradientStart,
                                                ),
                                                onPressed: () => _addNewAlert(doc['document_id']),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.delete,
                                                  size: 20,
                                                  color: Theme.of(context).brightness == Brightness.dark
                                                      ? AppColors.calmWhite
                                                      : AppColors.primaryGradientStart,
                                                ),
                                                onPressed: () => _deleteDocument(doc['document_id']),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 8,
                                bottom: 8,
                                child: FutureBuilder<Map<String, dynamic>>(
                                  future: _getDocumentDetails(doc['document_id']),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const SizedBox.shrink();
                                    }
                                    final details = snapshot.data!;
                                    final farthestDate = details['farthestDate'] as DateTime?;
                                    final statusColor = details['statusColor'] as Color;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? AppColors.darkCardBackground
                                            : AppColors.cardBackground,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            margin: const EdgeInsets.only(right: 4),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: statusColor,
                                            ),
                                          ),
                                          Text(
                                            farthestDate != null
                                                ? DateFormat('dd/MM/yyyy', 'pt_BR').format(farthestDate)
                                                : 'Sem Alerta(s)',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? AppColors.darkTextSecondary
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
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
                style: GoogleFonts.poppins(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.primaryGradientStart,
                  fontSize: 12,
                ),
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
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkPrimaryGradientStart
                    : AppColors.primaryGradientStart,
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
                style: GoogleFonts.poppins(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.primaryGradientStart,
                  fontSize: 12,
                ),
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
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkPrimaryGradientStart
                    : AppColors.primaryGradientStart,
                child: const Icon(Icons.camera_alt_outlined, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FloatingActionButton(
            heroTag: 'dossier_fab_main',
            onPressed: _toggleExpand,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkPrimaryGradientStart
                : AppColors.primaryGradientStart,
            child: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      )
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Adicionar\nDocumento',
            style: GoogleFonts.poppins(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextPrimary
                  : AppColors.primaryGradientStart,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          FloatingActionButton(
            heroTag: 'dossier_fab_main',
            onPressed: _toggleExpand,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkPrimaryGradientStart
                : AppColors.primaryGradientStart,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  Future<Map<String, dynamic>> _getDocumentDetails(int documentId) async {
    final alerts = await DataBaseHelper.instance.getAlertsForDocument(documentId);
    final alertCount = alerts.length;
    final now = DateTime.now();
    DateTime? farthestDate;
    Color statusColor = Colors.grey;

    if (alerts.isNotEmpty) {
      for (var alert in alerts) {
        final alertDate = DateTime.parse(alert['date'] as String);
        if (alert['is_active'] == 1 && (farthestDate == null || alertDate.isAfter(farthestDate))) {
          farthestDate = alertDate;
        }
      }
      if (farthestDate != null) {
        final daysUntilDue = farthestDate.difference(now).inDays;
        statusColor = now.isAfter(farthestDate)
            ? Colors.red
            : daysUntilDue <= 7
            ? Colors.yellow
            : Colors.green;
      }
    }

    // Placeholder for image count - replace with actual logic
    final imageCount = await _getImageCount(documentId); // Hypothetical method

    return {
      'alertCount': alertCount,
      'imageCount': imageCount,
      'farthestDate': farthestDate,
      'statusColor': statusColor,
    };
  }


  Future<int> _getImageCount(int documentId) async {
    try {
      final imageCount = await DataBaseHelper.instance.getImageCountForDocument(documentId);
      return imageCount ?? 0; // Return 0 if null
    } catch (e) {
      print('Erro ao contar imagens: $e');
      return 0; // Default to 0 on error
    }
  }
}