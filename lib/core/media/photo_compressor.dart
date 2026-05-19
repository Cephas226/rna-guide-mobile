import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class PhotoCompressor {
  static const _maxBytes = 500 * 1024; // 500 Ko
  static const _qualities = [70, 55, 40];

  static Future<String> compress(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final ext = p.extension(sourcePath).toLowerCase();
    final destPath = p.join(
      appDir.path, 'rna_photos', '${const Uuid().v4()}${ext.isEmpty ? '.jpg' : ext}',
    );
    await Directory(p.dirname(destPath)).create(recursive: true);

    for (final quality in _qualities) {
      final result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        destPath,
        quality: quality,
        minWidth: 1280,
        minHeight: 960,
        autoCorrectionAngle: true,
      );
      if (result == null) break;
      if (await result.length() <= _maxBytes || quality == _qualities.last) {
        return result.path;
      }
    }
    // Fallback : copie brute
    await File(sourcePath).copy(destPath);
    return destPath;
  }
}
