class Folder {
  const Folder({
    required this.id,
    required this.name,
    required this.userId,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String userId;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}
