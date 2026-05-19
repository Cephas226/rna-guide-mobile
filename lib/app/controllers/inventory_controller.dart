// ============================================================
// RNA Guide - Inventory Controller + Photo Controller
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/media/photo_compressor.dart';
import '../models/models.dart';
import '../repositories/base_repository.dart';
import '../repositories/exploitation_repository.dart';
import 'auth_controller.dart';

class InventoryController extends GetxController {
  static InventoryController get to => Get.find();

  final _repo = InventoryRepository.instance;
  final _speciesRepo = SpeciesRepository.instance;
  final _log = Logger();

  final RxList<InventoryModel> inventories = <InventoryModel>[].obs;
  final RxList<SpeciesModel> availableSpecies = <SpeciesModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadSpecies();
  }

  Future<void> loadSpecies({String? search}) async {
    try {
      final species = await _speciesRepo.findAll(search: search);
      availableSpecies.value = species;
    } catch (e) {
      _log.e('loadSpecies: $e');
    }
  }

  Future<void> loadByParcel(String parcelId) async {
    isLoading.value = true;
    error.value = '';
    try {
      final data = await _repo.findByParcel(parcelId);
      inventories.value = data;
    } catch (e) {
      error.value = 'Erreur chargement inventaires';
      _log.e('loadByParcel: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> create({
    required String parcelId,
    required int year,
    required String season,
    required List<InventorySpeciesModel> species,
    String? observations,
  }) async {
    if (species.isEmpty) {
      error.value = 'Ajoutez au moins une espèce';
      return false;
    }

    // Validation
    for (final sp in species) {
      if (sp.selectedPieds > sp.totalPieds) {
        error.value = 'Pieds sélectionnés > total pour ${sp.species?.localNameFr ?? sp.speciesId}';
        return false;
      }
    }

    isSaving.value = true;
    error.value = '';
    try {
      final agentId = AuthController.to.currentUser.value?.id ?? '';
      final totalPieds = species.fold(0, (s, sp) => s + sp.totalPieds);
      final selectedPieds = species.fold(0, (s, sp) => s + sp.selectedPieds);

      final inv = await _repo.create(
        parcelId: parcelId,
        agentId: agentId,
        year: year,
        season: season,
        totalPieds: totalPieds,
        selectedPieds: selectedPieds,
        observations: observations,
        species: species,
      );

      inventories.insert(0, inv);
      return true;
    } catch (e) {
      error.value = 'Erreur enregistrement inventaire';
      _log.e('create inventory: $e');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> delete(String localId) async {
    try {
      await _repo.delete(localId);
      inventories.removeWhere((i) => i.localId == localId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Aide à la saisie
  static const seasons = [
    {'value': 'HIVERNAGE',    'label': 'Hivernage', 'subtitle': 'Juin — Octobre', 'icon': '🌧️'},
    {'value': 'SAISON_SECHE', 'label': 'Saison sèche', 'subtitle': 'Novembre — Mai', 'icon': '☀️'},
  ];

  static const healthStates = [
    {'value': 'BON',    'label': 'Bon',    'color': 0xFF40916C},
    {'value': 'MOYEN',  'label': 'Moyen',  'color': 0xFFF4A261},
    {'value': 'MAUVAIS','label': 'Mauvais','color': 0xFFD62828},
  ];
}

// ============================================================
// RNA Guide - Photo Controller
// ============================================================

class PhotoController extends GetxController {
  static PhotoController get to => Get.find();

  final _photoRepo = PhotoRepository.instance;
  final _picker = ImagePicker();
  final _log = Logger();

  final RxList<Map<String, dynamic>> photos = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isCapturing = false.obs;

  Future<void> loadByParcel(String parcelId, {int? year}) async {
    isLoading.value = true;
    try {
      final data = await _photoRepo.findByParcel(parcelId, year: year);
      photos.value = data;
    } finally {
      isLoading.value = false;
    }
  }

  // ── Capturer avec la caméra ───────────────────────────────

  Future<bool> captureFromCamera({
    required String parcelId,
    required String authorId,
    String? photoPointId,
    String? notes,
  }) async {
    isCapturing.value = true;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1440,
        imageQuality: 85,
      );
      if (image == null) return false;

      return await _savePhoto(
        image: image,
        parcelId: parcelId,
        authorId: authorId,
        photoPointId: photoPointId,
        notes: notes,
      );
    } catch (e) {
      _log.e('captureFromCamera: $e');
      return false;
    } finally {
      isCapturing.value = false;
    }
  }

  // ── Choisir depuis la galerie ─────────────────────────────

  Future<bool> pickFromGallery({
    required String parcelId,
    required String authorId,
    String? notes,
  }) async {
    isCapturing.value = true;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1440,
        imageQuality: 85,
      );
      if (image == null) return false;

      return await _savePhoto(
        image: image,
        parcelId: parcelId,
        authorId: authorId,
        notes: notes,
      );
    } catch (e) {
      _log.e('pickFromGallery: $e');
      return false;
    } finally {
      isCapturing.value = false;
    }
  }

  // ── Sauvegarder localement ────────────────────────────────

  Future<bool> _savePhoto({
    required XFile image,
    required String parcelId,
    required String authorId,
    String? photoPointId,
    String? notes,
  }) async {
    try {
      // Compresser avant sauvegarde (≤500 Ko, qualité 70%)
      final destPath = await PhotoCompressor.compress(image.path);
      final localId = const Uuid().v4();

      // Récupérer position GPS
      double? lat, lng;
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}

      await _photoRepo.save(
        localId: localId,
        parcelId: parcelId,
        authorId: authorId,
        localPath: destPath,
        photoPointId: photoPointId,
        latitude: lat,
        longitude: lng,
        notes: notes,
        year: DateTime.now().year,
      );

      // Recharger la liste
      await loadByParcel(parcelId);
      return true;
    } catch (e) {
      _log.e('_savePhoto: $e');
      return false;
    }
  }

  Future<bool> delete(String localId, String parcelId) async {
    try {
      // Supprimer le fichier local si existe
      final photo = photos.firstWhereOrNull((p) => p['local_id'] == localId);
      if (photo != null && photo['local_path'] != null) {
        final file = File(photo['local_path'] as String);
        if (await file.exists()) await file.delete();
      }
      await _photoRepo.delete(localId);
      photos.removeWhere((p) => p['local_id'] == localId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
