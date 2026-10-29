import 'dart:io';

import 'package:image_picker/image_picker.dart';

import '../errors/app_exceptions.dart';

/// La foto no es JPEG ni PNG: el backend no la aceptaría (415).
class UnsupportedPhotoException extends AppException {
  const UnsupportedPhotoException() : super('La foto no es JPEG ni PNG');
}

/// Una foto elegida o tomada, ya reducida (lado mayor 1600 px, JPEG calidad 80; ADR de fotos, punto 5). El backend
/// le quita los metadatos al guardarla (ADR-051 F4).
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.contentType, required this.filename});
  final List<int> bytes;

  /// `image/jpeg` o `image/png`, deducido de los propios bytes.
  final String contentType;
  final String filename;
}

/// Cámara y galería, detrás de una interfaz para poder probar el flujo sin el plugin.
abstract interface class PhotoPicker {
  /// null si la persona cancela. [UnsupportedPhotoException] si la foto no es JPEG ni PNG.
  Future<PickedPhoto?> takePhoto();
  Future<PickedPhoto?> choosePhoto();
}

/// `image_picker` (ADR de fotos; dependencia aprobada el 2026-10-28). En escritorio no hay cámara: solo la galería.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  static const _maxSide = 1600.0;
  static const _quality = 80;

  /// El tipo por el contenido: JPEG empieza por `FF D8`, PNG por `89 50 4E 47`. Cualquier otro no se sube.
  static String? sniffContentType(List<int> b) {
    if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xD8) return 'image/jpeg';
    if (b.length >= 4 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
    return null;
  }

  Future<PickedPhoto?> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: _quality,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } finally {
      // La foto vive solo en memoria: la copia reducida que deja `image_picker` en la caché se borra en cuanto se
      // lee (ADR-051: nada de fotos de entrega en un teléfono que se puede perder; auditoría 2026-10-29, S-04).
      await deleteIfTemporary(file.path, Directory.systemTemp);
    }
    final type = sniffContentType(bytes);
    if (type == null) throw const UnsupportedPhotoException();
    return PickedPhoto(bytes: bytes, contentType: type, filename: type == 'image/png' ? 'entrega.png' : 'entrega.jpg');
  }

  /// Borra [path] solo si está dentro de [tempRoot] (la caché de la app, donde `image_picker` deja sus copias). Una
  /// foto que esté en otro sitio, como el original de la galería, no se toca nunca. Devuelve si se borró.
  static Future<bool> deleteIfTemporary(String path, Directory tempRoot) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return false;
      final real = file.resolveSymbolicLinksSync();
      final root = tempRoot.resolveSymbolicLinksSync();
      if (!real.startsWith('$root${Platform.pathSeparator}')) return false;
      await file.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  @override
  Future<PickedPhoto?> takePhoto() => _pick(ImageSource.camera);

  @override
  Future<PickedPhoto?> choosePhoto() => _pick(ImageSource.gallery);
}
