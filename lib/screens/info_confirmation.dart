import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as imge;
import 'package:path_provider/path_provider.dart';
import '../DocumentScanner.dart';
import '../ExtractedTextBox.dart';

class InfoConfirmationScreen extends StatefulWidget {
  final List<XFile> imagesList;

  InfoConfirmationScreen({required this.imagesList});

  @override
  _InfoConfirmationScreenState createState() => _InfoConfirmationScreenState();
}

class _InfoConfirmationScreenState extends State<InfoConfirmationScreen> {
  List<String> _extractedTextsList = [];
  List<String> _extractedAlertsList = [];
  String text = "carta";
  List<int>? coords = [];
  double? angle;
  late DocumentScanner ds;
  String inferredDocTypeName = 'Tipo nao detetado';

  Future<String> _inferDocTypeName(XFile x_file_img) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/docs_texts_map.txt';
    final file = File(filePath);

    List<String> existingLines = [];
    if (await file.exists()) {
      existingLines = await file.readAsLines();
    }

    final textRecognizer = TextRecognizer();
    final inputImage = InputImage.fromFilePath(x_file_img.path);
    final recognizedText = await textRecognizer.processImage(inputImage);

    final imageBytes = await x_file_img.readAsBytes();
    final image = imge.decodeImage(imageBytes)!;
    final imageWidth = image.width;
    final imageHeight = image.height;

    final docTypesScore = <String, double>{};

    // Processar as linhas do arquivo de mapeamento
    for (var line in existingLines) {
      String docTypeName = line.split(":")[0];
      List<String> wordsAndCoords = line.split(":")[1].split("|");
      for (String wc in wordsAndCoords) {
        List<String> types = wc.split(";");
        for (String type in types) {
          List<String> parts = type.split("-");
          String docText = parts[0];
          List<double> coords = parts[1].split(",").map(double.parse).toList();

          double xTopLeft = coords[0];
          double yTopLeft = coords[1];
          double xBottomRight = coords[2];
          double yBottomRight = coords[3];

          // Convertendo as coordenadas normalizadas para coordenadas absolutas na imagem
          double xTopLeftAbs = xTopLeft * imageWidth;
          double yTopLeftAbs = yTopLeft * imageHeight;
          double xBottomRightAbs = xBottomRight * imageWidth;
          double yBottomRightAbs = yBottomRight * imageHeight;

          // Verifica a interseção e calcula o score
          double score = _getTextIntersectionScore(
            recognizedText,
            docText,
            xTopLeftAbs,
            yTopLeftAbs,
            xBottomRightAbs,
            yBottomRightAbs,
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

    print("GANHEIIIIIIIII");
    if (docTypesScore.isEmpty) {
      print("EMPTY");
    }
    docTypesScore.forEach((key, value) {
      print("key: $key value: $value");
      if (value > maxScore) {
        maxScore = value;
        inferredDocText = key;
      }
    });

    return inferredDocText;
  }

  double _getTextIntersectionScore(
      RecognizedText recognizedText,
      String paramText,
      double xTopLeftAbs,
      double yTopLeftAbs,
      double xBottomRightAbs,
      double yBottomRightAbs,
      )
  {
    // Retângulo da área fornecida como parâmetro
    final paramRect = math.Rectangle<double>(
      xTopLeftAbs,
      yTopLeftAbs,
      xBottomRightAbs - xTopLeftAbs,
      yBottomRightAbs - yTopLeftAbs,
    );

    double bestScore = 0;
    math.Rectangle<double>? bestRect;

    // Itera sobre os retângulos de texto reconhecidos
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

            // Verifica se há interseção
            if (paramRect.intersects(textRect)) {
              // Calcula a área de interseção
              final intersection = paramRect.intersection(textRect);
              if (intersection != null) {
                double intersectionArea = intersection.width * intersection.height;
                double textRectArea = textRect.width * textRect.height;
                double overlapRatio = intersectionArea / textRectArea;

                // Só considera retângulos com interseção significativa
                if (overlapRatio > 0) {
                  if (overlapRatio > bestScore || (overlapRatio == bestScore && textRectArea < (bestRect?.width ?? double.infinity) * (bestRect?.height ?? double.infinity))) {
                    bestScore = overlapRatio;
                    bestRect = textRect;

                    // Calcula o score de correspondência de texto
                    String recognizedTextLower = element.text.toLowerCase();
                    String paramTextLower = paramText.toLowerCase();

                    if (recognizedTextLower.contains(paramTextLower)) {
                      // Score 1 se o texto do parâmetro está completamente contido
                      bestScore = 1.0;
                    } else {
                      // Calcula a maior subsequência comum (LCS - Longest Common Subsequence)
                      int lcsLength = _longestCommonSubsequence(recognizedTextLower, paramTextLower);
                      bestScore = lcsLength / paramTextLower.length;
                    }
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

  @override
  void initState() {
    super.initState();
    _processImages();
    _initScanner();
  }

  Future<void> _initScanner() async {
    XFile image = widget.imagesList[0];
    inferredDocTypeName = await _inferDocTypeName(image);
    ds = await DocumentScanner.create(File(image.path));
    coords = await ds.getTextAreaCoordinates();
    angle = await ds.getMostFreqAngle();
    setState(() {});
  }

  int parseTwoDigitYear(String twoDigits) {
    final currentYear = DateTime.now().year;
    final century = (currentYear ~/ 100) * 100;
    return century + int.parse(twoDigits);
  }

  Future<void> _processImages() async {
    for (var image in widget.imagesList) {
      ExtractedTextBox etb = ExtractedTextBox(image.path);
      await etb.extractText();

      String extractedText = etb.text;
      List<DateTime>? futuresDate = extractFutureDate(extractedText);
      String extractedAlert = "";
      if (futuresDate != null) {
        for (DateTime dt in futuresDate) {
          extractedAlert += "${dt.day}/${dt.month}/${dt.year}\n";
        }
      } else {
        extractedAlert = "Nenhuma data válida encontrada";
      }

      setState(() {
        _extractedTextsList.add(extractedText);
        _extractedAlertsList.add(extractedAlert);
      });
    }
  }

  List<DateTime>? extractFutureDate(String text) {
    List<String> patterns = [
      r'(\d{2})\s*(\d{2})\s*(\d{4})',
      r'(\d{2})\.(\d{2})\.(\d{4})',
      r'(\d{2})\-(\d{2})\-(\d{4})',
      r'(\d{2})\\(\d{2})\\(\d{4})',
      r'(\d{2})\/(\d{2})\/(\d{4})',
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
      r'(\d{2})\s*(\d{2})',
      r'(\d{2})\.(\d{2})',
      r'(\d{2})\-(\d{2})',
      r'(\d{2})\\(\d{2})',
    ];
    DateTime hoje = DateTime.now();
    hoje = hoje.subtract(Duration(days: 7));
    DateTime limite = hoje.add(Duration(days: 36500));
    RegExp regex = RegExp(patterns[0]);
    Iterable<Match> matches = regex.allMatches(text);
    List<DateTime> dates = [];
    for (int i = 1; i < patterns.length; i++) {
      regex = RegExp(patterns[i]);
      matches = regex.allMatches(text);

      DateTime? validDate;
      int day, month, year = 0;
      for (var match in matches) {
        if (match.groupCount == 2) {
          day = 1;
          month = int.parse(match.group(1)!);
          final anoRaw = match.group(2)!;
          year = anoRaw.length == 2
              ? parseTwoDigitYear(anoRaw)
              : int.parse(anoRaw);
        } else {
          day = int.parse(match.group(1)!);
          month = int.parse(match.group(2)!);
          final anoRaw = match.group(2)!;
          year = anoRaw.length == 2
              ? parseTwoDigitYear(anoRaw)
              : int.parse(anoRaw);
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

    return dates;
  }

  String _normalizeText(String text) {
    String normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãäåǎȁȃ]'), 'a')
        .replaceAll(RegExp(r'[éèêẽëėęěȩ]'), 'e')
        .replaceAll(RegExp(r'[íìîĩïıĩīĭ]'), 'i')
        .replaceAll(RegExp(r'[óòôõöȯȱőǒºøǿ]'), 'o')
        .replaceAll(RegExp(r'[úùûũüůűųȕȗ]'), 'u')
        .replaceAll(RegExp(r'[çćĉċč]'), 'c')
        .replaceAll(RegExp(r'[ñńňņṅṇṉǹ]'), 'n')
        .replaceAll(RegExp(r'[ḧĥħḩḥ]'), 'h')
        .replaceAll(RegExp(r'[ĵǰǰ]'), 'j')
        .replaceAll(RegExp(r'[ķĺľļŗ]'), 'l')
        .replaceAll(RegExp(r'[ḿṅṇ]'), 'm')
        .replaceAll(RegExp(r'[ṕp̌ḧ]'), 'p')
        .replaceAll(RegExp(r'[śšṡṧẛ]'), 's')
        .replaceAll(RegExp(r'[ťţṫṯ]'), 't')
        .replaceAll(RegExp(r'[ẃẇẅẉŵ]'), 'w')
        .replaceAll(RegExp(r'[x̌x̱ẋ]'), 'x')
        .replaceAll(RegExp(r'[ýŷỳỹẏ]'), 'y')
        .replaceAll(RegExp(r'[żźžẑ]'), 'z')
        .replaceAll(RegExp(r'[\r]'), ' ')
        .replaceAll(RegExp(r'[\n]'), ' ')
        .replaceAll(RegExp(r'[\t]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    return normalized;
  }

  String guessDocType(List<String> texts) {
    String combinedText = texts.map(_normalizeText).join(" ");

    Map<String, List<String>> documents = {
      "Cartão de Cidadão": [
        "citzen",
        "card",
        "cartao",
        "cidadao",
        "identity",
        "prt"
      ],
      "Título de Residência": [
        "titulo",
        "residencia",
        "prt",
        "resid",
        "autoriz",
        "residence",
        "permit"
      ],
      "Carta de Condução": ["carta", "conducao", "imt", "b1", "b"]
    };

    String bestMatch = "Documento não identificado";
    int bestScore = 0;

    for (var entry in documents.entries) {
      int score = 0;
      for (String keyword in entry.value) {
        if (combinedText.contains(keyword)) {
          score++;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestMatch = entry.key;
      }
    }

    return bestMatch;
  }

  Future<XFile?> rotateXFileImage(XFile xfile, double angleDegrees) async {
    try {
      final Uint8List bytes = await xfile.readAsBytes();
      final imge.Image? image = imge.decodeImage(bytes);
      if (image == null) return null;
      final rotated = imge.copyRotate(image, angle: angleDegrees);

      final Uint8List rotatedBytes =
      Uint8List.fromList(imge.encodeJpg(rotated));

      // Guarda a imagem num ficheiro temporário
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/rotated_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = await File(path).writeAsBytes(rotatedBytes);

      return XFile(file.path);
    } catch (e) {
      print('Erro ao rotacionar imagem: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Confirmação dos dados"),
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
                      return FutureBuilder<XFile?>(
                        future: rotateXFileImage(widget.imagesList[index], -angle!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox(
                              height: 300,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          } else if (snapshot.hasError ||
                              snapshot.data == null) {
                            return const SizedBox(
                              height: 300,
                              child:
                              Center(child: Text('Erro a carregar imagem')),
                            );
                          } else {
                            return Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Image.file(
                                File(snapshot.data!.path),
                                height: 300,
                                fit: BoxFit.cover,
                              ),
                            );
                          }
                        },
                      );
                    }),
                  ),
                ),
              ),
              SizedBox(height: 30),
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      "Tipo do documento",
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    SizedBox(height: 10),
                    Text(
                      inferredDocTypeName,//guessDocType(_extractedTextsList),
                      style: TextStyle(fontSize: 12),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "$text : $coords",
                      style: TextStyle(fontSize: 12),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Angle : $angle",
                      style: TextStyle(fontSize: 12),
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
}