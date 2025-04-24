import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as imge;
import 'package:path_provider/path_provider.dart';
import '../services/DocScanner.dart';

class InfoConfirmationScreen extends StatefulWidget {
  final List<XFile> imagesList;

  const InfoConfirmationScreen({required this.imagesList, super.key});

  @override
  _InfoConfirmationScreenState createState() => _InfoConfirmationScreenState();
}

class _InfoConfirmationScreenState extends State<InfoConfirmationScreen> {
  List<String> _extractedTextsList = [];
  List<String> _extractedAlertsList = [];
  String text = "carta";
  List<int>? coords = [];
  double? angle;
  DocScanner? ds;
  String inferredDocTypeName = 'Tipo não detectado';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _processImages();
    await _initDocumentScanner();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initDocumentScanner() async {
    if (widget.imagesList.isNotEmpty) {
      XFile image = widget.imagesList[0];
      inferredDocTypeName = await _inferDocTypeName(image);
      ds = await DocScanner.create(File(image.path));
      coords = await ds!.getTextAreaCoordinates();
      angle = await ds!.getMostFreqAngle();
    }
  }

  Future<String> _inferDocTypeName(XFile xFileImg) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/docs_texts_map.txt';
    final file = File(filePath);

    List<String> existingLines = [];
    if (await file.exists()) {
      existingLines = await file.readAsLines();
    }

    final textRecognizer = TextRecognizer();
    final inputImage = InputImage.fromFilePath(xFileImg.path);
    final recognizedText = await textRecognizer.processImage(inputImage);
    textRecognizer.close();

    final imageBytes = await xFileImg.readAsBytes();
    final image = imge.decodeImage(imageBytes)!;
    final imageWidth = image.width;
    final imageHeight = image.height;

    final docTypesScore = <String, double>{};

    for (var line in existingLines) {
      String docTypeName = line.split(":")[0];
      List<String> wordsAndCoords = line.split(":")[1].split("|");
      for (String wc in wordsAndCoords) {
        List<String> types = wc.split(";");
        for (String type in types) {
          List<String> parts = type.split("-");
          String docText = parts[0];
          List<double> coords = parts[1].split(",").map(double.parse).toList();

          double xTopLeft = coords[0] * imageWidth;
          double yTopLeft = coords[1] * imageHeight;
          double xBottomRight = coords[2] * imageWidth;
          double yBottomRight = coords[3] * imageHeight;

          double score = _getTextIntersectionScore(
            recognizedText,
            docText,
            xTopLeft,
            yTopLeft,
            xBottomRight,
            yBottomRight,
          );

          if (score > 0) {
            print("Score para $docText em $docTypeName: $score");
            docTypesScore[docTypeName] = (docTypesScore[docTypeName] ?? 0) + score;
          }
        }
      }
    }

    String inferredDocText = 'Nome não detectado';
    double maxScore = 0;
    docTypesScore.forEach((key, value) {
      if (value > maxScore) {
        maxScore = value;
        inferredDocText = key;
      }
    });

    return inferredDocText;
  }

  double _getTextIntersectionScore(
      RecognizedText recognizedText,
      String targetText,
      double xTopLeftAbs,
      double yTopLeftAbs,
      double xBottomRightAbs,
      double yBottomRightAbs,
      ) {
    final targetRect = math.Rectangle<double>(
      xTopLeftAbs,
      yTopLeftAbs,
      xBottomRightAbs - xTopLeftAbs,
      yBottomRightAbs - yTopLeftAbs,
    );

    double bestScore = 0;

    for (var block in recognizedText.blocks) {
      for (var line in block.lines) {
        for (var element in line.elements) {
          if (element.boundingBox != null) {
            final boundingBox = element.boundingBox!;
            final textRect = math.Rectangle<double>(
              boundingBox.left,
              boundingBox.top,
              boundingBox.width,
              boundingBox.height,
            );

            if (targetRect.intersects(textRect)) {
              final intersection = targetRect.intersection(textRect);
              if (intersection != null) {
                double intersectionArea = intersection.width * intersection.height;
                double textRectArea = textRect.width * textRect.height;
                double overlapRatio = intersectionArea / textRectArea;

                if (overlapRatio > 0) {
                  String recognizedTextLower = element.text.toLowerCase();
                  String paramTextLower = targetText.toLowerCase();

                  if (recognizedTextLower.contains(paramTextLower)) {
                    bestScore = math.max(bestScore, 1.0);
                  } else {
                    int lcsLength = _longestCommonSubsequence(recognizedTextLower, paramTextLower);
                    bestScore = math.max(bestScore, lcsLength / paramTextLower.length);
                  }
                }
              }
            }
          }
        }
      }
    }

    return bestScore;
  }

  int _longestCommonSubsequence(String text1, String text2) {
    int m = text1.length;
    int n = text2.length;
    List<List<int>> dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (text1[i - 1] == text2[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1]);
        }
      }
    }

    return dp[m][n];
  }

  Future<void> _processImages() async {
    for (var image in widget.imagesList) {
      // Corrigido: Usar DocumentScanner.create em vez de construtor sem nome
      DocScanner scanner = await DocScanner.create(File(image.path));
      String extractedText = await scanner.extractTextAndNormalise();
      List<DateTime>? futuresDate = extractFutureDate(extractedText);
      String extractedAlert = "";
      if (futuresDate != null && futuresDate.isNotEmpty) {
        for (DateTime dt in futuresDate) {
          extractedAlert += "${dt.day}/${dt.month}/${dt.year}\n";
        }
      } else {
        extractedAlert = "Nenhuma data válida encontrada";
      }

      if (mounted) {
        setState(() {
          _extractedTextsList.add(extractedText);
          _extractedAlertsList.add(extractedAlert);
        });
      }
      scanner.dispose(); // Liberar recursos
    }
  }

  int parseTwoDigitYear(String twoDigits) {
    final currentYear = DateTime.now().year;
    final century = (currentYear ~/ 100) * 100;
    return century + int.parse(twoDigits);
  }

  List<DateTime>? extractFutureDate(String text) {
    List<String> patterns = [
      r'(\d{2})\s*(\d{2})\s*(\d{4})',
      r'(\d{2})\.(\d{2})\.(\d{4})',
      r'(\d{2})\-(\d{2})\-(\d{4})',
      r'(\d{2})\\(\d{2})\\(\d{4})',
      r'(\d{2})\/(\d{2})\/(\d{4})',
      r'(\d{2})\s*(\d{2})\s*(\d{2})',
      r'(\d{2})\.(\d{2})\.(\d{2})',
      r'(\d{2})\-(\d{2})\-(\d{2})',
      r'(\d{2})\\(\d{2})\\(\d{2})',
      r'(\d{2})\/(\d{2})\/(\d{2})',
      r'(\d{2})\s*(\d{4})',
      r'(\d{2})\.(\d{4})',
      r'(\d{2})\-(\d{4})',
      r'(\d{2})\\(\d{4})',
      r'(\d{2})\/(\d{4})',
    ];
    DateTime hoje = DateTime.now().subtract(const Duration(days: 7));
    DateTime limite = hoje.add(const Duration(days: 36500));
    List<DateTime> dates = [];

    for (String pattern in patterns) {
      RegExp regex = RegExp(pattern);
      Iterable<Match> matches = regex.allMatches(text);

      for (var match in matches) {
        int day, month, year;
        if (match.groupCount == 2) {
          day = 1;
          month = int.parse(match.group(1)!);
          final anoRaw = match.group(2)!;
          year = anoRaw.length == 2 ? parseTwoDigitYear(anoRaw) : int.parse(anoRaw);
        } else {
          day = int.parse(match.group(1)!);
          month = int.parse(match.group(2)!);
          final anoRaw = match.group(3)!;
          year = anoRaw.length == 2 ? parseTwoDigitYear(anoRaw) : int.parse(anoRaw);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Confirmação dos dados")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Confirmação dos dados"),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                height: 300,
                color: Colors.black,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.imagesList.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Image.file(
                          File(widget.imagesList[index].path),
                          height: 300,
                          fit: BoxFit.cover,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      "Tipo do documento",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      inferredDocTypeName,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "$text : ${coords ?? 'Não encontrado'}",
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Angle : ${angle ?? 'Não calculado'}",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    ds?.dispose();
    super.dispose();
  }
}