// ============================================================
// RNA Guide - Carte des Parcelles (Flutter Map)
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/map/tile_cache_service.dart';
import '../../controllers/parcel_controller.dart';
import '../../models/models.dart';
import '../../routes/app_pages.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _mapController = MapController();
  // Centre du Burkina Faso
  static const _bfCenter = LatLng(12.3647, -1.5333);
  ParcelModel? _selectedParcel;
  bool _showSatellite = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // ── Carte ──
        Obx(() {
          final parcels = ParcelController.to.parcels;
          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _bfCenter,
              initialZoom: 6.5,
              onTap: (_, __) => setState(() => _selectedParcel = null),
            ),
            children: [
              TileLayer(
                urlTemplate: _showSatellite
                  ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rna.guide',
                tileProvider: _showSatellite ? NetworkTileProvider() : CachedTileProvider(),
              ),

              // ── Polygones parcelles ──
              PolygonLayer(
                polygons: parcels
                  .where((p) => p.gpsPoints != null && p.gpsPoints!.length >= 3)
                  .map((p) => Polygon(
                    points: p.gpsPoints!.map((pt) => LatLng(pt['lat']!, pt['lng']!)).toList(),
                    color: AppTheme.primary.withOpacity(0.2),
                    borderColor: AppTheme.primary,
                    borderStrokeWidth: 2,
                  ))
                  .toList(),
              ),

              // ── Marqueurs ──
              MarkerLayer(
                markers: parcels.map((p) => Marker(
                  point: LatLng(p.latitude, p.longitude),
                  width: 36, height: 36,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedParcel = p),
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.isSynced ? AppTheme.primary : AppTheme.warning,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.agriculture, color: Colors.white, size: 18),
                    ),
                  ),
                )).toList(),
              ),
            ],
          );
        }),

        // ── Contrôles ──
        Positioned(
          top: 16, right: 16,
          child: Column(children: [
            _MapButton(
              icon: _showSatellite ? Icons.map : Icons.satellite,
              tooltip: _showSatellite ? 'Vue plan' : 'Vue satellite',
              onTap: () => setState(() => _showSatellite = !_showSatellite),
            ),
            const SizedBox(height: 8),
            _MapButton(
              icon: Icons.my_location,
              tooltip: 'Ma position',
              onTap: () {/* GPS position */},
            ),
            const SizedBox(height: 8),
            _MapButton(
              icon: Icons.center_focus_strong,
              tooltip: 'Centrer BF',
              onTap: () => _mapController.move(_bfCenter, 6.5),
            ),
          ]),
        ),

        // ── Compteur ──
        Positioned(
          top: 16, left: 16,
          child: Obx(() => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.agriculture, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text('${ParcelController.to.parcels.length} parcelles',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          )),
        ),

        // ── Popup sélection ──
        if (_selectedParcel != null)
          Positioned(
            bottom: 24, left: 16, right: 16,
            child: _ParcelPopup(
              parcel: _selectedParcel!,
              onView: () => Get.toNamed(Routes.parcelDetail, arguments: _selectedParcel),
              onClose: () => setState(() => _selectedParcel = null),
            ),
          ),
      ]),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _MapButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Icon(icon, size: 20, color: AppTheme.primary),
      ),
    ),
  );
}

class _ParcelPopup extends StatelessWidget {
  final ParcelModel parcel;
  final VoidCallback onView;
  final VoidCallback onClose;
  const _ParcelPopup({required this.parcel, required this.onView, required this.onClose});

  @override
  Widget build(BuildContext context) => Card(
    elevation: 8,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.agriculture, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(parcel.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('${parcel.village} • ${parcel.superficie} ha',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ])),
        ElevatedButton(onPressed: onView, child: const Text('Voir')),
        const SizedBox(width: 8),
        IconButton(icon: const Icon(Icons.close), onPressed: onClose),
      ]),
    ),
  );
}
