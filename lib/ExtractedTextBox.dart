import 'dart:math';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ExtractedTextBox {
  String text = "";
  String imagePath = "";
  List<TextBlock> _recognizedBlocks = [];

  ExtractedTextBox(this.imagePath);

  Future<bool> extractText() async {
    final inputImage = InputImage.fromFile(File(imagePath));
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    textRecognizer.close();

    _recognizedBlocks = recognizedText.blocks;
    text = recognizedText.text;
    return text.isNotEmpty;
  }


}