// ============================================================
// RNA Guide - Base Repository + Inventory Repository
// ============================================================

import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../../core/sync/sync_manager.dart';
import '../models/models.dart';
import 'base_repository.dart';

abstract class BaseRepository {
  DatabaseHelper get db => DatabaseHelper.instance;
}

// ============================================================
// RNA Guide - Inventory Repository
// ============================================================

class InventoryRepository extends BaseRepository {
  static final InventoryRepository instance = InventoryRepository._();
  InventoryRepository._();

  Future<InventoryModel> create({
    required String parcelId,
    required String agentId,
    required int year,
    required String season,
    required int totalPieds,
    required int selectedPieds,
    String? observations,
    required List<InventorySpeciesModel> species,
  }) async {
    final now = DateTime.now();
    final localId = const Uuid().v4();

    await DatabaseHelper.instance.insert('inventories', {
      'id': localId,
      'local_id': localId,
      'parcel_id': parcelId,
      'agent_id': agentId,
      'year': year,
      'season': season,
      'total_pieds': totalPieds,
      'selected_pieds': selectedPieds,
      'observations': observations,
      'sync_status': 'PENDING',
      'version': 1,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    // Sauvegarder les espèces
    for (final sp in species) {
      await DatabaseHelper.instance.insert('inventory_species', {
        'id': const Uuid().v4(),
        'inventory_id': localId,
        'species_id': sp.speciesId,
        'total_pieds': sp.totalPieds,
        'selected_pieds': sp.selectedPieds,
        'health_state': sp.healthState,
        'height_cm': sp.heightCm,
        'notes': sp.notes,
        'is_new_species': sp.isNewSpecies ? 1 : 0,
      });
    }

    await SyncManager.instance.enqueue(
      localId: localId,
      entityType: 'inventory',
      action: 'create',
      payload: {
        'localId': localId,
        'parcelId': parcelId,
        'agentId': agentId,
        'year': year,
        'season': season,
        'totalPieds': totalPieds,
        'selectedPieds': selectedPieds,
        'observations': observations,
        'species': species.map((s) => s.toMap()).toList(),
      },
    );

    return InventoryModel(
      id: localId,
      localId: localId,
      parcelId: parcelId,
      agentId: agentId,
      year: year,
      season: season,
      totalPieds: totalPieds,
      selectedPieds: selectedPieds,
      observations: observations,
      syncStatus: 'PENDING',
      species: species,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<List<InventoryModel>> findByParcel(String parcelId) async {
    final rows = await DatabaseHelper.instance.query(
      'inventories',
      where: 'parcel_id = ?',
      whereArgs: [parcelId],
      orderBy: 'year DESC, season ASC',
    );

    final inventories = <InventoryModel>[];
    for (final row in rows) {
      final inv = InventoryModel.fromMap(row);
      // Charger les espèces
      final speciesRows = await DatabaseHelper.instance.rawQuery(
        '''SELECT is.*, s.scientific_name, s.local_name_fr, s.local_name_moore,
                  s.local_name_dioula, s.category, s.is_native
           FROM inventory_species is
           LEFT JOIN species s ON s.id = is.species_id
           WHERE is.inventory_id = ?
           ORDER BY is.total_pieds DESC''',
        [inv.id],
      );
      inv.species = speciesRows.map((r) {
        final sp = InventorySpeciesModel.fromMap(r);
        sp.species = SpeciesModel.fromMap(r);
        return sp;
      }).toList();
      inventories.add(inv);
    }
    return inventories;
  }

  Future<void> delete(String localId) async {
    await DatabaseHelper.instance.update(
      'inventories',
      {'sync_status': 'DELETED'},
      'local_id = ?',
      [localId],
    );
  }
}
