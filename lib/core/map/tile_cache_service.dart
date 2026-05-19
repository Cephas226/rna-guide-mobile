import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class TileCacheService {
  static final _log = Logger();
  static String? _cacheDir;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _cacheDir = p.join(dir.path, 'tiles_cache');
    await Directory(_cacheDir!).create(recursive: true);
  }

  static String get cacheDir => _cacheDir ?? '';

  static File tileFile(int z, int x, int y) =>
      File(p.join(_cacheDir!, z.toString(), x.toString(), '$y.png'));

  static Future<TileCacheStats> stats() async {
    int count = 0, size = 0;
    try {
      if (_cacheDir == null) return const TileCacheStats(tileCount: 0, sizeBytes: 0);
      await for (final e in Directory(_cacheDir!).list(recursive: true)) {
        if (e is File) { count++; size += await e.length(); }
      }
    } catch (_) {}
    return TileCacheStats(tileCount: count, sizeBytes: size);
  }

  static Future<void> clearCache() async {
    if (_cacheDir == null) return;
    final dir = Directory(_cacheDir!);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create();
    }
  }

  // Burkina Faso national, zoom 6→12
  static Future<void> downloadBF({
    required void Function(double progress, int done, int total) onProgress,
    required RxBool cancelToken,
  }) async {
    const minLat = 9.4, maxLat = 15.1;
    const minLon = -5.5, maxLon = 2.4;

    final tiles = <_Tile>[];
    for (int z = 6; z <= 12; z++) {
      final x0 = _lonToX(minLon, z), x1 = _lonToX(maxLon, z);
      final y0 = _latToY(maxLat, z), y1 = _latToY(minLat, z);
      for (int x = x0; x <= x1; x++) {
        for (int y = y0; y <= y1; y++) {
          tiles.add(_Tile(z, x, y));
        }
      }
    }

    final total = tiles.length;
    int done = 0;
    final dio = Dio();

    for (final t in tiles) {
      if (cancelToken.value) break;
      final file = tileFile(t.z, t.x, t.y);
      if (!await file.exists()) {
        try {
          final resp = await dio.get<List<int>>(
            'https://tile.openstreetmap.org/${t.z}/${t.x}/${t.y}.png',
            options: Options(
              responseType: ResponseType.bytes,
              headers: {'User-Agent': 'rna_guide/1.0'},
            ),
          );
          if (resp.statusCode == 200 && resp.data != null) {
            await file.parent.create(recursive: true);
            await file.writeAsBytes(Uint8List.fromList(resp.data!));
          }
        } catch (e) {
          _log.w('Tile ${t.z}/${t.x}/${t.y}: $e');
        }
      }
      done++;
      onProgress(done / total, done, total);
    }
  }

  static int _lonToX(double lon, int z) => ((lon + 180) / 360 * pow(2, z)).floor();
  static int _latToY(double lat, int z) {
    final r = lat * pi / 180;
    return ((1 - log(tan(r) + 1 / cos(r)) / pi) / 2 * pow(2, z)).floor();
  }
}

class _Tile {
  final int z, x, y;
  const _Tile(this.z, this.x, this.y);
}

class TileCacheStats {
  final int tileCount;
  final int sizeBytes;
  const TileCacheStats({required this.tileCount, required this.sizeBytes});

  String get formattedSize {
    if (sizeBytes == 0) return '0 Ko';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} Ko';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
}

// ── TileProvider avec cache fichier ───────────────────────────

class CachedTileProvider extends TileProvider {
  CachedTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    final file = TileCacheService.tileFile(coordinates.z.round(), coordinates.x, coordinates.y);
    return _CachedTileImage(url: url, file: file);
  }
}

class _CachedTileImage extends ImageProvider<_CachedTileImage> {
  final String url;
  final File file;
  const _CachedTileImage({required this.url, required this.file});

  @override
  Future<_CachedTileImage> obtainKey(ImageConfiguration _) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_CachedTileImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(_load(decode));

  Future<ImageInfo> _load(ImageDecoderCallback decode) async {
    Uint8List bytes;
    if (await file.exists()) {
      bytes = await file.readAsBytes();
    } else {
      final resp = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'User-Agent': 'rna_guide/1.0'},
        ),
      );
      if (resp.statusCode == 200 && resp.data != null) {
        bytes = Uint8List.fromList(resp.data!);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
      } else {
        throw Exception('Tile HTTP ${resp.statusCode}');
      }
    }
    final codec = await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }

  @override
  bool operator ==(Object other) => other is _CachedTileImage && url == other.url;
  @override
  int get hashCode => url.hashCode;
}
