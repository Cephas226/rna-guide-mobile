// ============================================================
// RNA Guide - Formulaire Parcelle RNA
// Avec capture GPS automatique et délimitation points
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import '../../controllers/parcel_controller.dart';
import '../../models/models.dart';
import '../../routes/app_pages.dart';

class ParcelFormPage extends StatefulWidget {
  const ParcelFormPage({super.key});
  @override
  State<ParcelFormPage> createState() => _ParcelFormPageState();
}

class _ParcelFormPageState extends State<ParcelFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ParcelModel? _existing = Get.arguments as ParcelModel?;
  final _data = <String, dynamic>{};
  bool _loadingGps = false;
  final List<Map<String, double>> _gpsPoints = [];

  final _regions = [
    'Boucle du Mouhoun', 'Cascades', 'Centre', 'Centre-Est',
    'Centre-Nord', 'Centre-Ouest', 'Centre-Sud', 'Est',
    'Hauts-Bassins', 'Nord', 'Plateau-Central', 'Sahel', 'Sud-Ouest',
  ];
  final _saisons = ['Hivernage (juin-octobre)', 'Saison sèche (nov-mai)'];

  @override
  void initState() {
    super.initState();
    if (_existing != null) {
      _data.addAll({
        'name': _existing!.name,
        'region': _existing!.region,
        'province': _existing!.province,
        'commune': _existing!.commune,
        'village': _existing!.village,
        'superficie': _existing!.superficie,
        'latitude': _existing!.latitude,
        'longitude': _existing!.longitude,
        'notes': _existing!.notes,
      });
      if (_existing!.gpsPoints != null) {
        _gpsPoints.addAll(_existing!.gpsPoints!
          .map((p) => {'lat': p['lat'] as double, 'lng': p['lng'] as double}));
      }
    }
  }

  Future<void> _captureGps() async {
    setState(() => _loadingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Get.snackbar('GPS', 'Activez la localisation dans les paramètres',
          backgroundColor: AppTheme.error, colorText: Colors.white);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      setState(() {
        _data['latitude'] = pos.latitude;
        _data['longitude'] = pos.longitude;
      });
      Get.snackbar('GPS', 'Position capturée: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
        backgroundColor: AppTheme.success, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('GPS', 'Erreur: $e', backgroundColor: AppTheme.error, colorText: Colors.white);
    } finally {
      setState(() => _loadingGps = false);
    }
  }

  Future<void> _addGpsPoint() async {
    setState(() => _loadingGps = true);
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _gpsPoints.add({'lat': pos.latitude, 'lng': pos.longitude});
        _data['gpsPoints'] = _gpsPoints;
      });
      Get.snackbar('Point ajouté', 'Point ${_gpsPoints.length} enregistré',
        backgroundColor: AppTheme.success, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Erreur GPS', '$e', backgroundColor: AppTheme.error, colorText: Colors.white);
    } finally {
      setState(() => _loadingGps = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_data['latitude'] == null) {
      Get.snackbar('GPS requis', 'Capturez d\'abord la position GPS',
        backgroundColor: AppTheme.warning);
      return;
    }
    _data['gpsPoints'] = _gpsPoints;

    ParcelModel? result;
    if (_existing != null) {
      await ParcelController.to.updateParcel(_existing!.localId, _data);
      result = _existing;
    } else {
      result = await ParcelController.to.create(_data);
    }

    if (result != null) {
      final parcelName = result.name;
      if (_existing != null) {
        Get.snackbar('✓ Parcelle modifiée', parcelName,
          backgroundColor: AppTheme.success, colorText: Colors.white,
          duration: const Duration(seconds: 3));
        Get.back();
      } else {
        Get.offAllNamed(Routes.home);
        Future.delayed(const Duration(milliseconds: 300), () {
          Get.snackbar('✓ Parcelle créée', parcelName,
            backgroundColor: AppTheme.success, colorText: Colors.white,
            duration: const Duration(seconds: 3));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing != null ? 'Modifier la parcelle' : 'Nouvelle parcelle RNA'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Section: Identification ──
            _SectionHeader(title: 'Identification', icon: Icons.label),
            TextFormField(
              initialValue: _data['name'],
              decoration: const InputDecoration(
                labelText: 'Nom de la parcelle *',
                hintText: 'Ex: Champ RNA Koudtenga 1',
                prefixIcon: Icon(Icons.agriculture),
              ),
              onChanged: (v) => _data['name'] = v,
              validator: (v) => v!.isEmpty ? 'Nom requis' : null,
            ),
            const SizedBox(height: 12),

            // ── Section: Localisation ──
            _SectionHeader(title: 'Localisation', icon: Icons.location_on),
            DropdownButtonFormField<String>(
              value: _data['region'],
              decoration: const InputDecoration(
                labelText: 'Région *', prefixIcon: Icon(Icons.map),
              ),
              items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() => _data['region'] = v),
              validator: (v) => v == null ? 'Région requise' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(
                initialValue: _data['province'],
                decoration: const InputDecoration(labelText: 'Province *'),
                onChanged: (v) => _data['province'] = v,
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                initialValue: _data['commune'],
                decoration: const InputDecoration(labelText: 'Commune *'),
                onChanged: (v) => _data['commune'] = v,
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              )),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _data['village'],
              decoration: const InputDecoration(
                labelText: 'Village *', prefixIcon: Icon(Icons.home),
              ),
              onChanged: (v) => _data['village'] = v,
              validator: (v) => v!.isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _data['superficie']?.toString(),
              decoration: const InputDecoration(
                labelText: 'Superficie (hectares) *',
                prefixIcon: Icon(Icons.straighten),
                hintText: '2.5',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => _data['superficie'] = double.tryParse(v) ?? 0,
              validator: (v) {
                if (v!.isEmpty) return 'Requis';
                if (double.tryParse(v) == null) return 'Nombre invalide';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Section: GPS ──
            _SectionHeader(title: 'Position GPS', icon: Icons.gps_fixed),
            if (_data['latitude'] != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: AppTheme.success),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Position GPS capturée', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${(_data['latitude'] as double).toStringAsFixed(5)}, ${(_data['longitude'] as double).toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ]),
                ]),
              ),
            OutlinedButton.icon(
              onPressed: _loadingGps ? null : _captureGps,
              icon: _loadingGps
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
              label: Text(_data['latitude'] == null ? 'Capturer la position GPS' : 'Recapturer la position'),
            ),
            const SizedBox(height: 8),

            // ── Points délimitation ──
            Row(children: [
              const Text('Points de délimitation: ',
                style: TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
              Text('${_gpsPoints.length} points',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary)),
            ]),
            const SizedBox(height: 4),
            Wrap(spacing: 8, runSpacing: 4, children: [
              ..._gpsPoints.asMap().entries.map((e) => Chip(
                label: Text('P${e.key + 1}', style: const TextStyle(fontSize: 11)),
                backgroundColor: AppTheme.primaryLight.withOpacity(0.2),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => setState(() => _gpsPoints.removeAt(e.key)),
              )),
              ActionChip(
                label: const Text('+ Point GPS', style: TextStyle(fontSize: 11)),
                onPressed: _loadingGps ? null : _addGpsPoint,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
              ),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Déplacez-vous aux coins de la parcelle et appuyez sur "+ Point GPS" pour chaque coin. Minimum 3 points pour le polygone.',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),

            // ── Notes ──
            TextFormField(
              initialValue: _data['notes'],
              decoration: const InputDecoration(
                labelText: 'Notes (optionnel)',
                prefixIcon: Icon(Icons.notes),
                hintText: 'Observations particulières, accord foncier...',
              ),
              maxLines: 3,
              onChanged: (v) => _data['notes'] = v,
            ),
            const SizedBox(height: 24),

            // ── Boutons ──
            Obx(() => ElevatedButton(
              onPressed: ParcelController.to.isSaving.value ? null : _submit,
              child: ParcelController.to.isSaving.value
                ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Enregistrement...'),
                  ])
                : Text(_existing != null ? 'Enregistrer les modifications' : 'Créer la parcelle'),
            )),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: Get.back, child: const Text('Annuler')),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Row(children: [
      Icon(icon, size: 18, color: AppTheme.primary),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.primary)),
    ]),
  );
}
