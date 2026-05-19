// RNA Guide - Home Page (5 onglets)
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/sync/sync_manager.dart';
import '../../controllers/auth_controller.dart';
import '../parcels/parcel_list_page.dart';
import '../parcels/map_page.dart';
import '../formations/formations_page.dart';
import '../sync/sync_status_page.dart';
import '../profile/profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  final _pages = const [
    ParcelListPage(), MapPage(), FormationsPage(), SyncStatusPage(), ProfilePage(),
  ];
  static const _titles = ['Mes Parcelles', 'Carte RNA', 'Guides RNA', 'Synchronisation', 'Mon Profil'];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(children: [
        const Text('🌿', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(_titles[_index]),
      ]),
      actions: [
        Obx(() {
          final p = SyncManager.instance.pendingCount.value;
          final s = SyncManager.instance.status.value;
          return Stack(children: [
            IconButton(
              icon: Icon(s == SyncStatus.syncing ? Icons.sync
                : s == SyncStatus.noNetwork ? Icons.wifi_off
                : p > 0 ? Icons.cloud_upload : Icons.cloud_done,
                color: Colors.white),
              onPressed: () => setState(() => _index = 3)),
            if (p > 0) Positioned(right: 8, top: 8, child: Container(
              width: 16, height: 16,
              decoration: const BoxDecoration(color: AppTheme.warning, shape: BoxShape.circle),
              child: Center(child: Text(p > 9 ? '9+' : '$p',
                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800))))),
          ]);
        }),
      ],
    ),
    body: IndexedStack(index: _index, children: _pages),
    bottomNavigationBar: Obx(() {
      final pending = SyncManager.instance.pendingCount.value;
      final user = AuthController.to.currentUser.value;
      return NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        height: 65,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.agriculture_outlined), selectedIcon: Icon(Icons.agriculture), label: 'Parcelles'),
          const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Carte'),
          const NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Guides'),
          NavigationDestination(
            icon: Stack(children: [
              const Icon(Icons.sync_outlined),
              if (pending > 0) Positioned(right: 0, top: 0, child: Container(
                width: 12, height: 12,
                decoration: const BoxDecoration(color: AppTheme.warning, shape: BoxShape.circle),
                child: Center(child: Text('$pending', style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.w800))))),
            ]),
            selectedIcon: const Icon(Icons.sync),
            label: 'Sync',
          ),
          NavigationDestination(
            icon: CircleAvatar(radius: 13, backgroundColor: AppTheme.primary.withOpacity(0.2),
              child: Text(user?.initials ?? '?', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary))),
            selectedIcon: CircleAvatar(radius: 13, backgroundColor: AppTheme.primary,
              child: Text(user?.initials ?? '?', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
            label: 'Profil',
          ),
        ],
      );
    }),
  );
}
