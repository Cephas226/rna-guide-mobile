// ============================================================
// RNA Guide - Database Helper (SQLite local)
// Toutes les tables pour le fonctionnement 100% offline
// ============================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  Database? _database;
  static const int _version = 3;
  static const String _dbName = 'rna_guide.db';

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<void> initialize() async {
    _database = await _initDatabase();
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        local_id TEXT UNIQUE,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        role TEXT NOT NULL DEFAULT 'PRODUCTEUR',
        region TEXT,
        province TEXT,
        commune TEXT,
        village TEXT,
        avatar_url TEXT,
        access_token TEXT,
        refresh_token TEXT,
        token_expires_at INTEGER,
        is_active INTEGER DEFAULT 1,
        last_sync_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE parcels (
        id TEXT PRIMARY KEY,
        local_id TEXT UNIQUE NOT NULL,
        server_id TEXT,
        name TEXT NOT NULL,
        region TEXT NOT NULL,
        province TEXT NOT NULL,
        commune TEXT NOT NULL,
        village TEXT NOT NULL,
        superficie REAL NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        geometry TEXT,
        gps_points TEXT,
        owner_id TEXT NOT NULL,
        notes TEXT,
        sync_status TEXT NOT NULL DEFAULT 'PENDING',
        version INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY (owner_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE inventories (
        id TEXT PRIMARY KEY,
        local_id TEXT UNIQUE NOT NULL,
        server_id TEXT,
        parcel_id TEXT NOT NULL,
        agent_id TEXT NOT NULL,
        year INTEGER NOT NULL,
        season TEXT NOT NULL,
        total_pieds INTEGER DEFAULT 0,
        selected_pieds INTEGER DEFAULT 0,
        observations TEXT,
        validated_at TEXT,
        validated_by TEXT,
        sync_status TEXT NOT NULL DEFAULT 'PENDING',
        version INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (parcel_id) REFERENCES parcels (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory_species (
        id TEXT PRIMARY KEY,
        inventory_id TEXT NOT NULL,
        species_id TEXT NOT NULL,
        pieds_h1 INTEGER NOT NULL DEFAULT 0,
        pieds_h2 INTEGER NOT NULL DEFAULT 0,
        pieds_h3 INTEGER NOT NULL DEFAULT 0,
        total_pieds INTEGER NOT NULL DEFAULT 0,
        selected_pieds INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        FOREIGN KEY (inventory_id) REFERENCES inventories (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE species (
        id TEXT PRIMARY KEY,
        scientific_name TEXT NOT NULL UNIQUE,
        local_name_fr TEXT,
        local_name_moore TEXT,
        local_name_dioula TEXT,
        local_name_fulfule TEXT,
        category TEXT,
        is_native INTEGER DEFAULT 1,
        ecological_role TEXT,
        image_url TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE photos (
        id TEXT PRIMARY KEY,
        local_id TEXT UNIQUE NOT NULL,
        server_id TEXT,
        parcel_id TEXT NOT NULL,
        author_id TEXT NOT NULL,
        photo_point_id TEXT,
        local_path TEXT,
        storage_url TEXT,
        thumbnail_url TEXT,
        latitude REAL,
        longitude REAL,
        taken_at TEXT NOT NULL,
        notes TEXT,
        year INTEGER,
        size_bytes INTEGER,
        sync_status TEXT NOT NULL DEFAULT 'PENDING',
        FOREIGN KEY (parcel_id) REFERENCES parcels (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE photo_points (
        id TEXT PRIMARY KEY,
        parcel_id TEXT NOT NULL,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (parcel_id) REFERENCES parcels (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE exploitations (
        id TEXT PRIMARY KEY,
        local_id TEXT UNIQUE NOT NULL,
        server_id TEXT,
        parcel_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        product_type TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        destination TEXT NOT NULL,
        usage TEXT,
        price_xof REAL,
        buyer_info TEXT,
        exploited_at TEXT NOT NULL,
        notes TEXT,
        sync_status TEXT NOT NULL DEFAULT 'PENDING',
        created_at TEXT NOT NULL,
        FOREIGN KEY (parcel_id) REFERENCES parcels (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE rna_operations (
        id TEXT PRIMARY KEY,
        local_id TEXT UNIQUE NOT NULL,
        server_id TEXT,
        parcel_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        category TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        notes TEXT,
        sync_status TEXT NOT NULL DEFAULT 'PENDING',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (parcel_id) REFERENCES parcels (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE formations (
        id TEXT PRIMARY KEY,
        title_fr TEXT NOT NULL,
        title_moore TEXT,
        title_dioula TEXT,
        title_fulfule TEXT,
        content_fr TEXT NOT NULL,
        content_moore TEXT,
        content_dioula TEXT,
        content_fulfule TEXT,
        category TEXT NOT NULL,
        media_urls TEXT DEFAULT '[]',
        order_index INTEGER DEFAULT 0,
        is_published INTEGER DEFAULT 1,
        updated_at TEXT NOT NULL
      )
    ''');

    // ── Table critique: queue de synchronisation ──────────────
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL,
        server_id TEXT,
        entity_type TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        client_updated_at TEXT NOT NULL,
        version INTEGER DEFAULT 1,
        attempts INTEGER DEFAULT 0,
        last_attempt_at TEXT,
        error_message TEXT,
        status TEXT NOT NULL DEFAULT 'PENDING',
        created_at TEXT NOT NULL
      )
    ''');

    // ── Index pour performances ────────────────────────────────
    await db.execute('CREATE INDEX idx_parcels_sync ON parcels (sync_status)');
    await db.execute('CREATE INDEX idx_parcels_owner ON parcels (owner_id)');
    await db.execute('CREATE INDEX idx_photos_parcel ON photos (parcel_id)');
    await db.execute('CREATE INDEX idx_inventories_parcel ON inventories (parcel_id)');
    await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue (status)');
    await db.execute('CREATE INDEX idx_exploitations_parcel ON exploitations (parcel_id)');
    await db.execute('CREATE INDEX idx_rna_operations_parcel ON rna_operations (parcel_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE inventory_species ADD COLUMN pieds_h1 INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE inventory_species ADD COLUMN pieds_h2 INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE inventory_species ADD COLUMN pieds_h3 INTEGER NOT NULL DEFAULT 0');
      // SQLite < 3.35 does not support DROP COLUMN, so old columns (height_cm, health_state, is_new_species) remain but are ignored
      // total_pieds and selected_pieds already exist — no need to add
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rna_operations (
          id TEXT PRIMARY KEY,
          local_id TEXT UNIQUE NOT NULL,
          server_id TEXT,
          parcel_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          category TEXT NOT NULL,
          operation_type TEXT NOT NULL,
          month INTEGER NOT NULL,
          year INTEGER NOT NULL,
          notes TEXT,
          sync_status TEXT NOT NULL DEFAULT 'PENDING',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (parcel_id) REFERENCES parcels (id)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_rna_operations_parcel ON rna_operations (parcel_id)',
      );
    }
  }

  // ── Helpers génériques ─────────────────────────────────────

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(String table, Map<String, dynamic> data, String where, List<dynamic> args) async {
    final db = await database;
    return db.update(table, data, where: where, whereArgs: args);
  }

  Future<int> delete(String table, String where, List<dynamic> args) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: args);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit, offset: offset);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? args]) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }

  Future<void> clearAll() async {
    final db = await database;
    final tables = ['sync_queue', 'photos', 'inventory_species', 'inventories', 'exploitations', 'rna_operations', 'photo_points', 'parcels', 'formations', 'species'];
    for (final table in tables) {
      await db.delete(table);
    }
  }
}
