// RNA Guide - Bindings initiaux
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/parcel_controller.dart';
export '../controllers/inventory_controller.dart' show PhotoController;

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<AuthController>(AuthController(), permanent: true);
  }
}

// SyncController proxy pour la home page
class SyncController extends GetxController {
  static SyncController get to => Get.find();
}

