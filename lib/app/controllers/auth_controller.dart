// ============================================================
// RNA Guide - Auth Controller (GetX)
// ============================================================

import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import '../models/models.dart';
import '../../core/network/dio_client.dart';
import '../../core/database/database_helper.dart';
import '../../core/sync/sync_manager.dart';

class AuthController extends GetxController {
  static AuthController get to => Get.find();

  final _storage = const FlutterSecureStorage();
  final _log = Logger();

  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;
  final RxBool isAuthenticated = false.obs;

  @override
  void onInit() {
    super.onInit();
    _checkAuth();
  }

  // ── Vérification auth au démarrage ────────────────────────

  Future<void> _checkAuth() async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      await _loadCurrentUser();
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final users = await DatabaseHelper.instance.query('users', limit: 1);
      if (users.isNotEmpty) {
        currentUser.value = UserModel.fromMap(users.first);
        isAuthenticated.value = true;
        SyncManager.instance.initialize();
      }
    } catch (e) {
      _log.e('Erreur chargement utilisateur: $e');
    }
  }

  // ── Connexion ─────────────────────────────────────────────

  Future<bool> login({String? email, String? phone, required String password}) async {
    isLoading.value = true;
    error.value = '';
    try {
      final response = await DioClient.instance.post('/auth/login', data: {
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data['data'];
        await _saveTokens(data['accessToken'], data['refreshToken']);
        await _saveUser(data['user']);
        isAuthenticated.value = true;
        await SyncManager.instance.initialize();
        await SyncManager.instance.syncNow();
        return true;
      }
    } catch (e) {
      error.value = _parseError(e);
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // ── Inscription ───────────────────────────────────────────

  Future<bool> register(Map<String, dynamic> data) async {
    isLoading.value = true;
    error.value = '';
    try {
      final response = await DioClient.instance.post('/auth/register', data: data);
      if (response.statusCode == 201) {
        final responseData = response.data['data'];
        await _saveTokens(responseData['accessToken'], responseData['refreshToken']);
        return true;
      }
    } catch (e) {
      error.value = _parseError(e);
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // ── Déconnexion ───────────────────────────────────────────

  Future<void> logout() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken != null) {
        await DioClient.instance.post('/auth/logout', data: {'refreshToken': refreshToken});
      }
    } catch (_) {}

    await _storage.deleteAll();
    await DatabaseHelper.instance.clearAll();
    currentUser.value = null;
    isAuthenticated.value = false;
    SyncManager.instance.dispose();
    Get.offAllNamed('/login');
  }

  // ── Helpers privés ────────────────────────────────────────

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<void> _saveUser(Map<String, dynamic> userData) async {
    final now = DateTime.now().toIso8601String();
    final user = UserModel(
      id: userData['id'],
      firstName: userData['firstName'] ?? '',
      lastName: userData['lastName'] ?? '',
      email: userData['email'],
      phone: userData['phone'],
      role: userData['role'] ?? 'PRODUCTEUR',
      region: userData['region'],
      province: userData['province'],
      commune: userData['commune'],
      village: userData['village'],
      createdAt: DateTime.now(),
    );

    await DatabaseHelper.instance.insert('users', {
      ...user.toMap(),
      'access_token': await _storage.read(key: 'access_token'),
      'refresh_token': await _storage.read(key: 'refresh_token'),
    });

    currentUser.value = user;
  }

  String _parseError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('401')) return 'Identifiants incorrects';
    if (msg.contains('409')) return 'Compte déjà existant';
    if (msg.contains('SocketException') || msg.contains('connection')) {
      return 'Pas de connexion internet';
    }
    return 'Erreur de connexion. Réessayez.';
  }
}
