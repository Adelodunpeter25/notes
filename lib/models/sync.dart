enum SyncOpType { upsert, delete }
enum SyncEntityType { note, folder }

class SyncOperation {
  final String id;
  final SyncOpType type;
  final SyncEntityType entityType;
  final String entityId;
  final DateTime updatedAt;
  final Map<String, dynamic>? payload;

  SyncOperation({
    required this.id,
    required this.type,
    required this.entityType,
    required this.entityId,
    required this.updatedAt,
    this.payload,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'entityType': entityType.name,
      'entityId': entityId,
      'updatedAt': updatedAt.toIso8601String(),
      'payload': payload,
    };
  }
}

class SyncRequest {
  final String? cursor;
  final List<SyncOperation> ops;

  SyncRequest({this.cursor, required this.ops});

  Map<String, dynamic> toJson() {
    return {
      'cursor': cursor,
      'ops': ops.map((e) => e.toJson()).toList(),
    };
  }
}

class SyncTombstone {
  final SyncEntityType entityType;
  final String entityId;
  final DateTime deletedAt;

  SyncTombstone({
    required this.entityType,
    required this.entityId,
    required this.deletedAt,
  });

  factory SyncTombstone.fromJson(Map<String, dynamic> json) {
    return SyncTombstone(
      entityType: SyncEntityType.values.byName(json['entityType']),
      entityId: json['entityId'],
      deletedAt: DateTime.parse(json['deletedAt']),
    );
  }
}

class SyncResponse {
  final String nextCursor;
  final List<dynamic> notes;
  final List<dynamic> folders;
  final List<SyncTombstone> deleted;
  final List<String> processedOpIds;

  SyncResponse({
    required this.nextCursor,
    required this.notes,
    required this.folders,
    required this.deleted,
    required this.processedOpIds,
  });

  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    return SyncResponse(
      nextCursor: json['nextCursor'],
      notes: json['notes'] ?? [],
      folders: json['folders'] ?? [],
      deleted: (json['deleted'] as List?)
              ?.map((e) => SyncTombstone.fromJson(e))
              .toList() ??
          [],
      processedOpIds: List<String>.from(json['processedOpIds'] ?? []),
    );
  }
}
