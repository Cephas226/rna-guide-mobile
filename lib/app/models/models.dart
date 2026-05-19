// ============================================================
// RNA Guide - Modèles de données Flutter
// ============================================================

import 'dart:convert';

// ── User ──────────────────────────────────────────────────────

class UserModel {
  final String id;
  final String? localId;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String role;
  final String? region;
  final String? province;
  final String? commune;
  final String? village;
  final String? avatarUrl;
  final String? deviceId;
  final bool isActive;
  final DateTime? lastSyncAt;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    this.localId,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    required this.role,
    this.region,
    this.province,
    this.commune,
    this.village,
    this.avatarUrl,
    this.deviceId,
    this.isActive = true,
    this.lastSyncAt,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName[0]}${lastName[0]}'.toUpperCase();
  bool get isAdmin => role == 'ADMIN';
  bool get isSuperviseur => role == 'SUPERVISEUR' || role == 'ADMIN';
  bool get isAgent => role == 'AGENT_TERRAIN' || isSuperviseur;

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    id: map['id'] as String,
    localId: map['local_id'] as String?,
    firstName: map['first_name'] ?? map['firstName'] ?? '',
    lastName: map['last_name'] ?? map['lastName'] ?? '',
    email: map['email'] as String?,
    phone: map['phone'] as String?,
    role: map['role'] ?? 'PRODUCTEUR',
    region: map['region'] as String?,
    province: map['province'] as String?,
    commune: map['commune'] as String?,
    village: map['village'] as String?,
    avatarUrl: map['avatar_url'] ?? map['avatarUrl'],
    deviceId: map['device_id'] ?? map['deviceId'],
    isActive: (map['is_active'] ?? map['isActive'] ?? 1) == 1,
    lastSyncAt: map['last_sync_at'] != null || map['lastSyncAt'] != null
        ? DateTime.tryParse(map['last_sync_at'] ?? map['lastSyncAt'] ?? '')
        : null,
    createdAt: DateTime.tryParse(map['created_at'] ?? map['createdAt'] ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'local_id': localId,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'phone': phone,
    'role': role,
    'region': region,
    'province': province,
    'commune': commune,
    'village': village,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  };
}

// ── Parcel ────────────────────────────────────────────────────

class ParcelModel {
  final String id;
  final String localId;
  String? serverId;
  String name;
  String region;
  String province;
  String commune;
  String village;
  double superficie;
  double latitude;
  double longitude;
  Map<String, dynamic>? geometry;
  List<Map<String, dynamic>>? gpsPoints;
  String ownerId;
  String? notes;
  String syncStatus;
  int version;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;

  // Relations chargées optionnellement
  UserModel? owner;
  int inventoriesCount;
  int photosCount;
  int exploitationsCount;

  ParcelModel({
    required this.id,
    required this.localId,
    this.serverId,
    required this.name,
    required this.region,
    required this.province,
    required this.commune,
    required this.village,
    required this.superficie,
    required this.latitude,
    required this.longitude,
    this.geometry,
    this.gpsPoints,
    required this.ownerId,
    this.notes,
    this.syncStatus = 'PENDING',
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.owner,
    this.inventoriesCount = 0,
    this.photosCount = 0,
    this.exploitationsCount = 0,
  });

  bool get isSynced => syncStatus == 'SYNCED';
  bool get isPending => syncStatus == 'PENDING';
  bool get hasConflict => syncStatus == 'CONFLICT';
  bool get isDeleted => deletedAt != null || syncStatus == 'DELETED';

  factory ParcelModel.fromMap(Map<String, dynamic> map) => ParcelModel(
    id: map['id'] as String,
    localId: map['local_id'] ?? map['localId'] ?? map['id'],
    serverId: map['server_id'] ?? map['id'],
    name: map['name'] ?? '',
    region: map['region'] ?? '',
    province: map['province'] ?? '',
    commune: map['commune'] ?? '',
    village: map['village'] ?? '',
    superficie: (map['superficie'] as num?)?.toDouble() ?? 0,
    latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
    geometry: map['geometry'] != null
        ? (map['geometry'] is String ? jsonDecode(map['geometry']) : map['geometry'])
        : null,
    gpsPoints: map['gps_points'] != null
        ? List<Map<String, dynamic>>.from(
            (map['gps_points'] is String ? jsonDecode(map['gps_points']) : map['gps_points']))
        : null,
    ownerId: map['owner_id'] ?? map['ownerId'] ?? '',
    notes: map['notes'] as String?,
    syncStatus: map['sync_status'] ?? map['syncStatus'] ?? 'SYNCED',
    version: (map['version'] as int?) ?? 1,
    createdAt: DateTime.tryParse(map['created_at'] ?? map['createdAt'] ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(map['updated_at'] ?? map['updatedAt'] ?? '') ?? DateTime.now(),
    deletedAt: map['deleted_at'] != null ? DateTime.tryParse(map['deleted_at']) : null,
    inventoriesCount: map['inventories_count'] ?? 0,
    photosCount: map['photos_count'] ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'local_id': localId,
    'server_id': serverId,
    'name': name,
    'region': region,
    'province': province,
    'commune': commune,
    'village': village,
    'superficie': superficie,
    'latitude': latitude,
    'longitude': longitude,
    'geometry': geometry != null ? jsonEncode(geometry) : null,
    'gps_points': gpsPoints != null ? jsonEncode(gpsPoints) : null,
    'owner_id': ownerId,
    'notes': notes,
    'sync_status': syncStatus,
    'version': version,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  Map<String, dynamic> toSyncPayload() => {
    'localId': localId,
    'name': name,
    'region': region,
    'province': province,
    'commune': commune,
    'village': village,
    'superficie': superficie,
    'latitude': latitude,
    'longitude': longitude,
    'geometry': geometry,
    'gpsPoints': gpsPoints,
    'notes': notes,
  };
}

// ── Species ───────────────────────────────────────────────────

class SpeciesModel {
  final String id;
  final String scientificName;
  final String? localNameFr;
  final String? localNameMoore;
  final String? localNameDioula;
  final String? localNameFulfule;
  final String category;
  final bool isNative;
  final String? ecologicalRole;
  final String? imageUrl;

  const SpeciesModel({
    required this.id,
    required this.scientificName,
    this.localNameFr,
    this.localNameMoore,
    this.localNameDioula,
    this.localNameFulfule,
    required this.category,
    this.isNative = true,
    this.ecologicalRole,
    this.imageUrl,
  });

  String displayName(String lang) => switch (lang) {
    'moore'   => localNameMoore ?? localNameFr ?? scientificName,
    'dioula'  => localNameDioula ?? localNameFr ?? scientificName,
    'fulfule' => localNameFulfule ?? localNameFr ?? scientificName,
    _          => localNameFr ?? scientificName,
  };

  factory SpeciesModel.fromMap(Map<String, dynamic> map) => SpeciesModel(
    id: map['id'],
    scientificName: map['scientific_name'] ?? map['scientificName'] ?? '',
    localNameFr: map['local_name_fr'] ?? map['localNameFr'],
    localNameMoore: map['local_name_moore'] ?? map['localNameMoore'],
    localNameDioula: map['local_name_dioula'] ?? map['localNameDioula'],
    localNameFulfule: map['local_name_fulfule'] ?? map['localNameFulfule'],
    category: map['category'] ?? 'arbre',
    isNative: (map['is_native'] ?? map['isNative'] ?? 1) == 1,
    ecologicalRole: map['ecological_role'] ?? map['ecologicalRole'],
    imageUrl: map['image_url'] ?? map['imageUrl'],
  );
}

// ── Inventory ─────────────────────────────────────────────────

class InventoryModel {
  final String id;
  final String localId;
  String? serverId;
  final String parcelId;
  final String agentId;
  final int year;
  final String season;
  int totalPieds;
  int selectedPieds;
  String? observations;
  DateTime? validatedAt;
  String syncStatus;
  int version;
  List<InventorySpeciesModel> species;
  final DateTime createdAt;
  DateTime updatedAt;

  InventoryModel({
    required this.id,
    required this.localId,
    this.serverId,
    required this.parcelId,
    required this.agentId,
    required this.year,
    required this.season,
    this.totalPieds = 0,
    this.selectedPieds = 0,
    this.observations,
    this.validatedAt,
    this.syncStatus = 'PENDING',
    this.version = 1,
    this.species = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isValidated => validatedAt != null;

  factory InventoryModel.fromMap(Map<String, dynamic> map) => InventoryModel(
    id: map['id'],
    localId: map['local_id'] ?? map['localId'] ?? map['id'],
    serverId: map['server_id'],
    parcelId: map['parcel_id'] ?? map['parcelId'] ?? '',
    agentId: map['agent_id'] ?? map['agentId'] ?? '',
    year: (map['year'] as int?) ?? DateTime.now().year,
    season: map['season'] ?? 'HIVERNAGE',
    totalPieds: (map['total_pieds'] ?? map['totalPieds'] ?? 0) as int,
    selectedPieds: (map['selected_pieds'] ?? map['selectedPieds'] ?? 0) as int,
    observations: map['observations'] as String?,
    validatedAt: map['validated_at'] != null ? DateTime.tryParse(map['validated_at']) : null,
    syncStatus: map['sync_status'] ?? 'SYNCED',
    version: (map['version'] as int?) ?? 1,
    createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toSyncPayload() => {
    'localId': localId,
    'parcelId': parcelId,
    'agentId': agentId,
    'year': year,
    'season': season,
    'totalPieds': totalPieds,
    'selectedPieds': selectedPieds,
    'observations': observations,
    'species': species.map((s) => s.toMap()).toList(),
  };
}

class InventorySpeciesModel {
  final String id;
  final String inventoryId;
  final String speciesId;
  int totalPieds;
  int selectedPieds;
  String healthState;
  double? heightCm;
  String? notes;
  bool isNewSpecies;
  SpeciesModel? species;

  InventorySpeciesModel({
    required this.id,
    required this.inventoryId,
    required this.speciesId,
    required this.totalPieds,
    required this.selectedPieds,
    this.healthState = 'BON',
    this.heightCm,
    this.notes,
    this.isNewSpecies = false,
    this.species,
  });

  factory InventorySpeciesModel.fromMap(Map<String, dynamic> map) => InventorySpeciesModel(
    id: map['id'],
    inventoryId: map['inventory_id'] ?? map['inventoryId'] ?? '',
    speciesId: map['species_id'] ?? map['speciesId'] ?? '',
    totalPieds: (map['total_pieds'] ?? map['totalPieds'] ?? 0) as int,
    selectedPieds: (map['selected_pieds'] ?? map['selectedPieds'] ?? 0) as int,
    healthState: map['health_state'] ?? map['healthState'] ?? 'BON',
    heightCm: (map['height_cm'] ?? map['heightCm'] as num?)?.toDouble(),
    isNewSpecies: (map['is_new_species'] ?? map['isNewSpecies'] ?? 0) == 1,
  );

  Map<String, dynamic> toMap() => {
    'speciesId': speciesId,
    'totalPieds': totalPieds,
    'selectedPieds': selectedPieds,
    'healthState': healthState,
    'heightCm': heightCm,
    'isNewSpecies': isNewSpecies ? 1 : 0,
  };
}

// ── Exploitation ──────────────────────────────────────────────

class ExploitationModel {
  final String id;
  final String localId;
  String? serverId;
  final String parcelId;
  final String userId;
  final String productType;
  double quantity;
  String unit;
  String destination;
  String? usage;
  double? priceXOF;
  final DateTime exploitedAt;
  String? notes;
  String syncStatus;

  ExploitationModel({
    required this.id,
    required this.localId,
    this.serverId,
    required this.parcelId,
    required this.userId,
    required this.productType,
    required this.quantity,
    required this.unit,
    required this.destination,
    this.usage,
    this.priceXOF,
    required this.exploitedAt,
    this.notes,
    this.syncStatus = 'PENDING',
  });

  factory ExploitationModel.fromMap(Map<String, dynamic> map) => ExploitationModel(
    id: map['id'],
    localId: map['local_id'] ?? map['localId'] ?? map['id'],
    serverId: map['server_id'],
    parcelId: map['parcel_id'] ?? map['parcelId'] ?? '',
    userId: map['user_id'] ?? map['userId'] ?? '',
    productType: map['product_type'] ?? map['productType'] ?? '',
    quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
    unit: map['unit'] ?? 'kg',
    destination: map['destination'] ?? 'autoconsommation',
    usage: map['usage'] as String?,
    priceXOF: (map['price_xof'] ?? map['priceXOF'] as num?)?.toDouble(),
    exploitedAt: DateTime.tryParse(map['exploited_at'] ?? map['exploitedAt'] ?? '') ?? DateTime.now(),
    notes: map['notes'] as String?,
    syncStatus: map['sync_status'] ?? 'SYNCED',
  );
}

// ── Formation ─────────────────────────────────────────────────

class FormationModel {
  final String id;
  final String titleFr;
  final String? titleMoore;
  final String? titleDioula;
  final String contentFr;
  final String? contentMoore;
  final String? contentDioula;
  final String category;
  final List<dynamic> mediaUrls;
  final int orderIndex;
  final DateTime updatedAt;

  const FormationModel({
    required this.id,
    required this.titleFr,
    this.titleMoore,
    this.titleDioula,
    required this.contentFr,
    this.contentMoore,
    this.contentDioula,
    required this.category,
    this.mediaUrls = const [],
    this.orderIndex = 0,
    required this.updatedAt,
  });

  String title(String lang) => switch (lang) {
    'moore'  => titleMoore ?? titleFr,
    'dioula' => titleDioula ?? titleFr,
    _         => titleFr,
  };

  String content(String lang) => switch (lang) {
    'moore'  => contentMoore ?? contentFr,
    'dioula' => contentDioula ?? contentFr,
    _         => contentFr,
  };

  factory FormationModel.fromMap(Map<String, dynamic> map) => FormationModel(
    id: map['id'],
    titleFr: map['title_fr'] ?? map['titleFr'] ?? '',
    titleMoore: map['title_moore'] ?? map['titleMoore'],
    titleDioula: map['title_dioula'] ?? map['titleDioula'],
    contentFr: map['content_fr'] ?? map['contentFr'] ?? '',
    contentMoore: map['content_moore'] ?? map['contentMoore'],
    contentDioula: map['content_dioula'] ?? map['contentDioula'],
    category: map['category'] ?? '',
    mediaUrls: map['media_urls'] is String
        ? (jsonDecode(map['media_urls']) as List)
        : (map['media_urls'] ?? []),
    orderIndex: (map['order_index'] ?? map['orderIndex'] ?? 0) as int,
    updatedAt: DateTime.tryParse(map['updated_at'] ?? map['updatedAt'] ?? '') ?? DateTime.now(),
  );
}
