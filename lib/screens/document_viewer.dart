import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../constants/color_app.dart';

class DocumentViewerScreen extends StatefulWidget {
  final int documentId;
  final String documentName;
  final Uint8List fileDataPrint;

  const DocumentViewerScreen({
    Key? key,
    required this.documentId,
    required this.documentName,
    required this.fileDataPrint,
  }) : super(key: key);

  @override
  _DocumentViewerScreenState createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  String? _pdfPath;
  bool _isLoading = true;
  Uint8List? _decryptedData;
  static final Map<int, Uint8List> _cache = {};

  // AES key and IV (must match encryption source)
  static final _aesKey = encrypt.Key.fromUtf8('16bytessecretkey');
  static final _aesIv = encrypt.IV.fromUtf8('16bytesiv1234567');

  @override
  void initState() {
    super.initState();
    _processDocument();
  }

  Future<void> _processDocument() async {
    try {
      if (_cache.containsKey(widget.documentId)) {
        _decryptedData = _cache[widget.documentId];
        await _generatePdf();
        return;
      }

      final encrypter = encrypt.Encrypter(encrypt.AES(_aesKey, mode: encrypt.AESMode.cbc));
      final encrypted = encrypt.Encrypted(widget.fileDataPrint);
      _decryptedData = Uint8List.fromList(encrypter.decryptBytes(encrypted, iv: _aesIv));
      _cache[widget.documentId] = _decryptedData!;

      await _generatePdf();
    } catch (e) {
      print('Erro ao processar documento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao processar documento: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generatePdf() async {
    if (_decryptedData == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final image = img.decodeImage(_decryptedData!);
      if (image == null) {
        await _savePdf(_decryptedData!); // Treat as raw PDF if not an image
        return;
      }

      final pdfData = image.height > image.width
          ? await _createA4Pdf(image)
          : await _createCardPdf(image);

      await _savePdf(pdfData);
    } catch (e) {
      print('Erro ao gerar PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<Uint8List> _createA4Pdf(img.Image image) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: pw.PdfPageFormat.a4.copyWith(
          marginTop: 57.0, // 2 cm at 72 DPI
          marginBottom: 57.0,
          marginLeft: 57.0,
          marginRight: 57.0,
        ),
        build: (pw.Context context) => pw.Container(
          color: pw.PdfColor.fromHex('#F0F0F0'), // Light gray background
          child: pw.Image(pw.MemoryImage(img.encodePng(image)), fit: pw.BoxFit.cover),
        ),
      ),
    );
    return pdf.save();
  }

  Future<Uint8List> _createCardPdf(img.Image image) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: pw.PdfPageFormat.a4.copyWith(
          marginTop: 57.0, // 2 cm at 72 DPI
          marginBottom: 57.0,
          marginLeft: 57.0,
          marginRight: 57.0,
        ),
        build: (pw.Context context) => pw.Container(
          color: pw.PdfColor.fromHex('#F0F0F0'), // Light gray background
          child: pw.Image(
            pw.MemoryImage(img.encodePng(image)),
            width: 300.0, // ~85.6mm at 72 DPI
            height: 180.0, // ~53.98mm at 72 DPI
          ),
        ),
      ),
    );
    return pdf.save();
  }

  Future<void> _savePdf(Uint8List pdfData) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/document_${widget.documentId}.pdf');
      await file.writeAsBytes(pdfData);
      if (mounted) {
        setState(() {
          _pdfPath = file.path;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erro ao salvar PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar PDF: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_pdfPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF não está carregado')));
      return;
    }
    try {
      await Share.shareXFiles([XFile(_pdfPath!, mimeType: 'application/pdf')], subject: widget.documentName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao compartilhar: $e')));
    }
  }

  Future<void> _printPdf() async {
    if (_pdfPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF não está carregado')));
      return;
    }
    try {
      await Printing.layoutPdf(onLayout: (_) => File(_pdfPath!).readAsBytesSync(), name: widget.documentName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao imprimir: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.documentName, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.darkerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pdfPath == null
          ? const Center(child: Text('Erro ao carregar o documento'))
          : PDFView(
        filePath: _pdfPath!,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        onError: (error) {
          print('Erro no PDFView: $error');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao exibir PDF: $error')));
        },
        onRender: (pages) => print('PDF renderizado com $pages páginas'),
        onPageChanged: (page, total) => print('Página alterada: $page/$total'),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: _sharePdf,
            label: const Text('Partilhar', style: TextStyle(color: Colors.white)),
            icon: const Icon(Icons.share, color: Colors.white),
            backgroundColor: AppColors.darkerBlue,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            onPressed: _printPdf,
            label: const Text('Imprimir', style: TextStyle(color: Colors.white)),
            icon: const Icon(Icons.print, color: Colors.white),
            backgroundColor: AppColors.darkerBlue,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}