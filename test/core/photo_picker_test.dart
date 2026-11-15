import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paxfide_mobile/core/media/photo_picker.dart';

class _Picker extends ImagePicker {
  _Picker(this.path);
  final String path;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => XFile(path);
}

void main() {
  const jpeg = [0xFF, 0xD8, 0xFF, 0xD9];

  test('S-04: la copia que deja image_picker en la caché se borra en cuanto se lee', () async {
    final dir = Directory.systemTemp.createTempSync('image_picker_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/scaled_1.jpg')..writeAsBytesSync(jpeg);
    final photo = await ImagePickerPhotoPicker(_Picker(file.path)).takePhoto();
    expect(photo!.bytes, jpeg);
    expect(file.existsSync(), isFalse);
  });

  test('S-04: también se borra si no es JPEG ni PNG (y no se sube)', () async {
    final dir = Directory.systemTemp.createTempSync('image_picker_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/raro.gif')..writeAsBytesSync([0x47, 0x49, 0x46]);
    await expectLater(
      ImagePickerPhotoPicker(_Picker(file.path)).choosePhoto(),
      throwsA(isA<UnsupportedPhotoException>()),
    );
    expect(file.existsSync(), isFalse);
  });

  test('una foto fuera de la caché de la app (p. ej. el original de la galería) nunca se borra', () async {
    final cache = Directory.systemTemp.createTempSync('cache_');
    final gallery = Directory.systemTemp.createTempSync('galeria_');
    addTearDown(() {
      cache.deleteSync(recursive: true);
      gallery.deleteSync(recursive: true);
    });
    final original = File('${gallery.path}/IMG_1.jpg')..writeAsBytesSync(jpeg);
    expect(await ImagePickerPhotoPicker.deleteIfTemporary(original.path, cache), isFalse);
    expect(original.existsSync(), isTrue);
    expect(
      await ImagePickerPhotoPicker.deleteIfTemporary(
        '${cache.path}/../${gallery.uri.pathSegments.where((s) => s.isNotEmpty).last}/IMG_1.jpg',
        cache,
      ),
      isFalse,
    );
    expect(original.existsSync(), isTrue);
  });
}
