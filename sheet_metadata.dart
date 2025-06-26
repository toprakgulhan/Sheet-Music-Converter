class SheetMetadata {
  final int id;
  final String filename;
  final DateTime createdAt;
  final int pageCount;

  SheetMetadata({
    required this.id,
    required this.filename,
    required this.createdAt,
    required this.pageCount,
  });

  factory SheetMetadata.fromJson(Map<String, dynamic> m) {
    return SheetMetadata(
      id: m['id'] as int,
      filename: m['filename'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      pageCount: m['page_count'] as int,
    );
  }
}
