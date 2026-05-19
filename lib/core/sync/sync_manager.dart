// ============================================================
// RNA Guide - Sync Manager
// Gestion de la synchronisation offline-first
// Queue → Retry exponentiel → Résolution conflits
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../database/database_helper.dart';
import '../network/dio_client.dart';
import '../media/photo_upload_service.dart';
import '../../app/controllers/auth_controller.dart';

enum SyncStatus { idle, syncing, error, noNetwork }

class SyncManager {
  static final SyncManager instance = SyncManager._internal();
  SyncManager._internal();

  final Logger _log = Logger();
  final Rx<SyncStatus> status = SyncStatus.idle.obs;
  final RxInt pendingCount = 0.obs;
  final RxString lastSyncAt = ''.obs;
  final RxList<SyncConflict> conflicts = <SyncConflict>[].obs;

  Timer? _syncTimer;
  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;

  // ── Initialisation ────────────────────────────────────────

  Future<void> initialize() async {
    // Observer la connectivité
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _log.i('📶 Réseau détecté — déclenchement sync automatique');
        syncNow();
      }
    });

    // Sync périodique toutes les 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => syncNow());

    // Compter les éléments en attente
    await _refreshPendingCount();
  }

  void dispose() {
    _syncTimer?.cancel();
    _connectivitySub?.cancel();
  }

  // ── Ajouter à la queue ────────────────────────────────────

  Future<void> enqueue({
    required String localId,
    String? serverId,
    required String entityType,
    required String action,
    required Map<String, dynamic> payload,
    int version = 1,
  }) async {
    final now = DateTime.now().toIso8601String();
    await DatabaseHelper.instance.insert('sync_queue', {
      'local_id': localId,
      'server_id': serverId,
      'entity_type': entityType,
      'action': action,
      'payload': jsonEncode(payload),
      'client_updated_at': now,
      'version': version,
      'status': 'PENDING',
      'attempts': 0,
      'created_at': now,
    });
    await _refreshPendingCount();
    _log.d('📥 Enqueued: $action $entityType $localId');
  }

  // ── Synchronisation principale ────────────────────────────

  Future<void> syncNow() async {
    if (_isSyncing) return;

    // Vérifier la connectivité
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      status.value = SyncStatus.noNetwork;
      return;
    }

    _isSyncing = true;
    status.value = SyncStatus.syncing;
    _log.i('🔄 Démarrage synchronisation...');

    try {
      // 1. PUSH: envoyer les mutations locales
      await _push();

      // 2. PUSH photos vers Supabase via backend
      await _pushPhotos();

      // 3. PULL: télécharger les deltas du serveur
      await _pull();

      lastSyncAt.value = DateTime.now().toIso8601String();
      status.value = SyncStatus.idle;
      _log.i('✅ Synchronisation terminée');
    } catch (e) {
      status.value = SyncStatus.error;
      _log.e('❌ Erreur synchronisation: $e');
    } finally {
      _isSyncing = false;
      await _refreshPendingCount();
    }
  }

  // ── PUSH: envoyer les mutations locales ───────────────────

  Future<void> _push() async {
    // Récupérer tous les items en attente (max 100 par batch)
    final items = await DatabaseHelper.instance.query(
      'sync_queue',
      where: 'status = ? AND attempts < ?',
      whereArgs: ['PENDING', 5],
      orderBy: 'created_at ASC',
      limit: 100,
    );

    if (items.isEmpty) {
      _log.d('📭 Aucun item à pousser');
      return;
    }

    _log.i('📤 Push de ${items.length} items...');

    final pushItems = items.map((item) => {
      'localId': item['local_id'],
      'serverId': item['server_id'],
      'entityType': item['entity_type'],
      'action': item['action'],
      'payload': jsonDecode(item['payload'] as String),
      'clientUpdatedAt': item['client_updated_at'],
      'version': item['version'],
    }).toList();

    try {
      final authController = Get.find<AuthController>();
      final response = await DioClient.instance.post('/sync/push', data: {
        'items': pushItems,
        'deviceId': authController.currentUser.value?.deviceId ?? 'unknown',
        'lastSyncAt': lastSyncAt.value,
      });

      if (response.statusCode == 200) {
        final results = response.data['data']['pushed']['results'] as List;

        // Traiter les résultats
        for (int i = 0; i < results.length; i++) {
          final result = results[i];
          final queueItem = items[i];
          final status = result['status'] as String;

          if (status == 'conflict') {
            // Stocker le conflit pour résolution
            conflicts.add(SyncConflict(
              localId: queueItem['local_id'] as String,
              entityType: queueItem['entity_type'] as String,
              clientPayload: jsonDecode(queueItem['payload'] as String),
              serverData: result['conflictData'],
            ));
            // Marquer comme conflit dans la queue
            await DatabaseHelper.instance.update(
              'sync_queue',
              {'status': 'CONFLICT'},
              'local_id = ?',
              [queueItem['local_id']],
            );
          } else if (['created', 'updated', 'deleted'].contains(status)) {
            // Succès: mettre à jour server_id si créé
            if (result['serverId'] != null && queueItem['local_id'] != null) {
              await _updateEntityServerId(
                queueItem['entity_type'] as String,
                queueItem['local_id'] as String,
                result['serverId'] as String,
              );
            }
            // Supprimer de la queue
            await DatabaseHelper.instance.delete(
              'sync_queue',
              'local_id = ? AND entity_type = ?',
              [queueItem['local_id'], queueItem['entity_type']],
            );
          } else {
            // Erreur: incrémenter attempts avec backoff
            final attempts = (queueItem['attempts'] as int) + 1;
            await DatabaseHelper.instance.update(
              'sync_queue',
              {
                'attempts': attempts,
                'last_attempt_at': DateTime.now().toIso8601String(),
                'error_message': result['errorMessage'],
                'status': attempts >= 5 ? 'FAILED' : 'PENDING',
              },
              'local_id = ?',
              [queueItem['local_id']],
            );
          }
        }
      }
    } catch (e) {
      // En cas d'erreur réseau, incrémenter attempts
      for (final item in items) {
        final attempts = (item['attempts'] as int) + 1;
        await DatabaseHelper.instance.update(
          'sync_queue',
          {'attempts': attempts, 'last_attempt_at': DateTime.now().toIso8601String()},
          'id = ?',
          [item['id']],
        );
      }
      rethrow;
    }
  }

  // ── PUSH photos vers Supabase ─────────────────────────────

  Future<void> _pushPhotos() async {
    final pending = await DatabaseHelper.instance.query(
      'photos',
      where: 'sync_status = ? AND local_path IS NOT NULL',
      whereArgs: ['PENDING'],
      limit: 20,
    );

    if (pending.isEmpty) return;
    _log.i('📷 Upload de ${pending.length} photos...');

    for (final photo in pending) {
      final localPath = photo['local_path'] as String?;
      if (localPath == null) continue;

      final storageUrl = await PhotoUploadService.upload(
        localPath: localPath,
        parcelId: photo['parcel_id'] as String,
        authorId: photo['author_id'] as String,
        photoPointId: photo['photo_point_id'] as String?,
        latitude: photo['latitude'] as double?,
        longitude: photo['longitude'] as double?,
        notes: photo['notes'] as String?,
        year: photo['year'] as int?,
      );

      if (storageUrl != null) {
        await DatabaseHelper.instance.update(
          'photos',
          {'storage_url': storageUrl, 'sync_status': 'SYNCED'},
          'local_id = ?',
          [photo['local_id']],
        );
        _log.d('✓ Photo uploadée: ${photo['local_id']}');
      }
    }
  }

  // ── PULL: télécharger les deltas ──────────────────────────

  Future<void> _pull() async {
    final since = lastSyncAt.value.isNotEmpty
        ? lastSyncAt.value
        : DateTime(2020).toIso8601String();

    _log.d('📥 Pull depuis $since...');

    final response = await DioClient.instance.get(
      '/sync/pull',
      queryParameters: {'lastSyncAt': since},
    );

    if (response.statusCode != 200) return;

    final delta = response.data['data']['delta'] as Map<String, dynamic>;

    // ── Upsert users (must precede parcels — FK owner_id → users.id) ──
    final users = delta['users'] as List? ?? [];
    for (final user in users) {
      await DatabaseHelper.instance.insert('users', _mapUserFromServer(user));
    }

    // ── Upsert parcelles ──
    final parcels = delta['parcels'] as List? ?? [];
    for (final parcel in parcels) {
      await DatabaseHelper.instance.insert('parcels', _mapParcelFromServer(parcel));
    }

    // ── Upsert inventaires ──
    final inventories = delta['inventories'] as List? ?? [];
    for (final inv in inventories) {
      await DatabaseHelper.instance.insert('inventories', _mapInventoryFromServer(inv));
    }

    // ── Upsert exploitations ──
    final exploitations = delta['exploitations'] as List? ?? [];
    for (final exp in exploitations) {
      await DatabaseHelper.instance.insert('exploitations', _mapExploitationFromServer(exp));
    }

    // ── Upsert formations (guides offline) ──
    final formations = delta['formations'] as List? ?? [];
    for (final f in formations) {
      await DatabaseHelper.instance.insert('formations', _mapFormationFromServer(f));
    }

    _log.i('📥 Pull: ${users.length} users, ${parcels.length} parcelles, ${inventories.length} inventaires, ${formations.length} formations');
  }

  // ── Helpers mapping serveur → SQLite ──────────────────────

  Map<String, dynamic> _mapUserFromServer(Map<String, dynamic> u) => {
    'id': u['id'],
    'local_id': u['localId'] ?? u['id'],
    'first_name': u['firstName'] ?? '',
    'last_name': u['lastName'] ?? '',
    'email': u['email'],
    'phone': u['phone'],
    'role': u['role'] ?? 'PRODUCTEUR',
    'region': u['region'],
    'province': u['province'],
    'commune': u['commune'],
    'village': u['village'],
    'avatar_url': u['avatarUrl'],
    'is_active': u['isActive'] == true ? 1 : 0,
    'created_at': u['createdAt'] ?? DateTime.now().toIso8601String(),
    'updated_at': u['updatedAt'] ?? DateTime.now().toIso8601String(),
  };

  Map<String, dynamic> _mapParcelFromServer(Map<String, dynamic> p) => {
    'id': p['id'],
    'local_id': p['localId'] ?? p['id'],
    'server_id': p['id'],
    'name': p['name'],
    'region': p['region'],
    'province': p['province'],
    'commune': p['commune'],
    'village': p['village'],
    'superficie': p['superficie'],
    'latitude': p['latitude'],
    'longitude': p['longitude'],
    'geometry': p['geometry'] != null ? jsonEncode(p['geometry']) : null,
    'gps_points': p['gpsPoints'] != null ? jsonEncode(p['gpsPoints']) : null,
    'owner_id': p['ownerId'],
    'notes': p['notes'],
    'sync_status': 'SYNCED',
    'version': p['version'] ?? 1,
    'created_at': p['createdAt'],
    'updated_at': p['updatedAt'],
    'deleted_at': p['deletedAt'],
  };

  Map<String, dynamic> _mapInventoryFromServer(Map<String, dynamic> i) => {
    'id': i['id'],
    'local_id': i['localId'] ?? i['id'],
    'server_id': i['id'],
    'parcel_id': i['parcelId'],
    'agent_id': i['agentId'],
    'year': i['year'],
    'season': i['season'],
    'total_pieds': i['totalPieds'],
    'selected_pieds': i['selectedPieds'],
    'observations': i['observations'],
    'validated_at': i['validatedAt'],
    'validated_by': i['validatedBy'],
    'sync_status': 'SYNCED',
    'version': i['version'] ?? 1,
    'created_at': i['createdAt'],
    'updated_at': i['updatedAt'],
  };

  Map<String, dynamic> _mapExploitationFromServer(Map<String, dynamic> e) => {
    'id': e['id'],
    'local_id': e['localId'] ?? e['id'],
    'server_id': e['id'],
    'parcel_id': e['parcelId'],
    'user_id': e['userId'],
    'product_type': e['productType'],
    'quantity': e['quantity'],
    'unit': e['unit'],
    'destination': e['destination'],
    'usage': e['usage'],
    'price_xof': e['priceXOF'],
    'exploited_at': e['exploitedAt'],
    'notes': e['notes'],
    'sync_status': 'SYNCED',
    'created_at': e['createdAt'],
  };

  Map<String, dynamic> _mapFormationFromServer(Map<String, dynamic> f) => {
    'id': f['id'],
    'title_fr': f['titleFr'],
    'title_moore': f['titleMoore'],
    'title_dioula': f['titleDioula'],
    'title_fulfule': f['titleFulfule'],
    'content_fr': f['contentFr'],
    'content_moore': f['contentMoore'],
    'media_urls': jsonEncode(f['mediaUrls'] ?? []),
    'category': f['category'],
    'order_index': f['orderIndex'],
    'is_published': f['isPublished'] == true ? 1 : 0,
    'updated_at': f['updatedAt'],
  };

  // ── Mettre à jour le server_id après création ─────────────

  Future<void> _updateEntityServerId(String entityType, String localId, String serverId) async {
    final tableMap = {
      'parcel': 'parcels',
      'inventory': 'inventories',
      'exploitation': 'exploitations',
      'photo': 'photos',
    };
    final table = tableMap[entityType];
    if (table == null) return;

    await DatabaseHelper.instance.update(
      table,
      {'server_id': serverId, 'sync_status': 'SYNCED'},
      'local_id = ?',
      [localId],
    );
  }

  Future<void> _refreshPendingCount() async {
    final result = await DatabaseHelper.instance.rawQuery(
      "SELECT COUNT(*) as count FROM sync_queue WHERE status = 'PENDING'",
    );
    pendingCount.value = (result.first['count'] as int?) ?? 0;
  }
}

// ── Modèle conflit ────────────────────────────────────────────

class SyncConflict {
  final String localId;
  final String entityType;
  final Map<String, dynamic> clientPayload;
  final Map<String, dynamic>? serverData;

  SyncConflict({
    required this.localId,
    required this.entityType,
    required this.clientPayload,
    this.serverData,
  });
}
