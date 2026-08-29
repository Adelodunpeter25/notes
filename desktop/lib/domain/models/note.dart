class Note {
  Note({
    required this.id,
    required this.title,
    required this.document,
    required this.userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isPinned = false,
    this.folderId,
    this.deletedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String document;
  final String userId;
  DateTime createdAt;
  DateTime updatedAt;
  bool isPinned;
  String? folderId;
  DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Note copyWith({
    String? title,
    String? document,
    DateTime? updatedAt,
    bool? isPinned,
    String? folderId,
    bool clearFolder = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      document: document ?? this.document,
      userId: userId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      folderId: clearFolder ? null : folderId ?? this.folderId,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    );
  }
}
