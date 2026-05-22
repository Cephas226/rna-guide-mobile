// RNA Guide - Routes complètes
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../views/splash/splash_page.dart';
import '../views/auth/login_page.dart';
import '../views/auth/register_page.dart';
import '../views/home/home_page.dart';
import '../views/parcels/parcel_list_page.dart';
import '../views/parcels/parcel_detail_page.dart';
import '../views/parcels/parcel_form_page.dart';
import '../views/parcels/map_page.dart';
import '../views/inventory/inventory_form_page.dart';
import '../views/exploitation/exploitation_form_page.dart';
import '../views/formations/formations_page.dart';
import '../views/sync/sync_status_page.dart';
import '../views/profile/profile_page.dart';
import '../controllers/auth_controller.dart';
import '../controllers/parcel_controller.dart';
import '../controllers/exploitation_controller.dart';
import '../controllers/inventory_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/rna_controller.dart';
part 'app_routes.dart';

class AppPages {
  static const initial = Routes.splash;
  static final routes = [
    GetPage(
      name: Routes.splash,
      page: () => const SplashPage(),
      binding: BindingsBuilder(() => Get.lazyPut(() => AuthController(), fenix: true)),
    ),
    GetPage(name: Routes.login, page: () => const LoginPage(),
      binding: BindingsBuilder(() => Get.lazyPut(() => AuthController(), fenix: true))),
    GetPage(name: Routes.register, page: () => const RegisterPage()),
    GetPage(name: Routes.home, page: () => const HomePage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => ParcelController(), fenix: true);
        Get.lazyPut(() => SyncController(), fenix: true);
      }),
      middlewares: [_AuthMiddleware()]),
    GetPage(name: Routes.parcelDetail, page: () => const ParcelDetailPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => InventoryController());
        Get.lazyPut(() => ExploitationController());
        Get.lazyPut(() => PhotoController());
        Get.lazyPut(() => RnaController());
      }),
      middlewares: [_AuthMiddleware()]),
    GetPage(name: Routes.parcelForm, page: () => const ParcelFormPage(), middlewares: [_AuthMiddleware()]),
    GetPage(name: Routes.map, page: () => const MapPage(), middlewares: [_AuthMiddleware()]),
    GetPage(name: Routes.inventoryForm, page: () => const InventoryFormPage(),
      binding: BindingsBuilder(() => Get.lazyPut(() => InventoryController())),
      middlewares: [_AuthMiddleware()]),
    GetPage(name: Routes.exploitationForm, page: () => const ExploitationFormPage(),
      binding: BindingsBuilder(() => Get.lazyPut(() => ExploitationController())),
      middlewares: [_AuthMiddleware()]),
    GetPage(name: Routes.formations, page: () => const FormationsPage(), middlewares: [_AuthMiddleware()]),
    GetPage(name: Routes.syncStatus, page: () => const SyncStatusPage(), middlewares: [_AuthMiddleware()]),
    GetPage(name: Routes.profile, page: () => const ProfilePage(),
      binding: BindingsBuilder(() => Get.lazyPut(() => ProfileController())),
      middlewares: [_AuthMiddleware()]),
  ];
}

class _AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (!Get.isRegistered<AuthController>()) return null;
    if (!AuthController.to.isAuthenticated.value) {
      return const RouteSettings(name: Routes.login);
    }
    return null;
  }
}
