import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class PreparedPhoto {
  final Uint8List bytes;
  final int width;
  final int height;
  const PreparedPhoto(this.bytes, this.width, this.height);
}

PreparedPhoto preparePhoto(Uint8List bytes) {
  if (bytes.length > 25 * 1024 * 1024) {
    throw const FormatException('Choose a photo smaller than 25 MB.');
  }
  final decoder = img.findDecoderForData(bytes);
  if (decoder == null ||
      ![
        img.ImageFormat.jpg,
        img.ImageFormat.png,
        img.ImageFormat.webp,
      ].contains(decoder.format)) {
    throw const FormatException('Use a JPEG, PNG or WebP photo.');
  }
  final info = decoder.startDecode(bytes);
  if (info == null || info.width * info.height > 24000000) {
    throw const FormatException('Choose a photo smaller than 24 megapixels.');
  }
  var image = decoder.decodeFrame(0);
  if (image == null) {
    throw const FormatException('Use a JPEG, PNG or WebP photo.');
  }
  image = img.bakeOrientation(image);
  if (image.width < 32 || image.height < 32) {
    throw const FormatException(
      'Choose a photo at least 32 pixels wide and tall.',
    );
  }
  if (image.width > 1600 || image.height > 1600) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? 1600 : null,
      height: image.height > image.width ? 1600 : null,
    );
  }
  // bakeOrientation applies the original camera orientation before metadata removal.
  image.exif = img.ExifData();
  image.iccProfile = null;
  // Re-encode only the prepared pixels, without camera or location metadata.
  return PreparedPhoto(
    Uint8List.fromList(img.encodeJpg(image, quality: 90)),
    image.width,
    image.height,
  );
}

class PhotoService {
  final ImagePicker picker;
  PhotoService({ImagePicker? picker}) : picker = picker ?? ImagePicker();
  Future<PreparedPhoto?> pick(ImageSource source) async {
    final file = await picker.pickImage(source: source);
    if (file == null) return null;
    return compute(preparePhoto, await file.readAsBytes());
  }

  Future<PreparedPhoto?> recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final lost = await picker.retrieveLostData();
    if (lost.exception != null) throw lost.exception!;
    if (lost.files == null || lost.files!.isEmpty) return null;
    return compute(preparePhoto, await lost.files!.first.readAsBytes());
  }
}
