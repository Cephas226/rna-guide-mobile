// ============================================================
// RNA Guide - Liste des Parcelles RNA
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../controllers/parcel_controller.dart';
import '../../routes/app_pages.dart';
import '../../../core/theme/app_theme.dart';
import '../../models/models.dart';

class ParcelListPage extends StatefulWidget {
  const ParcelListPage({super.key});
  @override
  State<ParcelListPage> createState() => _ParcelListPageState();
}

class _ParcelListPageState extends State<ParcelListPage> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    ParcelController.to.loadParcels();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        // ── Barre de recherche ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Rechercher une parcelle...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      ParcelController.to.loadParcels();
                    })
                : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (v) => ParcelController.to.loadParcels(search: v),
          ),
        ),

        // ── Stats rapides ──
        Obx(() {
          final total = ParcelController.to.total.value;
          final pending = ParcelController.to.parcels
              .where((p) => p.isPending).length;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              _StatChip(icon: Icons.agriculture, label: '$total parcelles', color: AppTheme.primary),
              const SizedBox(width: 8),
              if (pending > 0)
                _StatChip(icon: Icons.cloud_upload, label: '$pending en attente', color: AppTheme.warning),
            ]),
          );
        }),

        // ── Liste ──
        Expanded(
          child: Obx(() {
            if (ParcelController.to.isLoading.value) {
              return _buildShimmer();
            }
            if (ParcelController.to.parcels.isEmpty) {
              return _buildEmpty();
            }
            return RefreshIndicator(
              onRefresh: () => ParcelController.to.loadParcels(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: ParcelController.to.parcels.length,
                itemBuilder: (_, i) => _ParcelCard(
                  parcel: ParcelController.to.parcels[i],
                  onTap: () => Get.toNamed(Routes.parcelDetail,
                    arguments: ParcelController.to.parcels[i]),
                ),
              ),
            );
          }),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(Routes.parcelForm),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle parcelle'),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.agriculture, size: 80, color: AppTheme.primary.withOpacity(0.3)),
      const SizedBox(height: 16),
      Text('Aucune parcelle', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.textSecondary)),
      const SizedBox(height: 8),
      const Text('Créez votre première parcelle RNA\nen appuyant sur le bouton +',
        textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () => Get.toNamed(Routes.parcelForm),
        icon: const Icon(Icons.add),
        label: const Text('Créer une parcelle'),
        style: ElevatedButton.styleFrom(minimumSize: const Size(200, 48)),
      ),
    ]),
  );

  Widget _buildShimmer() => ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: 6,
    itemBuilder: (_, __) => Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
  );
}

class _ParcelCard extends StatelessWidget {
  final ParcelModel parcel;
  final VoidCallback onTap;
  const _ParcelCard({required this.parcel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // ── Icône statut ──
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppTheme.syncStatusColor(parcel.syncStatus).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                parcel.isSynced ? Icons.cloud_done : Icons.cloud_upload_outlined,
                color: AppTheme.syncStatusColor(parcel.syncStatus),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // ── Infos ──
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(parcel.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on, size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 2),
                Expanded(child: Text(
                  '${parcel.village} • ${parcel.commune}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                )),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                _InfoBadge(label: '${parcel.superficie} ha', icon: Icons.straighten),
                const SizedBox(width: 6),
                if (parcel.inventoriesCount > 0)
                  _InfoBadge(label: '${parcel.inventoriesCount} inv.', icon: Icons.list_alt),
              ]),
            ])),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ]),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  const _InfoBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: AppTheme.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: AppTheme.primary),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    ]),
  );
}
