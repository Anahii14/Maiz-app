import 'package:image_picker/image_picker.dart';

class CameraService {
  final ImagePicker _picker = ImagePicker();

  /// Lado máximo de la foto. El modelo usa 320 px (modelo_config.json) y el
  /// % se mide a 512 px,
  /// así que 1600 px sobra y evita que celulares básicos se queden sin memoria.
  static const double _maxSide = 1600;

  Future<XFile?> pickFromCamera() {
    return _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      preferredCameraDevice: CameraDevice.rear,
    );
  }

  Future<XFile?> pickFromGallery() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: _maxSide,
      maxHeight: _maxSide,
    );
  }
}
