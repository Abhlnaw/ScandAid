import 'package:image_picker/image_picker.dart';

import 'logging_service.dart';

class CameraService {
  CameraService({LoggingService? logger}) : _logger = logger ?? LoggingService();

  final ImagePicker _picker = ImagePicker();
  final LoggingService _logger;

  Future<String?> captureInjuryPhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );

      return pickedFile?.path;
    } catch (e) {
      _logger.error('Error capturing camera image', e);
      return null;
    }
  }

  Future<String?> selectPhotoFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      return pickedFile?.path;
    } catch (e) {
      _logger.error('Error picking gallery image', e);
      return null;
    }
  }
}
