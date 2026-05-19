// ============================================================
// RNA Guide - Parcel Controller (GetX)
// Gestion parcelles offline-first avec sync transparente
// ============================================================

import 'dart:convert';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';
import '../models/models.dart';
import '../../core/database/database_helper.dart';
import '../../core/network/dio_client.dart';
import '../../core/sync/sync_manager.dart';
import 'auth_controller.dart';

const _uuid = Uuid();

class ParcelController extends GetxController {
  static ParcelController get to => Get.find();

  final RxList<ParcelModel> parcels = <ParcelModel>[].obs;
  final Rx<ParcelModel?> selectedParcel = Rx<ParcelModel?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString error = ''.obs;
  final RxInt total = 0.obs;

  final _log = Logger();

  @override
  void onInit() {
    super.onInit();
    loadParcels();
  }

  // ── Charger depuis SQLite (offline-first) ─────────────────

  Future<void> loadParcels({String? search, String? region}) async {
    isLoading.value = true;
    error.value = '';
    try {
      final userId = AuthController.to.currentUser.value?.id;
      final role = AuthController.to.currentUser.value?.role ?? 'PRODUCTEUR';

      String? whereClause = 'deleted_at IS NULL';
      final List<dynamic> args = [];

      // Les producteurs ne voient que leurs parcelles
      if (role == 'PRODUCTEUR' && userId != null) {
        whereClause += ' AND owner_id = ?';
        args.add(userId);
      }
      if (search != null && search.isNotEmpty) {
        whereClause += ' AND (name LIKE ? OR village LIKE ? OR commune LIKE ?)';
        args.addAll(['%$search%', '%$search%', '%$search%']);
      }
      if (region != null && region.isNotEmpty) {
        whereClause += ' AND region = ?';
        args.add(region);
      }

      final results = await DatabaseHelper.instance.query(
        'parcels',
        where: whereClause,
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'updated_at DESC',
        limit: 100,
      );

      parcels.value = results.map((r) => ParcelModel.fromMap(r)).toList();
      total.value = parcels.length;
    } catch (e) {
      error.value = 'Erreur chargement parcelles';
      _log.e('loadParcels: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Charger une parcelle ──────────────────────────────────

  Future<ParcelModel?> loadParcelDetail(String localId) async {
    final results = await DatabaseHelper.instance.query(
      'parcels',
      where: 'local_id = ? OR id = ?',
      whereArgs: [localId, localId],
    );
    if (results.isEmpty) return null;
    final parcel = ParcelModel.fromMap(results.first);

    // Enrichir avec les compteurs
    final invCount = await DatabaseHelper.instance.rawQuery(
      'SELECT COUNT(*) as c FROM inventories WHERE parcel_id = ?',
      [parcel.id],
    );
    parcel.inventoriesCount = (invCount.first['c'] as int?) ?? 0;

    selectedParcel.value = parcel;
    return parcel;
  }

  // ── Créer une parcelle (offline-first) ───────────────────

  Future<ParcelModel?> create(Map<String, dynamic> data) async {
    isSaving.value = true;
    error.value = '';
    try {
      final userId = AuthController.to.currentUser.value?.id ?? '';
      final now = DateTime.now();
      final localId = _uuid.v4();

      final parcel = ParcelModel(
        id: localId,
        localId: localId,
        name: data['name'],
        region: data['region'],
        province: data['province'],
        commune: data['commune'],
        village: data['village'],
        superficie: (data['superficie'] as num).toDouble(),
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        gpsPoints: data['gpsPoints'] != null
            ? List<Map<String, dynamic>>.from(data['gpsPoints'])
            : null,
        ownerId: userId,
        notes: data['notes'],
        syncStatus: 'PENDING',
        createdAt: now,
        updatedAt: now,
      );

      // Sauvegarder SQLite
      await DatabaseHelper.instance.insert('parcels', parcel.toMap());

      // Ajouter à la queue sync
      await SyncManager.instance.enqueue(
        localId: localId,
        entityType: 'parcel',
        action: 'create',
        payload: parcel.toSyncPayload(),
      );

      parcels.insert(0, parcel);
      _log.i('Parcelle créée localement: $localId');

      // Tenter sync immédiate
      SyncManager.instance.syncNow();

      return parcel;
    } catch (e) {
      error.value = 'Erreur création parcelle';
      _log.e('create parcel: $e');
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  // ── Modifier une parcelle ─────────────────────────────────

  Future<bool> updateParcel(String localId, Map<String, dynamic> data) async {
    isSaving.value = true;
    try {
      final now = DateTime.now().toIso8601String();
      final results = await DatabaseHelper.instance.query(
        'parcels', where: 'local_id = ?', whereArgs: [localId],
      );
      if (results.isEmpty) return false;

      final current = ParcelModel.fromMap(results.first);

      await DatabaseHelper.instance.update(
        'parcels',
        {...data, 'sync_status': 'PENDING', 'updated_at': now, 'version': current.version + 1},
        'local_id = ?',
        [localId],
      );

      await SyncManager.instance.enqueue(
        localId: localId,
        serverId: current.serverId,
        entityType: 'parcel',
        action: 'update',
        payload: {...data, 'localId': localId},
        version: current.version + 1,
      );

      await loadParcels();
      SyncManager.instance.syncNow();
      return true;
    } catch (e) {
      error.value = 'Erreur modification';
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  // ── Supprimer une parcelle ────────────────────────────────

  Future<bool> delete(String localId) async {
    try {
      await DatabaseHelper.instance.update(
        'parcels',
        {'sync_status': 'DELETED', 'deleted_at': DateTime.now().toIso8601String()},
        'local_id = ?',
        [localId],
      );
      await SyncManager.instance.enqueue(
        localId: localId,
        entityType: 'parcel',
        action: 'delete',
        payload: {'localId': localId},
      );
      parcels.removeWhere((p) => p.localId == localId);
      SyncManager.instance.syncNow();
      return true;
    } catch (e) {
      return false;
    }
  }
}

// ============================================================
// RNA Guide - Sync Controller (GetX) - UI pour la sync
// ============================================================

class SyncController extends GetxController {
  static SyncController get to => Get.find();

  final syncManager = SyncManager.instance;

  RxInt get pendingCount => syncManager.pendingCount;
  Rx<SyncStatus> get status => syncManager.status;
  RxString get lastSyncAt => syncManager.lastSyncAt;
  RxList<SyncConflict> get conflicts => syncManager.conflicts;

  Future<void> syncNow() => syncManager.syncNow();

  String get statusLabel => switch (syncManager.status.value) {
    SyncStatus.idle      => 'Synchronisé',
    SyncStatus.syncing   => 'Synchronisation...',
    SyncStatus.error     => 'Erreur de sync',
    SyncStatus.noNetwork => 'Hors ligne',
  };

  String get lastSyncLabel {
    if (lastSyncAt.value.isEmpty) return 'Jamais synchronisé';
    final dt = DateTime.tryParse(lastSyncAt.value);
    if (dt == null) return 'Jamais synchronisé';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inDays} jour(s)';
  }
}
