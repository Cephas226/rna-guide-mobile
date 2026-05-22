import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../../core/database/database_helper.dart';
import '../../core/sync/sync_manager.dart';
import 'auth_controller.dart';

const _uuid = Uuid();

class RnaController extends GetxController {
  static RnaController get to => Get.find();

  final _log = Logger();

  final RxList<RnaOperationModel> entretienOps = <RnaOperationModel>[].obs;
  final RxList<RnaOperationModel> cesDrsOps = <RnaOperationModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  Future<void> loadByParcel(String parcelId) async {
    isLoading.value = true;
    try {
      final rows = await DatabaseHelper.instance.query(
        'rna_operations',
        where: "parcel_id = ? AND sync_status != 'DELETED'",
        whereArgs: [parcelId],
        orderBy: 'year DESC, month DESC',
      );
      final ops = rows.map((r) => RnaOperationModel.fromMap(r)).toList();
      entretienOps.value = ops.where((o) => o.category == 'ENTRETIEN').toList();
      cesDrsOps.value = ops.where((o) => o.category == 'CES_DRS').toList();
    } catch (e) {
      _log.e('loadByParcel rna: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> create({
    required String parcelId,
    required String category,
    required String operationType,
    required int month,
    required int year,
    String? notes,
  }) async {
    isSaving.value = true;
    try {
      final now = DateTime.now();
      final localId = _uuid.v4();
      final userId = AuthController.to.currentUser.value?.id ?? '';

      await DatabaseHelper.instance.insert('rna_operations', {
        'id': localId,
        'local_id': localId,
        'parcel_id': parcelId,
        'user_id': userId,
        'category': category,
        'operation_type': operationType,
        'month': month,
        'year': year,
        'notes': notes,
        'sync_status': 'PENDING',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await SyncManager.instance.enqueue(
        localId: localId,
        entityType: 'rna_operation',
        action: 'create',
        payload: {
          'localId': localId,
          'parcelId': parcelId,
          'category': category,
          'operationType': operationType,
          'month': month,
          'year': year,
          'notes': notes,
        },
      );
      SyncManager.instance.syncNow();

      final op = RnaOperationModel(
        id: localId, localId: localId,
        parcelId: parcelId, userId: userId,
        category: category, operationType: operationType,
        month: month, year: year, notes: notes,
        syncStatus: 'PENDING',
        createdAt: now, updatedAt: now,
      );
      if (category == 'ENTRETIEN') {
        entretienOps.insert(0, op);
      } else {
        cesDrsOps.insert(0, op);
      }
      return true;
    } catch (e) {
      _log.e('create rna operation: $e');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> delete(String localId, String category) async {
    try {
      final now = DateTime.now().toIso8601String();
      await DatabaseHelper.instance.update(
        'rna_operations',
        {'sync_status': 'DELETED', 'updated_at': now},
        'local_id = ?',
        [localId],
      );
      await SyncManager.instance.enqueue(
        localId: localId,
        entityType: 'rna_operation',
        action: 'delete',
        payload: {'localId': localId},
      );
      SyncManager.instance.syncNow();
      if (category == 'ENTRETIEN') {
        entretienOps.removeWhere((o) => o.localId == localId);
      } else {
        cesDrsOps.removeWhere((o) => o.localId == localId);
      }
      return true;
    } catch (e) {
      _log.e('delete rna operation: $e');
      return false;
    }
  }

  // ── Métadonnées des types ──────────────────────────────────

  static const List<Map<String, String>> entretienTypes = [
    {'value': 'TAILLE',          'label': 'Taille / Élagage',       'icon': '✂️'},
    {'value': 'COUPE',           'label': 'Coupe de rejets',         'icon': '🪓'},
    {'value': 'PROTECTION',      'label': 'Protection individuelle', 'icon': '🛡️'},
    {'value': 'CUVETTES',        'label': 'Confection de cuvettes',  'icon': '⛏️'},
    {'value': 'FUMURE',          'label': 'Fumure organique',        'icon': '🌱'},
    {'value': 'SUIVI_SANITAIRE', 'label': 'Suivi sanitaire',         'icon': '🔍'},
    {'value': 'NETTOYAGE',       'label': 'Nettoyage / Clôture',     'icon': '🧹'},
  ];

  static const List<Map<String, String>> cesDrsTypes = [
    {'value': 'CORDONS_PIERREUX', 'label': 'Cordons pierreux',  'icon': '🪨'},
    {'value': 'ZAI',              'label': 'Zaï',               'icon': '⚫'},
    {'value': 'DEMI_LUNE',        'label': 'Demi-lune',         'icon': '🌙'},
    {'value': 'BANDES_ENHERBEES', 'label': 'Bandes enherbées',  'icon': '🌿'},
    {'value': 'DIGUETTE',         'label': 'Diguette en terre', 'icon': '🏔️'},
    {'value': 'DIGUE_FILTRANTE',  'label': 'Digue filtrante',   'icon': '💧'},
    {'value': 'AUTRE',            'label': 'Autre',             'icon': '📝'},
  ];

  String typeLabel(String value, String category) {
    final list = category == 'ENTRETIEN' ? entretienTypes : cesDrsTypes;
    return list.firstWhere(
      (t) => t['value'] == value,
      orElse: () => {'label': value},
    )['label']!;
  }

  String typeIcon(String value, String category) {
    final list = category == 'ENTRETIEN' ? entretienTypes : cesDrsTypes;
    return list.firstWhere(
      (t) => t['value'] == value,
      orElse: () => {'icon': '📋'},
    )['icon']!;
  }
}
