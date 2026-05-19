// ============================================================
// RNA Guide - Point d'entrée Flutter
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/database_helper.dart';
import 'core/network/dio_client.dart';
import 'core/map/tile_cache_service.dart';
import 'core/theme/app_theme.dart';
import 'app/routes/app_pages.dart';
import 'app/bindings/initial_binding.dart';
import 'app/translations/app_translations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await Hive.initFlutter();
  await DatabaseHelper.instance.initialize();
  await DioClient.instance.initialize();
  await TileCacheService.init();

  // ── Restaurer la langue choisie ──
  final prefs = await SharedPreferences.getInstance();
  final langCode = prefs.getString('app_locale_lang') ?? 'fr';
  final countryCode = prefs.getString('app_locale_country') ?? 'FR';
  final savedLocale = Locale(langCode, countryCode);

  runApp(RNAGuideApp(locale: savedLocale));
}

class RNAGuideApp extends StatelessWidget {
  final Locale locale;
  const RNAGuideApp({super.key, required this.locale});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'RNA Guide',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,

      translations: AppTranslations(),
      locale: locale,
      fallbackLocale: const Locale('fr', 'FR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('mos', 'BF'), // Mooré
        Locale('dyu', 'BF'), // Dioula
      ],

      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      initialBinding: InitialBinding(),

      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 200),
    );
  }
}
