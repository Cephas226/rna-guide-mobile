// ============================================================
// RNA Guide - Guides & Formations RNA
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/database_helper.dart';
import '../../models/models.dart';

class FormationsPage extends StatefulWidget {
  const FormationsPage({super.key});
  @override
  State<FormationsPage> createState() => _FormationsPageState();
}

class _FormationsPageState extends State<FormationsPage> {
  List<FormationModel> _formations = [];
  bool _loading = true;
  String _selectedCategory = 'all';

  final _categories = {
    'all': 'Tous',
    'technique_rna': 'Technique RNA',
    'botanique': 'Botanique',
    'economique': 'Économie',
    'entretien': 'Entretien',
  };

  @override
  void initState() {
    super.initState();
    _loadFormations();
  }

  Future<void> _loadFormations() async {
    final results = await DatabaseHelper.instance.query(
      'formations',
      where: _selectedCategory != 'all' ? 'category = ?' : null,
      whereArgs: _selectedCategory != 'all' ? [_selectedCategory] : null,
      orderBy: 'order_index ASC',
    );
    setState(() {
      _formations = results.map((r) => FormationModel.fromMap(r)).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        // ── Filtres catégories ──
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: _categories.entries.map((e) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(e.value),
                selected: _selectedCategory == e.key,
                onSelected: (_) {
                  setState(() { _selectedCategory = e.key; _loading = true; });
                  _loadFormations();
                },
                selectedColor: AppTheme.primary.withOpacity(0.2),
                checkmarkColor: AppTheme.primary,
              ),
            )).toList(),
          ),
        ),

        // ── Liste ──
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _formations.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.menu_book, size: 64, color: AppTheme.textDisabled),
                  SizedBox(height: 16),
                  Text('Guides non disponibles hors ligne',
                    style: TextStyle(color: AppTheme.textSecondary)),
                  Text('Synchronisez pour accéder aux guides',
                    style: TextStyle(fontSize: 12, color: AppTheme.textDisabled)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _formations.length,
                  itemBuilder: (_, i) => _FormationCard(formation: _formations[i]),
                ),
        ),
      ]),
    );
  }
}

class _FormationCard extends StatelessWidget {
  final FormationModel formation;
  const _FormationCard({required this.formation});

  static const _catColors = {
    'technique_rna': AppTheme.primary,
    'botanique': AppTheme.success,
    'economique': AppTheme.secondary,
    'entretien': AppTheme.accent,
  };

  @override
  Widget build(BuildContext context) {
    final color = _catColors[formation.category] ?? AppTheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetail(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.menu_book, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(formation.titleFr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(formation.category.replaceAll('_', ' '),
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
              ),
            ])),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ]),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: AppTheme.divider, borderRadius: BorderRadius.circular(2),
            )),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(formation.titleFr,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            Expanded(child: ListView(controller: ctrl, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
              Text(formation.contentFr, style: const TextStyle(fontSize: 14, height: 1.7, color: AppTheme.textPrimary)),
              const SizedBox(height: 32),
            ])),
          ]),
        ),
      ),
    );
  }
}
