// ============================================================
// RNA Guide - Page Profil Utilisateur
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/sync/sync_manager.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/map_cache_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../widgets/common_widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _ctrl = Get.put(ProfileController());
  final _mapCtrl = Get.put(MapCacheController());
  final _stats = <String, int>{}.obs;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final s = await _ctrl.getUserStats();
    _stats.value = s;
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthController.to.currentUser.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Avatar + nom ──
          Center(
            child: Column(children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 16, offset: const Offset(0, 4),
                  )],
                ),
                child: Center(child: Text(
                  user?.initials ?? '?',
                  style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white,
                  ),
                )),
              ),
              const SizedBox(height: 14),
              Text(user?.fullName ?? '—',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.roleColor(user?.role ?? '').withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _roleLabel(user?.role ?? ''),
                  style: TextStyle(
                    color: AppTheme.roleColor(user?.role ?? ''),
                    fontWeight: FontWeight.w700, fontSize: 13,
                  ),
                ),
              ),
              if (user?.region != null) ...[
                const SizedBox(height: 6),
                Text('📍 ${user!.region}${user.commune != null ? ' • ${user.commune}' : ''}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ]),
          ),
          const SizedBox(height: 24),

          // ── Statistiques ──
          Obx(() {
            if (_stats.isEmpty) return const SizedBox.shrink();
            return Column(children: [
              SectionHeader(title: 'Mes activités', icon: Icons.bar_chart),
              Row(children: [
                Expanded(child: MetricTile(
                  label: 'Parcelles',
                  value: '${_stats['parcels'] ?? 0}',
                  icon: Icons.agriculture,
                )),
                const SizedBox(width: 8),
                Expanded(child: MetricTile(
                  label: 'Inventaires',
                  value: '${_stats['inventories'] ?? 0}',
                  icon: Icons.list_alt,
                  color: AppTheme.info,
                )),
                const SizedBox(width: 8),
                Expanded(child: MetricTile(
                  label: 'Photos',
                  value: '${_stats['photos'] ?? 0}',
                  icon: Icons.photo_camera,
                  color: const Color(0xFF9B5DE5),
                )),
                const SizedBox(width: 8),
                Expanded(child: MetricTile(
                  label: 'Récoltes',
                  value: '${_stats['exploitations'] ?? 0}',
                  icon: Icons.shopping_basket,
                  color: AppTheme.secondary,
                )),
              ]),
              const SizedBox(height: 20),
            ]);
          }),

          // ── Sync status ──
          Obx(() {
            final pending = SyncManager.instance.pendingCount.value;
            final syncStatus = SyncManager.instance.status.value;
            final lastSync = SyncManager.instance.lastSyncAt.value;
            final color = syncStatus == SyncStatus.idle && pending == 0
                ? AppTheme.success
                : syncStatus == SyncStatus.noNetwork
                    ? AppTheme.warning
                    : AppTheme.info;
            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(_syncIcon(syncStatus), color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_syncLabel(syncStatus, pending),
                    style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
                  if (lastSync.isNotEmpty)
                    Text('Dernière sync: ${_formatSync(lastSync)}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ])),
                TextButton(
                  onPressed: () => SyncManager.instance.syncNow(),
                  child: const Text('Sync'),
                ),
              ]),
            );
          }),

          // ── Infos compte ──
          SectionHeader(title: 'Informations du compte', icon: Icons.person),
          RnaInfoCard(title: 'Contact', items: {
            'Téléphone': user?.phone ?? '—',
            'Email': user?.email ?? '—',
          }),
          const SizedBox(height: 12),
          RnaInfoCard(title: 'Localisation', items: {
            'Région': user?.region ?? '—',
            'Province': user?.province ?? '—',
            'Commune': user?.commune ?? '—',
            'Village': user?.village ?? '—',
          }),
          const SizedBox(height: 20),

          // ── Langue ──
          SectionHeader(title: 'Langue', icon: Icons.language),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                _LangButton(label: '🇫🇷 Français', locale: const Locale('fr', 'FR')),
                const SizedBox(width: 8),
                _LangButton(label: 'Mooré', locale: const Locale('mos', 'BF')),
                const SizedBox(width: 8),
                _LangButton(label: 'Dioula', locale: const Locale('dyu', 'BF')),
              ]),
            ),
          ),
          const SizedBox(height: 8),

          // ── Carte offline ──
          SectionHeader(title: 'Carte offline', icon: Icons.map),
          Obx(() {
            final stats = _mapCtrl.stats.value;
            final isDownloading = _mapCtrl.isDownloading.value;
            final progress = _mapCtrl.progress.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(
                      stats.tileCount > 0 ? Icons.offline_pin : Icons.cloud_download_outlined,
                      color: stats.tileCount > 0 ? AppTheme.success : AppTheme.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      stats.tileCount > 0
                          ? '${stats.tileCount} tuiles — ${stats.formattedSize}'
                          : 'Carte non téléchargée',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    )),
                  ]),
                  if (isDownloading) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: progress, backgroundColor: Colors.grey[200]),
                    const SizedBox(height: 4),
                    Text('${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                  const SizedBox(height: 12),
                  Row(children: [
                    if (!isDownloading)
                      Expanded(child: ElevatedButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Télécharger BF'),
                        onPressed: _mapCtrl.startDownload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ))
                    else
                      Expanded(child: OutlinedButton.icon(
                        icon: const Icon(Icons.stop, size: 16),
                        label: const Text('Annuler'),
                        onPressed: _mapCtrl.cancelDownload,
                      )),
                    if (stats.tileCount > 0) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                        label: const Text('Vider', style: TextStyle(color: AppTheme.error)),
                        onPressed: () async {
                          await _mapCtrl.clearCache();
                          Get.snackbar('Cache supprimé', '',
                            backgroundColor: AppTheme.success, colorText: Colors.white,
                            duration: const Duration(seconds: 2));
                        },
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.error)),
                      ),
                    ],
                  ]),
                ]),
              ),
            );
          }),

          // ── Actions ──
          SectionHeader(title: 'Paramètres', icon: Icons.settings),

          _SettingsTile(
            icon: Icons.edit,
            label: 'Modifier mon profil',
            onTap: () => _showEditProfileSheet(context),
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            label: 'Changer mon mot de passe',
            onTap: () => _showChangePasswordSheet(context),
          ),
          _SettingsTile(
            icon: Icons.sync,
            label: 'Forcer la synchronisation',
            onTap: () async {
              await SyncManager.instance.syncNow();
              Get.snackbar('Sync', 'Synchronisation terminée',
                backgroundColor: AppTheme.success, colorText: Colors.white);
            },
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            label: 'Version de l\'application',
            trailing: const Text('v1.0.0', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
          const SizedBox(height: 16),

          // ── Déconnexion ──
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout, color: AppTheme.error),
            label: const Text('Déconnexion', style: TextStyle(color: AppTheme.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.error),
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Modifier le profil ────────────────────────────────────

  void _showEditProfileSheet(BuildContext context) {
    final user = AuthController.to.currentUser.value;
    final firstNameCtrl = TextEditingController(text: user?.firstName);
    final lastNameCtrl = TextEditingController(text: user?.lastName);
    final regionCtrl = TextEditingController(text: user?.region);
    final communeCtrl = TextEditingController(text: user?.commune);
    final villageCtrl = TextEditingController(text: user?.village);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          builder: (_, ctrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Modifier mon profil',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Expanded(child: ListView(controller: ctrl, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                TextFormField(controller: firstNameCtrl,
                  decoration: const InputDecoration(labelText: 'Prénom', prefixIcon: Icon(Icons.person))),
                const SizedBox(height: 12),
                TextFormField(controller: lastNameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom', prefixIcon: Icon(Icons.person_outline))),
                const SizedBox(height: 12),
                TextFormField(controller: regionCtrl,
                  decoration: const InputDecoration(labelText: 'Région', prefixIcon: Icon(Icons.map))),
                const SizedBox(height: 12),
                TextFormField(controller: communeCtrl,
                  decoration: const InputDecoration(labelText: 'Commune', prefixIcon: Icon(Icons.location_city))),
                const SizedBox(height: 12),
                TextFormField(controller: villageCtrl,
                  decoration: const InputDecoration(labelText: 'Village', prefixIcon: Icon(Icons.home))),
                const SizedBox(height: 24),
                Obx(() => RnaButton(
                  label: 'Enregistrer',
                  isLoading: _ctrl.isSaving.value,
                  onPressed: () async {
                    final ok = await _ctrl.updateProfile({
                      'firstName': firstNameCtrl.text.trim(),
                      'lastName': lastNameCtrl.text.trim(),
                      'region': regionCtrl.text.trim(),
                      'commune': communeCtrl.text.trim(),
                      'village': villageCtrl.text.trim(),
                    });
                    if (ok) {
                      Navigator.pop(context);
                      setState(() {}); // refresh UI
                      Get.snackbar('✓ Profil mis à jour', '',
                        backgroundColor: AppTheme.success, colorText: Colors.white);
                    }
                  },
                )),
                const SizedBox(height: 16),
              ])),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Changer le mot de passe ───────────────────────────────

  void _showChangePasswordSheet(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool showCurrent = false, showNew = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setModalState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Changer mon mot de passe',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
              controller: currentCtrl,
              obscureText: !showCurrent,
              decoration: InputDecoration(
                labelText: 'Mot de passe actuel',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(showCurrent ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setModalState(() => showCurrent = !showCurrent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: !showNew,
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe (min 8 caractères)',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(showNew ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setModalState(() => showNew = !showNew),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmer le nouveau mot de passe',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 8),
            Obx(() {
              if (_ctrl.error.value.isNotEmpty) return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_ctrl.error.value,
                  style: const TextStyle(color: AppTheme.error, fontSize: 12)),
              );
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 16),
            Obx(() => RnaButton(
              label: 'Changer le mot de passe',
              isLoading: _ctrl.isSaving.value,
              onPressed: () async {
                if (newCtrl.text != confirmCtrl.text) {
                  _ctrl.error.value = 'Les mots de passe ne correspondent pas';
                  return;
                }
                await _ctrl.changePassword(
                  currentPassword: currentCtrl.text,
                  newPassword: newCtrl.text,
                );
              },
            )),
            const SizedBox(height: 8),
          ]),
        ),
      )),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await RnaConfirmDialog.show(
      context,
      title: 'Déconnexion',
      message: 'Vos données locales sont conservées. Vous pourrez vous reconnecter avec vos identifiants.',
      confirmLabel: 'Se déconnecter',
      confirmColor: AppTheme.error,
    );
    if (ok) await AuthController.to.logout();
  }

  String _roleLabel(String role) => switch (role) {
    'ADMIN'         => '⚙️ Administrateur',
    'SUPERVISEUR'   => '👁️ Superviseur',
    'AGENT_TERRAIN' => '🚶 Agent terrain',
    'PRODUCTEUR'    => '👤 Producteur',
    _               => role,
  };

  IconData _syncIcon(SyncStatus s) => switch (s) {
    SyncStatus.idle      => Icons.cloud_done,
    SyncStatus.syncing   => Icons.sync,
    SyncStatus.error     => Icons.sync_problem,
    SyncStatus.noNetwork => Icons.wifi_off,
  };

  String _syncLabel(SyncStatus s, int pending) => switch (s) {
    SyncStatus.idle      => pending == 0 ? 'Tout synchronisé' : '$pending éléments en attente',
    SyncStatus.syncing   => 'Synchronisation en cours...',
    SyncStatus.error     => 'Erreur de synchronisation',
    SyncStatus.noNetwork => 'Hors ligne — données sauvegardées',
  };

  String _formatSync(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays} jour(s)';
  }
}

// ── Bouton sélecteur langue ───────────────────────────────────

class _LangButton extends StatelessWidget {
  final String label;
  final Locale locale;
  const _LangButton({required this.label, required this.locale});

  @override
  Widget build(BuildContext context) {
    final current = Get.locale;
    final isActive = current?.languageCode == locale.languageCode;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          Get.updateLocale(locale);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('app_locale_lang', locale.languageCode);
          await prefs.setString('app_locale_country', locale.countryCode ?? '');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppTheme.primary : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
              color: isActive ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Settings tile ─────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: trailing ?? (onTap != null
          ? const Icon(Icons.chevron_right, color: AppTheme.textSecondary)
          : null),
      onTap: onTap,
    ),
  );
}
