// ============================================================
// RNA Guide - Détail Parcelle RNA (complet — 4 onglets)
// ============================================================

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/map/tile_cache_service.dart';
import '../../models/models.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/exploitation_controller.dart';
import '../../controllers/inventory_controller.dart' show PhotoController;
import '../../controllers/parcel_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../routes/app_pages.dart';

class ParcelDetailPage extends StatefulWidget {
  const ParcelDetailPage({super.key});
  @override
  State<ParcelDetailPage> createState() => _ParcelDetailPageState();
}

class _ParcelDetailPageState extends State<ParcelDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late ParcelModel parcel;
  final _invCtrl = Get.put(InventoryController(), permanent: false);
  final _explCtrl = Get.put(ExploitationController(), permanent: false);
  final _photoCtrl = Get.put(PhotoController(), permanent: false);

  @override
  void initState() {
    super.initState();
    parcel = Get.arguments as ParcelModel;
    _tabs = TabController(length: 4, vsync: this);
    _invCtrl.loadByParcel(parcel.id);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        if (_tabs.index == 2) _explCtrl.loadByParcel(parcel.id);
        if (_tabs.index == 3) _photoCtrl.loadByParcel(parcel.id);
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
          leading: IconButton(
  icon: const Icon(
    Icons.arrow_back,
    color: Colors.black,
  ),
  onPressed: () {
    Get.back(result: true);
  },
),
            expandedHeight: 210,
            pinned: true,
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(parcel.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
              background: _MiniMap(parcel: parcel),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.edit,color: AppTheme.primary),
                onPressed: () => Get.toNamed(Routes.parcelForm, arguments: parcel)),
              IconButton(icon: const Icon(Icons.delete_outline,color: AppTheme.primary),
                onPressed: () => _confirmDelete(context)),
            ],
          ),
          SliverToBoxAdapter(child: _KpiRow(parcel: parcel)),
          SliverPersistentHeader(
            delegate: _StickyTabBar(TabBar(
              controller: _tabs,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Infos'),
                Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Inventaires'),
                Tab(icon: Icon(Icons.shopping_basket_outlined, size: 18), text: 'Récoltes'),
                Tab(icon: Icon(Icons.photo_camera_outlined, size: 18), text: 'Photos'),
              ],
            )),
            pinned: true,
          ),
        ],
        body: TabBarView(controller: _tabs, children: [
          _InfoTab(parcel: parcel),
          _InventoryTab(parcel: parcel, ctrl: _invCtrl),
          _ExploitationTab(parcel: parcel, ctrl: _explCtrl),
          _PhotoTab(parcel: parcel, ctrl: _photoCtrl),
        ]),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (_, __) => switch (_tabs.index) {
          1 => FloatingActionButton.extended(
              onPressed: () => Get.toNamed(Routes.inventoryForm, arguments: parcel),
              icon: const Icon(Icons.add_chart), label: const Text('Inventaire')),
          2 => FloatingActionButton.extended(
              onPressed: () => Get.toNamed(Routes.exploitationForm, arguments: parcel),
              icon: const Icon(Icons.add), label: const Text('Récolte'),
              backgroundColor: AppTheme.secondary),
          3 => FloatingActionButton.extended(
              onPressed: () => _showPhotoMenu(context),
              icon: const Icon(Icons.camera_alt), label: const Text('Photo'),
              backgroundColor: const Color(0xFF9B5DE5)),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  void _showPhotoMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: AppTheme.primary),
            title: const Text('Prendre une photo'),
            onTap: () async {
              Navigator.pop(context);
              final userId = Get.find<dynamic>().currentUser?.value?.id ?? '';
              final ok = await _photoCtrl.captureFromCamera(
                parcelId: parcel.id, authorId: userId);
              if (ok) Get.snackbar('✓ Photo enregistrée', '',
                backgroundColor: AppTheme.success, colorText: Colors.white,
                duration: const Duration(seconds: 2));
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: AppTheme.info),
            title: const Text('Choisir depuis la galerie'),
            onTap: () async {
              Navigator.pop(context);
              final ok = await _photoCtrl.pickFromGallery(
                parcelId: parcel.id, authorId: '');
              if (ok) Get.snackbar('✓ Photo ajoutée', '',
                backgroundColor: AppTheme.success, colorText: Colors.white);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await RnaConfirmDialog.show(context,
      title: 'Supprimer cette parcelle?',
      message: '"${parcel.name}" sera supprimée. Action irréversible.',
      confirmLabel: 'Supprimer', confirmColor: AppTheme.error);
    if (ok) {
      await ParcelController.to.delete(parcel.localId);
      Get.back();
      Get.snackbar('Parcelle supprimée', '',
        backgroundColor: AppTheme.success, colorText: Colors.white);
    }
  }
}

// ── Mini carte ────────────────────────────────────────────────

class _MiniMap extends StatelessWidget {
  final ParcelModel parcel;
  const _MiniMap({required this.parcel});
  @override
  Widget build(BuildContext context) => FlutterMap(
    options: MapOptions(
      initialCenter: LatLng(parcel.latitude, parcel.longitude),
      initialZoom: 14,
      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.rna.guide',
        tileProvider: CachedTileProvider(),
      ),
      if ((parcel.gpsPoints?.length ?? 0) >= 3)
        PolygonLayer(polygons: [Polygon(
          points: parcel.gpsPoints!
            .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
            .toList(),
          color: AppTheme.primary.withOpacity(0.25),
          borderColor: AppTheme.primary,
          borderStrokeWidth: 2.5,
        )]),
      MarkerLayer(markers: [Marker(
        point: LatLng(parcel.latitude, parcel.longitude),
        child: const Icon(Icons.location_on, color: AppTheme.error, size: 36),
      )]),
    ],
  );
}

// ── KPIs ──────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final ParcelModel parcel;
  const _KpiRow({required this.parcel});
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(children: [
      Expanded(child: MetricTile(label: 'Superficie', value: '${parcel.superficie} ha', icon: Icons.straighten)),
      const SizedBox(width: 6),
      Expanded(child: MetricTile(label: 'Inventaires', value: '${parcel.inventoriesCount}', icon: Icons.list_alt, color: AppTheme.info)),
      const SizedBox(width: 6),
      Expanded(child: MetricTile(label: 'Photos', value: '${parcel.photosCount}', icon: Icons.photo_camera, color: const Color(0xFF9B5DE5))),
      const SizedBox(width: 6),
      Expanded(child: MetricTile(
        label: 'Sync', value: parcel.isSynced ? '✓' : '⏳',
        icon: parcel.isSynced ? Icons.cloud_done : Icons.cloud_upload,
        color: AppTheme.syncStatusColor(parcel.syncStatus))),
    ]),
  );
}

// ── Onglet Infos ──────────────────────────────────────────────

class _InfoTab extends StatelessWidget {
  final ParcelModel parcel;
  const _InfoTab({required this.parcel});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      RnaInfoCard(title: 'Localisation', items: {
        'Région': parcel.region, 'Province': parcel.province,
        'Commune': parcel.commune, 'Village': parcel.village,
      }),
      const SizedBox(height: 12),
      RnaInfoCard(title: 'GPS', color: AppTheme.info, items: {
        'Latitude': parcel.latitude.toStringAsFixed(6),
        'Longitude': parcel.longitude.toStringAsFixed(6),
        'Superficie': '${parcel.superficie} ha',
        'Points délimitation': '${parcel.gpsPoints?.length ?? 0}',
      }),
      if (parcel.notes?.isNotEmpty == true) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.info.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.info.withOpacity(0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.notes, size: 16, color: AppTheme.info),
              SizedBox(width: 8),
              Text('Notes', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.info)),
            ]),
            const SizedBox(height: 8),
            Text(parcel.notes!, style: const TextStyle(fontSize: 13, height: 1.5)),
          ]),
        ),
      ],
      const SizedBox(height: 80),
    ],
  );
}

// ── Onglet Inventaires ────────────────────────────────────────

class _InventoryTab extends StatelessWidget {
  final ParcelModel parcel;
  final InventoryController ctrl;
  const _InventoryTab({required this.parcel, required this.ctrl});

  @override
  Widget build(BuildContext context) => Obx(() {
    if (ctrl.isLoading.value) return ListView(padding: const EdgeInsets.all(16),
      children: List.generate(3, (_) => const RnaShimmerCard(height: 120)));

    if (ctrl.inventories.isEmpty) return RnaEmptyState(
      icon: Icons.list_alt, title: 'Aucun inventaire',
      subtitle: 'Réalisez le premier inventaire RNA de cette parcelle',
      buttonLabel: 'Faire un inventaire',
      onButton: () => Get.toNamed(Routes.inventoryForm, arguments: parcel));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: ctrl.inventories.length,
      itemBuilder: (_, i) {
        final inv = ctrl.inventories[i];
        final sl = inv.season == 'HIVERNAGE' ? '🌧️ Hivernage' : '☀️ Saison sèche';
        return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('$sl ${inv.year}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              if (inv.isValidated) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: const Text('✓ Validé', style: TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _Kpi('Total', '${inv.totalPieds}', AppTheme.primary),
              const SizedBox(width: 12),
              _Kpi('RNA', '${inv.selectedPieds}', AppTheme.success),
              const SizedBox(width: 12),
              _Kpi('Espèces', '${inv.species.length}', AppTheme.secondary),
            ]),
            if (inv.species.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: inv.species.map((sp) {
                final name = sp.species?.localNameFr ?? sp.species?.scientificName ?? '?';
                return Chip(
                  label: Text('$name · ${sp.selectedPieds}', style: const TextStyle(fontSize: 10)),
                  backgroundColor: AppTheme.primary.withOpacity(0.07),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              }).toList()),
            ],
            if (!inv.isValidated) Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                label: const Text('Supprimer', style: TextStyle(color: AppTheme.error, fontSize: 12)),
                onPressed: () => ctrl.delete(inv.localId),
              ),
            ),
          ]),
        ));
      },
    );
  });
}

class _Kpi extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Kpi(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
    Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
  ]);
}

// ── Onglet Exploitations ──────────────────────────────────────

class _ExploitationTab extends StatelessWidget {
  final ParcelModel parcel;
  final ExploitationController ctrl;
  const _ExploitationTab({required this.parcel, required this.ctrl});

  @override
  Widget build(BuildContext context) => Obx(() {
    if (ctrl.isLoading.value) return ListView(padding: const EdgeInsets.all(16),
      children: List.generate(3, (_) => const RnaShimmerCard(height: 90)));

    if (ctrl.exploitations.isEmpty) return RnaEmptyState(
      icon: Icons.shopping_basket_outlined, title: 'Aucune récolte',
      subtitle: 'Enregistrez vos récoltes de produits RNA',
      buttonLabel: 'Enregistrer une récolte',
      onButton: () => Get.toNamed(Routes.exploitationForm, arguments: parcel));

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), children: [
      if (ctrl.totalRevenueFCFA > 0) Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.secondary.withOpacity(0.85), AppTheme.success.withOpacity(0.85)]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Revenus totaux enregistrés', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text('${ctrl.totalRevenueFCFA.toStringAsFixed(0)} FCFA',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
          ]),
        ]),
      ),
      ...ctrl.exploitations.map((exp) => Dismissible(
        key: Key(exp.localId),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (_) => RnaConfirmDialog.show(context,
          title: 'Supprimer?', message: 'Suppression irréversible.',
          confirmLabel: 'Supprimer', confirmColor: AppTheme.error),
        onDismissed: (_) => ctrl.delete(exp.localId),
        child: Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(ctrl.productIcon(exp.productType),
              style: const TextStyle(fontSize: 20))),
          ),
          title: Text('${ctrl.productLabel(exp.productType)} — ${exp.quantity} ${exp.unit}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: Text(
            '${DateFormat('dd/MM/yyyy').format(exp.exploitedAt)} • ${exp.destination}'
            '${exp.priceXOF != null ? ' • ${exp.priceXOF!.toStringAsFixed(0)} FCFA' : ''}',
            style: const TextStyle(fontSize: 11)),
        )),
      )),
    ]);
  });
}

// ── Onglet Photos ─────────────────────────────────────────────

class _PhotoTab extends StatelessWidget {
  final ParcelModel parcel;
  final PhotoController ctrl;
  const _PhotoTab({required this.parcel, required this.ctrl});

  @override
  Widget build(BuildContext context) => Obx(() {
    if (ctrl.photos.isEmpty && !ctrl.isLoading.value) return RnaEmptyState(
      icon: Icons.photo_camera_outlined,
      title: 'Aucune photo',
      subtitle: 'Documentez l\'état de votre\nparcelle RNA avec des photos');

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
      itemCount: ctrl.photos.length,
      itemBuilder: (_, i) {
        final photo = ctrl.photos[i];
        final localPath = photo['local_path'] as String?;
        final pending = photo['sync_status'] == 'PENDING';
        return GestureDetector(
          onLongPress: () async {
            final ok = await RnaConfirmDialog.show(context,
              title: 'Supprimer la photo?',
              message: 'Cette action est irréversible.',
              confirmLabel: 'Supprimer', confirmColor: AppTheme.error);
            if (ok) ctrl.delete(photo['local_id'] as String, parcel.id);
          },
          child: Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _PhotoThumbnail(
                localPath: localPath,
                storageUrl: photo['storage_url'] as String?,
              ),
            ),
            if (pending) Positioned(top: 5, right: 5,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppTheme.warning, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.cloud_upload, size: 11, color: Colors.white),
              )),
          ]),
        );
      },
    );
  });
}

// ── Miniature photo (local ou Supabase) ───────────────────────

class _PhotoThumbnail extends StatelessWidget {
  final String? localPath;
  final String? storageUrl;
  const _PhotoThumbnail({this.localPath, this.storageUrl});

  @override
  Widget build(BuildContext context) {
    if (storageUrl != null && storageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: storageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => Container(
          color: AppTheme.primary.withOpacity(0.08),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }
    if (localPath != null && localPath!.isNotEmpty) {
      final file = File(localPath!);
      return FutureBuilder<bool>(
        future: file.exists(),
        builder: (_, snap) => snap.data == true
            ? Image.file(file, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
            : _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
    color: AppTheme.primary.withOpacity(0.08),
    child: const Center(child: Icon(Icons.photo, size: 32, color: AppTheme.primary)),
  );
}

class _StickyTabBar extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _StickyTabBar(this.tabBar);
  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;
  @override Widget build(_, __, ___) => Container(color: Colors.white, child: tabBar);
  @override bool shouldRebuild(_) => false;
}
