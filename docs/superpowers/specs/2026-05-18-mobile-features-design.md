# RNA Guide Mobile — Fonctionnalités restantes

**Date :** 2026-05-18
**Scope :** 4 fonctionnalités indépendantes sur le mobile Flutter

---

## 1. Compression photo avant upload

### Objectif
Réduire le poids des photos terrain avant stockage local et upload, pour préserver la bande passante sur connexions 3G/4G lentes au Sahel.

### Contraintes
- Taille cible : ≤ 500 Ko
- Qualité JPEG : 70%
- Package : `flutter_image_compress` (déjà dans pubspec.yaml, non utilisé)

### Architecture
Nouveau fichier `lib/core/media/photo_compressor.dart` — service stateless avec une seule méthode publique :

```dart
class PhotoCompressor {
  static Future<Uint8List> compress(String sourcePath) async { ... }
}
```

Flux : `XFile brute → PhotoCompressor.compress() → Uint8List ≤500Ko → écriture disque → SQLite sync_status=PENDING`

Si le premier passage dépasse 500 Ko, la qualité est réduite itérativement (70% → 55% → 40%) jusqu'à atteindre le seuil.

### Intégration
`PhotoController._savePhoto()` dans `inventory_controller.dart` appelle `PhotoCompressor.compress(image.path)` avant `File.writeAsBytes()`. L'appel `image_picker` existant (maxWidth 1920, imageQuality 85) est conservé comme pré-filtre.

---

## 2. Upload photo vers Supabase via backend

### Objectif
Les photos capturées hors ligne sont uploadées vers Supabase Storage quand le réseau est disponible, via le backend NestJS (la clé Supabase reste côté serveur).

### Contraintes
- Upload via `POST /media/upload` (multipart/form-data) — endpoint déjà implémenté côté backend (`media.controller.ts`)
- Offline-first : la photo reste `sync_status=PENDING` jusqu'à l'upload réussi
- Retry max 5 tentatives (cohérent avec la sync_queue existante)
- Le `storage_url` retourné par le backend est sauvegardé en local

### Architecture
Nouveau fichier `lib/core/media/photo_upload_service.dart` :

```dart
class PhotoUploadService {
  static Future<String?> upload({ required String localPath, required String parcelId, ... }) async { ... }
}
```

`SyncManager.syncNow()` appelle `_pushPhotos()` après `_push()`. `_pushPhotos()` récupère les photos `PENDING` depuis SQLite, appelle `PhotoUploadService.upload()` pour chacune, met à jour `storage_url` et `sync_status=SYNCED` en cas de succès, incrémente `attempts` en cas d'erreur.

### Données
Table `photos` en SQLite : colonnes `storage_url` et `sync_status` déjà présentes. Aucun changement de schéma requis.

### Affichage
`_PhotoTab` dans `parcel_detail_page.dart` : si `storage_url` non null → afficher avec `CachedNetworkImage` ; sinon → afficher le fichier local avec `Image.file`.

---

## 3. Carte offline (tuiles téléchargées)

### Objectif
Permettre l'utilisation de la carte sans connexion internet sur le terrain au Burkina Faso.

### Contraintes
- Zone : BF national
- Niveaux de zoom : 6 → 12
- Source tuiles : OpenStreetMap
- Estimation : ~80 Mo, ~15 000 tuiles
- Téléchargement manuel déclenché par l'utilisateur
- Package à ajouter : `flutter_map_tile_caching` (FMTC)

### Architecture
Nouveau fichier `lib/core/map/tile_cache_service.dart` :

```dart
class TileCacheService {
  static const storeName = 'rna_bf';
  static Future<void> init() async { ... }
  static Future<void> downloadBF({ required void Function(double) onProgress }) async { ... }
  static Future<void> clear() async { ... }
  static Future<TileCacheStats> stats() async { ... }
}
```

`TileCacheService.init()` appelé dans `main()` après `Hive.initFlutter()`.

### Intégration carte
`TileLayer` dans `map_page.dart` et `_MiniMap` dans `parcel_detail_page.dart` : remplacer `urlTemplate` direct par un `TileProvider` FMTC avec fallback réseau automatique.

### UI téléchargement
Dans `ProfilePage` : nouvelle section "Carte offline" avec :
- Statut (non téléchargée / X Mo / en cours X%)
- Bouton "Télécharger" → progress indicator circulaire + pourcentage
- Bouton "Supprimer le cache"

`RxDouble downloadProgress` dans un `MapCacheController` (GetX) pilote le widget.

---

## 4. Multi-langue (français / mooré / dioula)

### Objectif
Permettre aux agents terrain de switcher l'interface en mooré ou dioula, les deux langues locales principales des zones RNA.

### Contraintes
- ~50 clés UI essentielles (boutons, labels, menus, messages d'erreur)
- Les contenus formations restent en français (hors scope)
- Codes locale ISO 639-3 corrects : `mos` (mooré), `dyu` (dioula)

### Corrections locale
Dans `main.dart` et partout dans le code :
- `Locale('moore', '')` → `Locale('mos')`
- `Locale('dioula', '')` → `Locale('dyu')`
- `Locale('fulfule', '')` → `Locale('ff')` (Fulfuldé, ISO 639-1)

`AppTranslations` enrichi avec les maps `mos_MOS` et `dyu_DYU` (~50 clés chacune).

### UI sélecteur
Dans `ProfilePage` : section "Langue" avec 3 boutons (🇫🇷 Français / 🇧🇫 Mooré / 🇧🇫 Dioula). Le choix est persisté dans `SharedPreferences` (clé `app_locale`) et restauré au démarrage dans `main()` avant `runApp()`.

```dart
Get.updateLocale(Locale('mos'));
```

---

## Ordre d'implémentation recommandé

1. **Compression** — rapide, autonome, valeur immédiate
2. **Upload Supabase** — dépend de la compression
3. **Multi-langue** — autonome, aucune dépendance
4. **Carte offline** — le plus long, dépend du nouveau package FMTC

---

## Fichiers créés / modifiés

| Fichier | Action |
|---|---|
| `lib/core/media/photo_compressor.dart` | Créer |
| `lib/core/media/photo_upload_service.dart` | Créer |
| `lib/core/map/tile_cache_service.dart` | Créer |
| `lib/app/controllers/map_cache_controller.dart` | Créer |
| `lib/app/controllers/inventory_controller.dart` | Modifier (compression + affichage photo) |
| `lib/core/sync/sync_manager.dart` | Modifier (ajout `_pushPhotos`) |
| `lib/app/views/parcels/map_page.dart` | Modifier (FMTC TileLayer) |
| `lib/app/views/parcels/parcel_detail_page.dart` | Modifier (affichage photo + FMTC minimap) |
| `lib/app/views/profile/profile_page.dart` | Modifier (sélecteur langue + carte offline) |
| `lib/app/translations/app_translations.dart` | Modifier (ajout mooré + dioula) |
| `lib/main.dart` | Modifier (init FMTC + restore locale + correction codes) |
| `pubspec.yaml` | Modifier (ajouter `flutter_map_tile_caching`) |
