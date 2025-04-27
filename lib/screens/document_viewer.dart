import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
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
  Uint8List? _decryptedPdfData;

  // Chave AES (deve corresponder à usada no InfoConfirmationScreen)
  static final _aesKey = encrypt.Key.fromUtf8('16bytessecretkey');
  static final _aesIv = encrypt.IV.fromUtf8('16bytesiv1234567'); // Atualizado para corresponder ao IV

  @override
  void initState() {
    super.initState();
    _decryptAndSavePdf();
  }

  Future<void> _decryptAndSavePdf() async {
    try {
      print('DocumentViewerScreen: Iniciando descriptografia para documentId: ${widget.documentId}');
      print('DocumentViewerScreen: Tamanho do fileDataPrint: ${widget.fileDataPrint.length} bytes');

      // Verificar se fileDataPrint está vazio ou muito pequeno
      if (widget.fileDataPrint.isEmpty) {
        throw Exception('fileDataPrint está vazio');
      }
      if (widget.fileDataPrint.length < 16) {
        throw Exception('fileDataPrint muito pequeno para descriptografia AES (${widget.fileDataPrint.length} bytes)');
      }

      // Descriptografar o PDF
      final encrypter = encrypt.Encrypter(encrypt.AES(_aesKey, mode: encrypt.AESMode.cbc));
      final encrypted = encrypt.Encrypted(widget.fileDataPrint);
      final decryptedBytes = encrypter.decryptBytes(encrypted, iv: _aesIv); // Retorna List<int>
      _decryptedPdfData = Uint8List.fromList(decryptedBytes); // Converter para Uint8List
      print('DocumentViewerScreen: PDF descriptografado, tamanho: ${_decryptedPdfData!.length} bytes');

      // Verificar se o PDF descriptografado parece válido (%PDF-1.4 ou similar no início)
      if (_decryptedPdfData!.length >= 5) {
        final header = String.fromCharCodes(_decryptedPdfData!.sublist(0, 5));
        print('DocumentViewerScreen: Cabeçalho do PDF descriptografado: $header');
        if (!header.startsWith('%PDF-')) {
          throw Exception('Arquivo descriptografado não é um PDF válido (cabeçalho: $header)');
        }
      } else {
        throw Exception('PDF descriptografado muito pequeno (${_decryptedPdfData!.length} bytes)');
      }

      // Salvar o PDF descriptografado como arquivo temporário
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/document_${widget.documentId}.pdf');
      await file.writeAsBytes(_decryptedPdfData!);
      print('DocumentViewerScreen: PDF descriptografado salvo em ${file.path}');

      setState(() {
        _pdfPath = file.path;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('DocumentViewerScreen: Erro ao descriptografar ou salvar PDF: $e');
      print('Stack trace: $stackTrace');
      Future.microtask(() {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao carregar o PDF: $e')),
          );
        }
      });
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sharePdf() async {
    if (_pdfPath == null || _decryptedPdfData == null) {
      print('DocumentViewerScreen: PDF não carregado para compartilhamento');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF não está carregado')),
      );
      return;
    }
    try {
      print('DocumentViewerScreen: Compartilhando PDF: $_pdfPath');
      await Share.shareXFiles(
        [XFile(_pdfPath!, mimeType: 'application/pdf')],
        subject: widget.documentName,
      );
    } catch (e, stackTrace) {
      print('DocumentViewerScreen: Erro ao compartilhar PDF: $e');
      print('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao compartilhar: $e')),
      );
    }
  }

  Future<void> _printPdf() async {
    if (_decryptedPdfData == null) {
      print('DocumentViewerScreen: PDF não carregado para impressão');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF não está carregado')),
      );
      return;
    }
    try {
      print('DocumentViewerScreen: Iniciando impressão do PDF');
      await Printing.layoutPdf(
        onLayout: (_) => _decryptedPdfData!,
        name: widget.documentName,
      );
      print('DocumentViewerScreen: Impressão concluída');
    } catch (e, stackTrace) {
      print('DocumentViewerScreen: Erro ao imprimir PDF: $e');
      print('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao imprimir: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.documentName,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.darkerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _sharePdf,
            tooltip: 'Compartilhar',
          ),
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: _printPdf,
            tooltip: 'Imprimir',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pdfPath == null
          ? const Center(child: Text('Erro ao carregar o PDF'))
          : PDFView(
        filePath: _pdfPath!,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        onError: (error) {
          print('DocumentViewerScreen: Erro no PDFView: $error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao exibir o PDF: $error')),
          );
        },
        onRender: (pages) {
          print('DocumentViewerScreen: PDF renderizado com $pages páginas');
        },
        onPageChanged: (page, total) {
          print('DocumentViewerScreen: Página alterada: $page/$total');
        },
      ),
    );
  }
}