import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  /// Permite al usuario tomar una foto o elegirla de la galería.
  /// Luego copia la imagen al directorio local de la app para persistencia 
  /// y retorna la ruta del nuevo archivo.
  static Future<String?> pickAndSaveImage({required bool fromCamera}) async {
    final XFile? image = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 70, // Reducir tamaño para ahorrar espacio
    );

    if (image == null) return null;

    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}';
    final savedImagePath = p.join(directory.path, fileName);

    final savedImage = await File(image.path).copy(savedImagePath);
    return savedImage.path;
  }
}
