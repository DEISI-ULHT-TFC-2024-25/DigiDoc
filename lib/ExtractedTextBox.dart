import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';


class ExtractedTextBox{
  String text = "";
  String imagePath = "";

  ExtractedTextBox(this.imagePath);

  Future<bool> extractText() async {
    final inputImage = InputImage.fromFile(File(imagePath));
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

    textRecognizer.close();

    if (recognizedText.text.isEmpty){

      return false;
    } else{
      text = recognizedText.text;
      return true;
    }
  }
}