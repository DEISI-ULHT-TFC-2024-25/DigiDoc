import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as imge;
import 'package:intl/intl.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:encrypt/encrypt.dart' as encrypt;
import '../constants/color_app.dart';
import '../services/DocScanner.dart';
import '../models/DataBaseHelper.dart';

class InfoConfirmationScreen extends StatefulWidget {
  final List<XFile> imagesList;
  final int dossierId;

  const InfoConfirmationScreen({
    required this.imagesList,
    required this.dossierId,
    super.key,
  });

  @override
  _InfoConfirmationScreenState createState() => _InfoConfirmationScreenState();
}

class _InfoConfirmationScreenState extends State<InfoConfirmationScreen> {
  List<String> _extractedTextsList = [];
  List<Alert> _alerts = [];
  DocScanner? ds;
  String? selectedDocType;
  String dateAlertStructure = 'dd mm yyyy';
  String? dateAlertDescription;
  bool _isLoading = true;
  Interpreter? _interpreter;
  List<String> _labels = [];
  List<DocumentType> _docTypes = [];
  final TextEditingController _customDocController = TextEditingController();
  final GlobalKey<FormState> _alertFormKey = GlobalKey<FormState>();
  bool _isCustomDocActive = false;

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
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadTfliteModel();
    await _loadLabels();
    await _loadDocumentTypes();
    await _processImages();
    await _inferDocumentType();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (selectedDocType == null) {
        _showDocumentNotDetectedDialog();
      }
    }
  }

  Future<void> _loadTfliteModel() async {
    try {
      final modelPath = 'assets/model.tflite';
      final exists = await DefaultAssetBundle.of(context)
          .loadString(modelPath)
          .then((_) => true)
          .catchError((_) => false);
      if (!exists) return;
      _interpreter = await Interpreter.fromAsset(modelPath);
    } catch (e) {
      print('Erro ao carregar modelo TFLite: $e');
    }
  }

  Future<void> _loadLabels() async {
    try {
      final labelsPath = 'assets/labels.txt';
      final exists = await DefaultAssetBundle.of(context)
          .loadString(labelsPath)
          .then((_) => true)
          .catchError((_) => false);
      if (!exists) return;
      final labelsData = await DefaultAssetBundle.of(context).loadString(labelsPath);
      _labels = labelsData.split('\n').where((label) => label.isNotEmpty).toList();
    } catch (e) {
      print('Erro ao carregar labels: $e');
    }
  }

  Future<void> _loadDocumentTypes() async {
    try {
      final docsData = await DefaultAssetBundle.of(context).loadString('assets/defaultDocs.txt');
      _docTypes = docsData.split('\n').where((line) => line.isNotEmpty).map((line) {
        try {
          final parts = line.split(':');
          if (parts.length < 2) throw FormatException('Formato inválido: $line');
          final name = parts[0].trim();
          final rest = parts[1].split(';');
          if (rest.length < 2) throw FormatException('Formato inválido: $line');
          final keywords = rest[0].split(',').map((k) => k.trim().toLowerCase()).toList();
          final dateStructure = rest[1].split(',')[0].trim();
          final alertDescription = rest[1].split(',')[1].trim();
          return DocumentType(
            name: name,
            keywords: keywords,
            dateStructure: dateStructure,
            alertDescription: alertDescription,
          );
        } catch (e) {
          print('Erro ao processar linha de defaultDocs.txt: $e');
          return null;
        }
      }).whereType<DocumentType>().toList();
      _docTypes = _docTypes.toSet().toList();
      if (mounted) setState(() {});
    } catch (e) {
      print('Erro ao carregar tipos de documento: $e');
    }
  }

  Future<void> _processImages() async {
    _extractedTextsList.clear();
    for (var image in widget.imagesList) {
      DocScanner scanner = await DocScanner.create(File(image.path));
      String extractedText = await scanner.extractTextAndNormalise();
      _extractedTextsList.add(extractedText);
      scanner.dispose();
    }
  }

  Future<void> _inferDocumentType() async {
    if (widget.imagesList.isEmpty) {
      selectedDocType = null;
      return;
    }

    final image = widget.imagesList[0];
    ds = await DocScanner.create(File(image.path));
    final normalizedText = await ds!.extractTextAndNormalise();

    if (_interpreter == null || _labels.isEmpty) {
      selectedDocType = await _inferByKeywords(normalizedText);
      return;
    }

    try {
      final imageBytes = await image.readAsBytes();
      final imge.Image? imageDecoded = imge.decodeImage(imageBytes);
      if (imageDecoded == null) {
        selectedDocType = await _inferByKeywords(normalizedText);
        return;
      }

      final resizedImage = imge.copyResize(imageDecoded, width: 224, height: 224);
      final input = Float32List(224 * 224 * 3);
      int pixelIndex = 0;
      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resizedImage.getPixel(x, y);
          input[pixelIndex++] = pixel.r / 255.0;
          input[pixelIndex++] = pixel.g / 255.0;
          input[pixelIndex++] = pixel.b / 255.0;
        }
      }

      final output = Float32List(_labels.length);
      _interpreter!.run(input.reshape([1, 224, 224, 3]), output);

      double maxConfidence = -1;
      int maxIndex = -1;
      for (int i = 0; i < output.length; i++) {
        if (output[i] > maxConfidence) {
          maxConfidence = output[i];
          maxIndex = i;
        }
      }

      if (maxIndex < 0 || maxIndex >= _labels.length || maxConfidence < 0.1) {
        selectedDocType = await _inferByKeywords(normalizedText);
        return;
      }

      String predictedType = _labels[maxIndex];
      final docType = _docTypes.firstWhere(
            (d) => d.name.toLowerCase() == predictedType.toLowerCase(),
        orElse: () => DocumentType(
          name: 'Nome não detectado',
          keywords: [],
          dateStructure: 'dd mm yyyy',
          alertDescription: 'Nenhum alerta',
        ),
      );

      if (docType.name == 'Nome não detectado') {
        selectedDocType = await _inferByKeywords(normalizedText);
        return;
      }

      int matchedKeywords = docType.keywords
          .where((keyword) => normalizedText.toLowerCase().contains(keyword))
          .length;
      double matchPercentage = docType.keywords.isEmpty ? 0 : matchedKeywords / docType.keywords.length;

      if (matchPercentage >= 0.1) {
        selectedDocType = docType.name;
        dateAlertStructure = docType.dateStructure;
        dateAlertDescription = docType.alertDescription;
      } else {
        selectedDocType = await _inferByKeywords(normalizedText);
      }
    } catch (e) {
      print('Erro ao inferir tipo de documento: $e');
      selectedDocType = await _inferByKeywords(normalizedText);
    }
  }

  Future<String?> _inferByKeywords(String normalizedText) async {
    if (normalizedText.isEmpty || _docTypes.isEmpty) {
      return null;
    }

    String? bestMatch;
    double bestScore = -1;

    for (var docType in _docTypes) {
      int matchedKeywords = docType.keywords
          .where((keyword) => normalizedText.toLowerCase().contains(keyword))
          .length;
      double score = docType.keywords.isEmpty ? 0 : matchedKeywords / docType.keywords.length;
      if (score > bestScore) {
        bestScore = score;
        bestMatch = docType.name;
      }
    }

    if (bestScore >= 0.1 && bestMatch != null) {
      final docType = _docTypes.firstWhere((d) => d.name == bestMatch);
      dateAlertStructure = docType.dateStructure;
      dateAlertDescription = docType.alertDescription;
      return bestMatch;
    }
    return null;
  }

  void _showDocumentNotDetectedDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Documento Não Detectado'),
          content: const Text('Nenhum tipo de documento foi identificado automaticamente. Deseja continuar e selecionar manualmente?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Continuar'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkerBlue),
            ),
          ],
        );
      },
    );
  }

  List<DateTime>? extractFutureDate(String text, String dateStructure) {
    final patterns = {
      'dd mm yyyy': [
        r'(\d{2})\s*(\d{2})\s*(\d{4})',
        r'(\d{2})\.(\d{2})\.(\d{4})',
        r'(\d{2})\-(\d{2})\-(\d{4})',
        r'(\d{2})\/(\d{2})\/(\d{4})',
      ],
      'dd-mm-yyyy': [
        r'(\d{2})\-(\d{2})\-(\d{4})',
        r'(\d{2})\/(\d{2})\/(\d{4})',
      ],
      'dd/mm/yyyy': [
        r'(\d{2})\/(\d{2})\/(\d{4})',
        r'(\d{2})\-(\d{2})\-(\d{4})',
      ],
      'mm/yyyy': [
        r'(\d{2})\s*(\d{4})',
        r'(\d{2})\/(\d{4})',
        r'(\d{2})\-(\d{4})',
      ],
    };

    final selectedPatterns = patterns[dateStructure] ?? patterns['dd mm yyyy']!;
    DateTime hoje = DateTime.now().subtract(const Duration(days: 7));
    DateTime limite = hoje.add(const Duration(days: 36500));
    List<DateTime> dates = [];

    for (String pattern in selectedPatterns) {
      RegExp regex = RegExp(pattern);
      Iterable<Match> matches = regex.allMatches(text);

      for (var match in matches) {
        int day, month, year;
        if (dateStructure == 'mm/yyyy') {
          day = 1;
          month = int.parse(match.group(1)!);
          year = int.parse(match.group(2)!);
        } else {
          day = int.parse(match.group(1)!);
          month = int.parse(match.group(2)!);
          year = int.parse(match.group(3)!);
        }
        try {
          DateTime date = DateTime(year, month, day);
          if (date.isAfter(hoje) && date.isBefore(limite)) {
            dates.add(date);
          }
        } catch (e) {
          continue;
        }
      }
    }

    return dates.isNotEmpty ? dates : null;
  }

  void _addOrEditAlert({Alert? existingAlert, int? index}) {
    final dateController = TextEditingController(
      text: existingAlert != null
          ? DateFormat('dd/MM/yyyy', 'pt_PT').format(existingAlert.date)
          : '',
    );
    final timeController = TextEditingController(
      text: existingAlert != null
          ? existingAlert.time.format(context)
          : TimeOfDay.now().format(context),
    );
    final descController = TextEditingController(
      text: existingAlert?.description ?? dateAlertDescription ?? 'Sem descrição',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(existingAlert == null ? 'Adicionar Alerta' : 'Editar Alerta'),
          content: Form(
            key: _alertFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Data (dd/mm/aaaa)',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: dialogContext,
                        initialDate: existingAlert?.date ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        locale: const Locale('pt', 'PT'),
                        builder: (BuildContext context, Widget? child) {
                          return Theme(
                            data: Theme.of(dialogContext).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppColors.darkerBlue,
                                onPrimary: Colors.white,
                                onSurface: Colors.black,
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.darkerBlue,
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
                    decoration: const InputDecoration(
                      labelText: 'Hora',
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final pickedTime = await showTimePicker(
                        context: dialogContext,
                        initialTime: existingAlert?.time ?? TimeOfDay.now(),
                        builder: (BuildContext context, Widget? child) {
                          return Theme(
                            data: Theme.of(dialogContext).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppColors.darkerBlue,
                                onPrimary: Colors.white,
                                onSurface: Colors.black,
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.darkerBlue,
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
                    decoration: const InputDecoration(labelText: 'Descrição'),
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_alertFormKey.currentState!.validate()) {
                  final date = DateFormat('dd/MM/yyyy', 'pt_PT').parseStrict(dateController.text);
                  final time = TimeOfDay.fromDateTime(
                    DateFormat.jm('pt_PT').parse(timeController.text),
                  );
                  final alert = Alert(
                    date: DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    ),
                    time: time,
                    description: descController.text,
                  );
                  setState(() {
                    if (index != null) {
                      _alerts[index] = alert;
                    } else {
                      _alerts.add(alert);
                    }
                  });
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Salvar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkerBlue,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Uint8List> _convertImagesToPdf(List<XFile> images) async {
    final pdf = pw.Document();
    for (var image in images) {
      final imageData = await image.readAsBytes();
      final imageDecoded = imge.decodeImage(imageData);
      if (imageDecoded == null) {
        throw Exception('Falha ao decodificar a imagem para PDF');
      }
      final resized = imge.copyResize(imageDecoded, width: 800);
      final resizedData = imge.encodeJpg(resized, quality: 85);
      final pdfImage = pw.MemoryImage(resizedData);
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(
            child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    return await pdf.save();
  }

  Future<Uint8List> _encryptPdfData(Uint8List pdfData) async {
    final aesKey = encrypt.Key.fromUtf8('16bytessecretkey');
    final aesIv = encrypt.IV.fromUtf8('16bytesiv1234567');
    final encrypter = encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(pdfData, iv: aesIv);
    return encrypted.bytes;
  }

  Future<Uint8List> _compressImage(Uint8List imageData) async {
    final image = imge.decodeImage(imageData);
    if (image == null) {
      throw Exception('Falha ao decodificar imagem para compressão');
    }
    final resized = imge.copyResize(image, width: 800);
    return imge.encodeJpg(resized, quality: 85);
  }

  Future<void> _saveDocument() async {
    setState(() {
      _isLoading = true;
    });
    try {
      if (!mounted) return;
      if (widget.dossierId <= 0) {
        throw Exception('Invalid dossierId: ${widget.dossierId}');
      }
      if (selectedDocType == null || selectedDocType!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione um tipo de documento')),
        );
        return;
      }

      final db = await DataBaseHelper.instance.database;
      final dossierExists = await db.query(
        'Dossier',
        where: 'dossier_id = ?',
        whereArgs: [widget.dossierId],
      );
      if (dossierExists.isEmpty) {
        throw Exception('Dossiê com ID ${widget.dossierId} não existe');
      }

      final firstImage = widget.imagesList[0];
      var fileData = await firstImage.readAsBytes();
      fileData = await _compressImage(fileData);

      final pdfData = await _convertImagesToPdf(widget.imagesList);
      final encryptedPdfData = await _encryptPdfData(pdfData);

      final extractedText = _extractedTextsList.join('\n');

      final documentId = await DataBaseHelper.instance.insertDocument(
        selectedDocType!,
        fileData,
        encryptedPdfData,
        extractedText,
        widget.dossierId,
      );

      for (String text in _extractedTextsList) {
        await DataBaseHelper.instance.insertImage(documentId, text);
      }

      for (var alert in _alerts) {
        final alertDate = DateTime(
          alert.date.year,
          alert.date.month,
          alert.date.day,
          alert.time.hour,
          alert.time.minute,
        );
        await DataBaseHelper.instance.insertAlert(
          alert.description,
          alertDate,
          documentId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento salvo com sucesso!')),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar documento: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _isSaveButtonEnabled {
    return selectedDocType != null && selectedDocType!.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final dropdownItems = [
      ..._docTypes.map((docType) => DropdownMenuItem<String>(
        value: docType.name,
        child: Text(docType.name),
      )),
      const DropdownMenuItem<String>(
        value: 'Outro',
        child: Text('Outro'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmação dos Dados', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.darkerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Container(
                height: 300,
                color: Colors.white,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(widget.imagesList.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.file(
                          File(widget.imagesList[index].path),
                          height: 280,
                          fit: BoxFit.contain,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tipo do Documento',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkerBlue,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedDocType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Selecione o tipo de documento',
              ),
              items: dropdownItems,
              onChanged: (value) {
                setState(() {
                  selectedDocType = value;
                  _isCustomDocActive = value == 'Outro';
                  if (value != 'Outro') {
                    _customDocController.clear();
                    final docType = _docTypes.firstWhere(
                          (d) => d.name == value,
                      orElse: () => DocumentType(
                        name: 'Nome não detectado',
                        keywords: [],
                        dateStructure: 'dd mm yyyy',
                        alertDescription: 'Nenhum alerta',
                      ),
                    );
                    dateAlertStructure = docType.dateStructure;
                    dateAlertDescription = docType.alertDescription;
                  } else {
                    dateAlertStructure = 'dd mm yyyy';
                    dateAlertDescription = 'Nenhum alerta';
                  }
                });
              },
              isExpanded: true,
            ),
            if (_isCustomDocActive) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _customDocController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Nome do documento personalizado',
                ),
                onChanged: (value) {
                  setState(() {
                    selectedDocType = value.isNotEmpty ? value : 'Outro';
                  });
                },
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Alertas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkerBlue,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _addOrEditAlert(),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Adicionar Alerta', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkerBlue),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _alerts.isEmpty
                ? const Text(
              'Nenhum alerta adicionado.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _alerts.length,
              itemBuilder: (context, index) {
                final alert = _alerts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                    title: Text(
                      '${DateFormat('dd/MM/yyyy', 'pt_PT').format(alert.date)} às ${alert.time.format(context)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(alert.description),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppColors.darkerBlue),
                          onPressed: () => _addOrEditAlert(existingAlert: alert, index: index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: AppColors.darkerBlue),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirmar Exclusão'),
                                content: const Text('Deseja excluir este alerta?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _alerts.removeAt(index);
                                      });
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Excluir'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.darkerBlue,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _isSaveButtonEnabled ? _saveDocument : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkerBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text(
                  'Guardar',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    ds?.dispose();
    _interpreter?.close();
    _customDocController.dispose();
    super.dispose();
  }
}

class DocumentType {
  final String name;
  final List<String> keywords;
  final String dateStructure;
  final String alertDescription;

  DocumentType({
    required this.name,
    required this.keywords,
    required this.dateStructure,
    required this.alertDescription,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is DocumentType && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

class Alert {
  final DateTime date;
  final TimeOfDay time;
  final String description;

  Alert({
    required this.date,
    required this.time,
    required this.description,
  });
}