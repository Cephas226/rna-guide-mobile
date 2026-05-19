// RNA Guide - Sync Status Page
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/database/database_helper.dart';
import '../../controllers/parcel_controller.dart';
import '../../widgets/common_widgets.dart';

class SyncStatusPage extends StatefulWidget {
  const SyncStatusPage({super.key});
  @override State<SyncStatusPage> createState() => _SyncStatusPageState();
}

class _SyncStatusPageState extends State<SyncStatusPage> {
  final _queue = <Map<String, dynamic>>[].obs;

  @override
  void initState() { super.initState(); _loadQueue(); }

  Future<void> _loadQueue() async {
    final items = await DatabaseHelper.instance.query('sync_queue', orderBy: 'created_at DESC', limit: 50);
    _queue.value = items;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Synchronisation'),
      actions: [IconButton(icon: const Icon(Icons.refresh),
        onPressed: () async { await SyncManager.instance.syncNow(); _loadQueue(); })]),
    body: RefreshIndicator(
      onRefresh: () async { await SyncManager.instance.syncNow(); await _loadQueue(); },
      child: ListView(padding: const EdgeInsets.all(16), children: [

        // Statut principal
        Obx(() {
          final s = SyncManager.instance.status.value;
          final p = SyncManager.instance.pendingCount.value;
          final last = SyncManager.instance.lastSyncAt.value;
          final isSyncing = s == SyncStatus.syncing;
          final color = switch (s) {
            SyncStatus.idle when p == 0 => AppTheme.success,
            SyncStatus.idle             => AppTheme.warning,
            SyncStatus.syncing          => AppTheme.info,
            SyncStatus.error            => AppTheme.error,
            SyncStatus.noNetwork        => AppTheme.warning,
          };
          final title = switch (s) {
            SyncStatus.idle when p == 0 => 'Tout synchronisé ✓',
            SyncStatus.idle             => '$p élément${p > 1 ? 's' : ''} en attente',
            SyncStatus.syncing          => 'Synchronisation...',
            SyncStatus.error            => 'Erreur de synchronisation',
            SyncStatus.noNetwork        => 'Hors ligne',
          };
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.25))),
            child: Row(children: [
              Container(width: 54, height: 54,
                decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: isSyncing
                  ? Padding(padding: const EdgeInsets.all(14),
                      child: CircularProgressIndicator(color: color, strokeWidth: 2.5))
                  : Icon(p == 0 ? Icons.cloud_done : Icons.cloud_upload, color: color, size: 26)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
                if (last.isNotEmpty) Text(
                  'Sync: ${_fmt(last)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ])),
            ]),
          );
        }),

        // Métriques
        Obx(() => Row(children: [
          Expanded(child: MetricTile(label: 'En attente',
            value: '${SyncManager.instance.pendingCount.value}',
            icon: Icons.upload,
            color: SyncManager.instance.pendingCount.value > 0 ? AppTheme.warning : AppTheme.success)),
          const SizedBox(width: 8),
          Expanded(child: MetricTile(label: 'Conflits',
            value: '${SyncManager.instance.conflicts.length}',
            icon: Icons.warning_amber,
            color: SyncManager.instance.conflicts.isNotEmpty ? AppTheme.error : AppTheme.success)),
          const SizedBox(width: 8),
          Expanded(child: MetricTile(label: 'Parcelles',
            value: '${ParcelController.to.parcels.length}',
            icon: Icons.agriculture)),
        ])),
        const SizedBox(height: 16),

        // Bouton sync
        Obx(() {
          final isSyncing = SyncManager.instance.status.value == SyncStatus.syncing;
          return RnaButton(
            label: isSyncing ? 'Synchronisation...' : 'Synchroniser maintenant',
            isLoading: isSyncing,
            icon: Icons.sync,
            onPressed: isSyncing ? null : () async {
              await SyncManager.instance.syncNow();
              _loadQueue();
            },
          );
        }),
        const SizedBox(height: 20),

        // Conflits
        Obx(() {
          final conflicts = SyncManager.instance.conflicts;
          if (conflicts.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: '⚠️ Conflits (${conflicts.length})', icon: Icons.warning_amber),
            ...conflicts.map((c) => Card(
              color: AppTheme.error.withOpacity(0.04),
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
                Row(children: [
                  const Icon(Icons.warning_amber, color: AppTheme.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Conflit: ${c.entityType}',
                    style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
                const SizedBox(height: 8),
                const Text(
                  'Le serveur a des données plus récentes. Quelle version conserver?',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => SyncManager.instance.conflicts.remove(c),
                    child: const Text('Mon version', style: TextStyle(fontSize: 12)))),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton(
                    onPressed: () => SyncManager.instance.conflicts.remove(c),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                    child: const Text('Serveur', style: TextStyle(fontSize: 12)))),
                ]),
              ])),
            )),
            const SizedBox(height: 8),
          ]);
        }),

        // Queue
        SectionHeader(title: 'File d\'attente', icon: Icons.queue),
        Obx(() {
          if (_queue.isEmpty) return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(children: [
              Icon(Icons.cloud_done, size: 48, color: AppTheme.success),
              SizedBox(height: 8),
              Text('File vide — tout est synchronisé',
                style: TextStyle(color: AppTheme.textSecondary)),
            ]),
          ));

          return Column(children: _queue.take(20).map((item) {
            final type = item['entity_type'] as String? ?? '?';
            final action = item['action'] as String? ?? '?';
            final status = item['status'] as String? ?? 'PENDING';
            final attempts = item['attempts'] as int? ?? 0;
            final color = status == 'FAILED' ? AppTheme.error
              : status == 'CONFLICT' ? AppTheme.warning
              : AppTheme.info;
            final icon = switch (type) {
              'parcel'       => '🌿',
              'inventory'    => '📋',
              'exploitation' => '🌾',
              'photo'        => '📷',
              _              => '📦',
            };
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.15))),
              child: Row(children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$action $type', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  if (item['created_at'] != null) Text(
                    _fmt(item['created_at'] as String),
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ])),
                if (attempts > 0) Text('$attempts ×',
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
              ]),
            );
          }).toList());
        }),

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.info.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.info.withOpacity(0.2))),
          child: const Text(
            '💡 Toutes vos données sont sauvegardées localement. La synchronisation est automatique à la reconnexion.',
            style: TextStyle(fontSize: 12, color: AppTheme.info, height: 1.5)),
        ),
        const SizedBox(height: 32),
      ]),
    ),
  );

  String _fmt(String iso) {
    final dt = DateTime.tryParse(iso); if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return DateFormat('dd/MM HH:mm').format(dt);
  }
}
