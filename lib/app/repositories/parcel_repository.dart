// ============================================================
// RNA Guide - Parcel Repository
// Couche data SQLite — séparée de la logique UI
// ============================================================

import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../../core/database/database_helper.dart';
import '../../core/sync/sync_manager.dart';
import 'base_repository.dart';

class ParcelRepository extends BaseRepository {
  static final ParcelRepository instance = ParcelRepository._();
  ParcelRepository._();

  // ── Créer ─────────────────────────────────────────────────

  Future<ParcelModel> create({
    required String name,
    required String region,
    required String province,
    required String commune,
    required String village,
    required double superficie,
    required double latitude,
    required double longitude,
    List<Map<String, double>>? gpsPoints,
    String? notes,
    required String ownerId,
  }) async {
    final now = DateTime.now();
    final localId = const Uuid().v4();

    final parcel = ParcelModel(
      id: localId,
      localId: localId,
      name: name,
      region: region,
      province: province,
      commune: commune,
      village: village,
      superficie: superficie,
      latitude: latitude,
      longitude: longitude,
      gpsPoints: gpsPoints,
      ownerId: ownerId,
      notes: notes,
      syncStatus: 'PENDING',
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('parcels', parcel.toMap());

    await SyncManager.instance.enqueue(
      localId: localId,
      entityType: 'parcel',
      action: 'create',
      payload: parcel.toSyncPayload(),
    );

    return parcel;
  }

  // ── Lire tous ─────────────────────────────────────────────

  Future<List<ParcelModel>> findAll({
    String? ownerId,
    String? region,
    String? search,
    bool includeDeleted = false,
    int? limit,
    int? offset,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    if (!includeDeleted) {
      conditions.add('deleted_at IS NULL');
    }
    if (ownerId != null) {
      conditions.add('owner_id = ?');
      args.add(ownerId);
    }
    if (region != null && region.isNotEmpty) {
      conditions.add('region = ?');
      args.add(region);
    }
    if (search != null && search.isNotEmpty) {
      conditions.add('(name LIKE ? OR village LIKE ? OR commune LIKE ?)');
      args.addAll(['%$search%', '%$search%', '%$search%']);
    }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final results = await db.query(
      'parcels',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );

    // Enrichir avec les compteurs
    final parcels = <ParcelModel>[];
    for (final row in results) {
      final parcel = ParcelModel.fromMap(row);
      final counts = await _getCounts(parcel.id);
      parcel.inventoriesCount = counts['inventories']!;
      parcel.photosCount = counts['photos']!;
      parcel.exploitationsCount = counts['exploitations']!;
      parcels.add(parcel);
    }

    return parcels;
  }

  // ── Lire un ───────────────────────────────────────────────

  Future<ParcelModel?> findById(String id) async {
    final results = await db.query(
      'parcels',
      where: '(id = ? OR local_id = ?) AND deleted_at IS NULL',
      whereArgs: [id, id],
      limit: 1,
    );
    if (results.isEmpty) return null;

    final parcel = ParcelModel.fromMap(results.first);
    final counts = await _getCounts(parcel.id);
    parcel.inventoriesCount = counts['inventories']!;
    parcel.photosCount = counts['photos']!;
    parcel.exploitationsCount = counts['exploitations']!;
    return parcel;
  }

  // ── Modifier ──────────────────────────────────────────────

  Future<void> update(String localId, Map<String, dynamic> fields) async {
    final existing = await db.query(
      'parcels',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (existing.isEmpty) return;

    final current = ParcelModel.fromMap(existing.first);
    final now = DateTime.now().toIso8601String();

    await db.update(
      'parcels',
      {
        ...fields,
        'sync_status': 'PENDING',
        'updated_at': now,
        'version': current.version + 1,
      },
      'local_id = ?',
      [localId],
    );

    await SyncManager.instance.enqueue(
      localId: localId,
      serverId: current.serverId,
      entityType: 'parcel',
      action: 'update',
      payload: {
        'localId': localId,
        ...fields,
      },
      version: current.version + 1,
    );
  }

  // ── Supprimer (soft) ──────────────────────────────────────

  Future<void> delete(String localId) async {
    final existing = await db.query(
      'parcels',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (existing.isEmpty) return;

    final current = ParcelModel.fromMap(existing.first);
    final now = DateTime.now().toIso8601String();

    await db.update(
      'parcels',
      {'sync_status': 'DELETED', 'deleted_at': now},
      'local_id = ?',
      [localId],
    );

    await SyncManager.instance.enqueue(
      localId: localId,
      serverId: current.serverId,
      entityType: 'parcel',
      action: 'delete',
      payload: {'localId': localId},
    );
  }

  // ── Statistiques rapides ──────────────────────────────────

  Future<Map<String, int>> getStats(String? ownerId) async {
    final cond = ownerId != null ? 'WHERE owner_id = ? AND deleted_at IS NULL' : 'WHERE deleted_at IS NULL';
    final args = ownerId != null ? [ownerId] : null;

    final total = await db.rawQuery('SELECT COUNT(*) as c FROM parcels $cond', args);
    final pending = await db.rawQuery(
      "SELECT COUNT(*) as c FROM parcels ${ownerId != null ? 'WHERE owner_id = ? AND' : 'WHERE'} sync_status = 'PENDING' AND deleted_at IS NULL",
      args,
    );
    final totalHa = await db.rawQuery(
      'SELECT COALESCE(SUM(superficie), 0) as s FROM parcels $cond',
      args,
    );

    return {
      'total': (total.first['c'] as int?) ?? 0,
      'pending': (pending.first['c'] as int?) ?? 0,
      'totalHa': ((totalHa.first['s'] as num?) ?? 0).round(),
    };
  }

  // ── Helper comptes ────────────────────────────────────────

  Future<Map<String, int>> _getCounts(String parcelId) async {
    final inv = await db.rawQuery(
      'SELECT COUNT(*) as c FROM inventories WHERE parcel_id = ?',
      [parcelId],
    );
    final photos = await db.rawQuery(
      "SELECT COUNT(*) as c FROM photos WHERE parcel_id = ? AND sync_status != 'DELETED'",
      [parcelId],
    );
    final expl = await db.rawQuery(
      "SELECT COUNT(*) as c FROM exploitations WHERE parcel_id = ? AND sync_status != 'DELETED'",
      [parcelId],
    );
    return {
      'inventories': (inv.first['c'] as int?) ?? 0,
      'photos': (photos.first['c'] as int?) ?? 0,
      'exploitations': (expl.first['c'] as int?) ?? 0,
    };
  }
}
