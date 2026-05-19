import 'package:get/get.dart';
import '../../core/map/tile_cache_service.dart';

class MapCacheController extends GetxController {
  static MapCacheController get to => Get.find();

  final RxDouble progress = 0.0.obs;
  final RxBool isDownloading = false.obs;
  final _cancel = false.obs;
  final Rx<TileCacheStats> stats =
      const TileCacheStats(tileCount: 0, sizeBytes: 0).obs;

  @override
  void onInit() {
    super.onInit();
    refreshStats();
  }

  Future<void> refreshStats() async {
    stats.value = await TileCacheService.stats();
  }

  Future<void> startDownload() async {
    if (isDownloading.value) return;
    isDownloading.value = true;
    progress.value = 0;
    _cancel.value = false;

    await TileCacheService.downloadBF(
      onProgress: (p, _, __) => progress.value = p,
      cancelToken: _cancel,
    );

    isDownloading.value = false;
    await refreshStats();
  }

  void cancelDownload() => _cancel.value = true;

  Future<void> clearCache() async {
    await TileCacheService.clearCache();
    await refreshStats();
  }
}
