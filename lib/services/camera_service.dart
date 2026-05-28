import 'package:image_picker/image_picker.dart';

class CameraService {
  final ImagePicker _picker = ImagePicker();

  Future<String?> captureInjuryPhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100, 
      );

      return pickedFile?.path;
    } catch (e) {
      print('Error capturing camera image: $e');
      return null;
    }
  }

  // Lets the user pick an existing photo from their gallery
  Future<String?> selectPhotoFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      
      return pickedFile?.path;
    } catch (e) {
      print('Error picking gallery image: $e');
      return null;
    }
  }
}