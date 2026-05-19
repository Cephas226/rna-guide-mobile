// ============================================================
// RNA Guide - Profile Controller
// ============================================================

import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../../core/network/dio_client.dart';
import '../../core/database/database_helper.dart';
import 'auth_controller.dart';

class ProfileController extends GetxController {
  static ProfileController get to => Get.find();

  final _log = Logger();

  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString error = ''.obs;
  final RxString success = ''.obs;

  // ── Modifier le profil ────────────────────────────────────

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    isSaving.value = true;
    error.value = '';
    success.value = '';
    try {
      final userId = AuthController.to.currentUser.value?.id;
      if (userId == null) return false;

      final response = await DioClient.instance.patch('/users/$userId', data: data);

      if (response.statusCode == 200) {
        final updated = response.data['data'];
        // Mettre à jour SQLite
        await DatabaseHelper.instance.update(
          'users',
          {
            'first_name': updated['firstName'],
            'last_name': updated['lastName'],
            'region': updated['region'],
            'province': updated['province'],
            'commune': updated['commune'],
            'village': updated['village'],
            'email': updated['email'],
            'phone': updated['phone'],
          },
          'id = ?',
          [userId],
        );
        success.value = 'Profil mis à jour';
        return true;
      }
      return false;
    } catch (e) {
      error.value = 'Erreur mise à jour profil';
      _log.e('updateProfile: $e');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  // ── Changer mot de passe ──────────────────────────────────

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      error.value = 'Nouveau mot de passe trop court (min 8 caractères)';
      return false;
    }
    if (currentPassword == newPassword) {
      error.value = 'Le nouveau mot de passe doit être différent';
      return false;
    }

    isSaving.value = true;
    error.value = '';
    success.value = '';
    try {
      final userId = AuthController.to.currentUser.value?.id;
      if (userId == null) return false;

      final response = await DioClient.instance.patch(
        '/users/$userId/password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );

      if (response.statusCode == 200) {
        success.value = 'Mot de passe modifié. Reconnectez-vous.';
        // Déconnexion forcée (les tokens ont été révoqués côté serveur)
        await Future.delayed(const Duration(seconds: 2));
        await AuthController.to.logout();
        return true;
      }
      return false;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('400')) {
        error.value = 'Mot de passe actuel incorrect';
      } else {
        error.value = 'Erreur changement de mot de passe';
      }
      _log.e('changePassword: $e');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  // ── Stats de l'utilisateur ────────────────────────────────

  Future<Map<String, int>> getUserStats() async {
    final userId = AuthController.to.currentUser.value?.id;
    if (userId == null) return {};

    final parcels = await DatabaseHelper.instance.rawQuery(
      'SELECT COUNT(*) as c FROM parcels WHERE owner_id = ? AND deleted_at IS NULL',
      [userId],
    );
    final inventories = await DatabaseHelper.instance.rawQuery(
      'SELECT COUNT(*) as c FROM inventories WHERE agent_id = ?',
      [userId],
    );
    final photos = await DatabaseHelper.instance.rawQuery(
      "SELECT COUNT(*) as c FROM photos WHERE author_id = ? AND sync_status != 'DELETED'",
      [userId],
    );
    final exploitations = await DatabaseHelper.instance.rawQuery(
      "SELECT COUNT(*) as c FROM exploitations WHERE user_id = ? AND sync_status != 'DELETED'",
      [userId],
    );

    return {
      'parcels': (parcels.first['c'] as int?) ?? 0,
      'inventories': (inventories.first['c'] as int?) ?? 0,
      'photos': (photos.first['c'] as int?) ?? 0,
      'exploitations': (exploitations.first['c'] as int?) ?? 0,
    };
  }
}
