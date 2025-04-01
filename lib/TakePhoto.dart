import 'package:image_picker/image_picker.dart';


class TakePhoto{
  String? imagePath;
  TakePhoto();

  Future<void> gettingPath() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) return;
    imagePath = image.path;
  }

}