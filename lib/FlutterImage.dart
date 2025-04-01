import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class FlutterImage {
  final File imageFile;


  FlutterImage(this.imageFile);

  Future<Size> getImageSize() async {
    final Completer<ImageInfo> completer = Completer();
    final Image image = Image.file(this.imageFile);

    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(info);
      }),
    );

    final ImageInfo imageInfo = await completer.future;
    return Size(imageInfo.image.width.toDouble(), imageInfo.image.height.toDouble());
  }

  Future<Uint8List> toUint8List(String imagePath) async {
    final ByteData data = await rootBundle.load(imagePath);
    return data.buffer.asUint8List();
  }

  Future<Uint8List> resizeImage(int targetWidth, int targetHeight) async {
    Uint8List imageBytes = await imageFile.readAsBytes();

    // Decodifica a imagem para manipulação
    ui.Image? decodedImage = img.decodeImage(imageBytes) as ui.Image?;
    if (decodedImage == null) {
      throw Exception("Erro ao decodificar a imagem");
    }

    // Redimensiona a imagem
    img.Image resized = img.copyResize(decodedImage as img.Image, width: targetWidth, height: targetHeight);

    // Codifica de volta para Uint8List (para exibir ou salvar)
    return Uint8List.fromList(img.encodeJpg(resized));
  }
}
