import 'package:image_picker/image_picker.dart';

class UploadFromGallery{
  String? imagePath;
  UploadFromGallery();

  Future<void> gettingPath() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;
    imagePath = image.path;
  }

}