import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../../controllers/rna_controller.dart';

class RnaOperationSheet extends StatefulWidget {
  final String parcelId;
  final String category;
  const RnaOperationSheet({super.key, required this.parcelId, required this.category});

  static Future<bool> show(
    BuildContext context, {
    required String parcelId,
    required String category,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RnaOperationSheet(parcelId: parcelId, category: category),
    );
    return result == true;
  }

  @override
  State<RnaOperationSheet> createState() => _RnaOperationSheetState();
}

class _RnaOperationSheetState extends State<RnaOperationSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedType;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  String? _notes;
  bool _saving = false;

  List<Map<String, String>> get _types =>
    widget.category == 'ENTRETIEN'
      ? RnaController.entretienTypes
      : RnaController.cesDrsTypes;

  bool get _notesRequired => _selectedType == 'AUTRE';

  static const _months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  Future<void> _submit() async {
    if (_selectedType == null) {
      Get.snackbar('Champ requis', 'Sélectionnez un type d\'opération',
        backgroundColor: AppTheme.warning, colorText: Colors.white);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _saving = true);
    final ok = await RnaController.to.create(
      parcelId: widget.parcelId,
      category: widget.category,
      operationType: _selectedType!,
      month: _month,
      year: _year,
      notes: _notes,
    );
    setState(() => _saving = false);

    if (ok) {
      Get.back(result: true);
      Get.snackbar('Opération enregistrée', 'Synchronisation en cours...',
        backgroundColor: AppTheme.success, colorText: Colors.white,
        duration: const Duration(seconds: 2));
    } else {
      Get.snackbar('Erreur', 'Impossible d\'enregistrer',
        backgroundColor: AppTheme.error, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.category == 'ENTRETIEN'
      ? 'Opération d\'entretien'
      : 'Aménagement CES/DRS';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Handle + Titre ──
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: 16),
            Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // ── Type (chips) ──
            const Text('Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _types.map((t) {
                final selected = _selectedType == t['value'];
                return FilterChip(
                  label: Text('${t['icon']} ${t['label']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    )),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedType = t['value']),
                  selectedColor: AppTheme.primary.withValues(alpha: 0.18),
                  checkmarkColor: AppTheme.primary,
                  backgroundColor: Colors.grey.shade100,
                  side: BorderSide(
                    color: selected ? AppTheme.primary : Colors.transparent),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Mois / Année ──
            Row(children: [
              Expanded(child: DropdownButtonFormField<int>(
                initialValue: _month,
                decoration: const InputDecoration(labelText: 'Mois'),
                items: List.generate(12, (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(_months[i]),
                )),
                onChanged: (v) => setState(() => _month = v!),
              )),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<int>(
                initialValue: _year,
                decoration: const InputDecoration(labelText: 'Année'),
                items: List.generate(5, (i) => DateTime.now().year - i)
                  .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                  .toList(),
                onChanged: (v) => setState(() => _year = v!),
              )),
            ]),
            const SizedBox(height: 16),

            // ── Notes ──
            TextFormField(
              decoration: InputDecoration(
                labelText: _notesRequired ? 'Préciser (obligatoire)' : 'Notes (optionnel)',
                prefixIcon: const Icon(Icons.notes, size: 18),
                hintText: 'Observations, détails de l\'intervention...',
              ),
              maxLines: 3,
              onSaved: (v) => _notes = v?.trim().isEmpty == true ? null : v?.trim(),
              validator: _notesRequired
                ? (v) => (v == null || v.trim().isEmpty) ? 'Précisez le type d\'opération' : null
                : null,
            ),
            const SizedBox(height: 24),

            // ── Bouton ──
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Enregistrer'),
            )),
          ]),
        ),
      ),
    );
  }
}
