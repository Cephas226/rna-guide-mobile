// ============================================================
// RNA Guide - Formulaire Inventaire RNA
// Saisie espèces avec comptage pieds sélectionnés
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/sync/sync_manager.dart';
import '../../models/models.dart';
import '../../controllers/auth_controller.dart';

const _uuid = Uuid();

class InventoryFormPage extends StatefulWidget {
  const InventoryFormPage({super.key});
  @override
  State<InventoryFormPage> createState() => _InventoryFormPageState();
}

class _InventoryFormPageState extends State<InventoryFormPage> {
  final ParcelModel parcel = Get.arguments as ParcelModel;
  final _formKey = GlobalKey<FormState>();
  List<SpeciesModel> _availableSpecies = [];
  final List<_SpeciesEntry> _entries = [];
  int _year = DateTime.now().year;
  String _season = 'HIVERNAGE';
  String? _observations;
  bool _saving = false;
  bool _loadingSpecies = true;

  @override
  void initState() {
    super.initState();
    _loadSpecies();
  }

  Future<void> _loadSpecies() async {
    final results = await DatabaseHelper.instance.query('species', orderBy: 'local_name_fr ASC');
    setState(() {
      _availableSpecies = results.map((r) => SpeciesModel.fromMap(r)).toList();
      _loadingSpecies = false;
    });
  }

  void _addSpecies(SpeciesModel species) {
    if (_entries.any((e) => e.speciesId == species.id)) return;
    setState(() => _entries.add(_SpeciesEntry(speciesId: species.id, species: species)));
  }

  void _removeSpecies(int i) => setState(() => _entries.removeAt(i));

  int get _totalPieds => _entries.fold(0, (sum, e) => sum + (int.tryParse(e.totalCtrl.text) ?? 0));
  int get _totalSelected => _entries.fold(0, (sum, e) => sum + (int.tryParse(e.selectedCtrl.text) ?? 0));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_entries.isEmpty) {
      Get.snackbar('Espèces requises', 'Ajoutez au moins une espèce',
        backgroundColor: AppTheme.warning, colorText: Colors.white);
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final localId = _uuid.v4();
      final userId = AuthController.to.currentUser.value?.id ?? '';

      final inventoryData = {
        'id': localId,
        'local_id': localId,
        'parcel_id': parcel.id,
        'agent_id': userId,
        'year': _year,
        'season': _season,
        'total_pieds': _totalPieds,
        'selected_pieds': _totalSelected,
        'observations': _observations,
        'sync_status': 'PENDING',
        'version': 1,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      await DatabaseHelper.instance.insert('inventories', inventoryData);

      // Sauvegarder les espèces
      for (final entry in _entries) {
        await DatabaseHelper.instance.insert('inventory_species', {
          'id': _uuid.v4(),
          'inventory_id': localId,
          'species_id': entry.speciesId,
          'total_pieds': int.tryParse(entry.totalCtrl.text) ?? 0,
          'selected_pieds': int.tryParse(entry.selectedCtrl.text) ?? 0,
          'health_state': entry.healthState,
          'height_cm': double.tryParse(entry.heightCtrl.text),
          'is_new_species': entry.isNew ? 1 : 0,
        });
      }

      // Ajouter à la queue sync
      await SyncManager.instance.enqueue(
        localId: localId,
        entityType: 'inventory',
        action: 'create',
        payload: {
          'localId': localId,
          'parcelId': parcel.id,
          'agentId': userId,
          'year': _year,
          'season': _season,
          'totalPieds': _totalPieds,
          'selectedPieds': _totalSelected,
          'observations': _observations,
          'species': _entries.map((e) => {
            'speciesId': e.speciesId,
            'totalPieds': int.tryParse(e.totalCtrl.text) ?? 0,
            'selectedPieds': int.tryParse(e.selectedCtrl.text) ?? 0,
            'healthState': e.healthState,
            'heightCm': double.tryParse(e.heightCtrl.text),
            'isNewSpecies': e.isNew,
          }).toList(),
        },
      );

      SyncManager.instance.syncNow();

      Get.back();
      Get.snackbar('Inventaire sauvegardé', 'Synchronisation en cours...',
        backgroundColor: AppTheme.success, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible d\'enregistrer: $e',
        backgroundColor: AppTheme.error, colorText: Colors.white);
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inventaire RNA — ${parcel.name}')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          // ── Année / Saison ──
          Row(children: [
            Expanded(child: DropdownButtonFormField<int>(
              value: _year,
              decoration: const InputDecoration(labelText: 'Année', prefixIcon: Icon(Icons.calendar_today)),
              items: List.generate(5, (i) => DateTime.now().year - i)
                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
              onChanged: (v) => setState(() => _year = v!),
            )),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<String>(
              value: _season,
              decoration: const InputDecoration(labelText: 'Saison', prefixIcon: Icon(Icons.wb_sunny)),
              items: const [
                DropdownMenuItem(value: 'HIVERNAGE', child: Text('Hivernage')),
                DropdownMenuItem(value: 'SAISON_SECHE', child: Text('Saison sèche')),
              ],
              onChanged: (v) => setState(() => _season = v!),
            )),
          ]),
          const SizedBox(height: 16),

          // ── Résumé totaux ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Expanded(child: Column(children: [
                Text('$_totalPieds', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                const Text('Total pieds', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ])),
              Container(width: 1, height: 40, color: AppTheme.divider),
              Expanded(child: Column(children: [
                Text('$_totalSelected', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.success)),
                const Text('Pieds RNA', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ])),
              Container(width: 1, height: 40, color: AppTheme.divider),
              Expanded(child: Column(children: [
                Text('${_entries.length}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.secondary)),
                const Text('Espèces', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Sélection espèces ──
          const Text('Espèces observées', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          if (_loadingSpecies)
            const Center(child: CircularProgressIndicator())
          else
            Wrap(
              spacing: 6, runSpacing: 6,
              children: _availableSpecies.map((sp) {
                final added = _entries.any((e) => e.speciesId == sp.id);
                return FilterChip(
                  label: Text(sp.localNameFr ?? sp.scientificName, style: const TextStyle(fontSize: 12)),
                  selected: added,
                  onSelected: (_) => added ? null : _addSpecies(sp),
                  selectedColor: AppTheme.primary.withOpacity(0.2),
                  checkmarkColor: AppTheme.primary,
                );
              }).toList(),
            ),
          const SizedBox(height: 16),

          // ── Saisie par espèce ──
          if (_entries.isNotEmpty) ...[
            const Text('Comptage par espèce', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            ..._entries.asMap().entries.map((e) =>
              _SpeciesEntryCard(entry: e.value, onRemove: () => _removeSpecies(e.key))
            ),
          ],
          const SizedBox(height: 12),

          // ── Observations ──
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Observations (optionnel)',
              prefixIcon: Icon(Icons.notes),
              hintText: 'Nouvelles pousses, état général, problèmes...',
            ),
            maxLines: 3,
            onChanged: (v) => _observations = v,
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
              ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  SizedBox(width: 12), Text('Enregistrement...'),
                ])
              : const Text('Enregistrer l\'inventaire'),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

// ── Entrée espèce ─────────────────────────────────────────────

class _SpeciesEntry {
  final String speciesId;
  final SpeciesModel species;
  final totalCtrl = TextEditingController();
  final selectedCtrl = TextEditingController();
  final heightCtrl = TextEditingController();
  String healthState = 'BON';
  bool isNew = false;

  _SpeciesEntry({required this.speciesId, required this.species});
}

class _SpeciesEntryCard extends StatefulWidget {
  final _SpeciesEntry entry;
  final VoidCallback onRemove;
  const _SpeciesEntryCard({required this.entry, required this.onRemove});
  @override
  State<_SpeciesEntryCard> createState() => _SpeciesEntryCardState();
}

class _SpeciesEntryCardState extends State<_SpeciesEntryCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── En-tête ──
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.entry.species.localNameFr ?? widget.entry.species.scientificName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(widget.entry.species.scientificName,
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary)),
            ])),
            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: widget.onRemove),
          ]),
          const SizedBox(height: 10),

          // ── Comptage ──
          Row(children: [
            Expanded(child: TextFormField(
              controller: widget.entry.totalCtrl,
              decoration: const InputDecoration(
                labelText: 'Total pieds',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              keyboardType: TextInputType.number,
            )),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(
              controller: widget.entry.selectedCtrl,
              decoration: const InputDecoration(
                labelText: 'Pieds RNA',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              keyboardType: TextInputType.number,
            )),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(
              controller: widget.entry.heightCtrl,
              decoration: const InputDecoration(
                labelText: 'Hauteur cm',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              keyboardType: TextInputType.number,
            )),
          ]),
          const SizedBox(height: 8),

          // ── État sanitaire ──
          Row(children: [
            const Text('État: ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ...['BON', 'MOYEN', 'MAUVAIS'].map((s) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(s, style: const TextStyle(fontSize: 11)),
                selected: widget.entry.healthState == s,
                selectedColor: s == 'BON' ? AppTheme.success.withOpacity(0.2)
                  : s == 'MOYEN' ? AppTheme.warning.withOpacity(0.2)
                  : AppTheme.error.withOpacity(0.2),
                onSelected: (_) => setState(() => widget.entry.healthState = s),
              ),
            )),
          ]),
          CheckboxListTile(
            title: const Text('Espèce nouvellement observée', style: TextStyle(fontSize: 12)),
            value: widget.entry.isNew,
            onChanged: (v) => setState(() => widget.entry.isNew = v!),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
        ]),
      ),
    );
  }
}
