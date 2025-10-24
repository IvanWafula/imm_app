class Document {
  final int id;
  final String title;
  final String fileUrl; // always PDF
  final String fileType;

  Document({
    required this.id,
    required this.title,
    required this.fileUrl,
    required this.fileType,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'],
      title: json['title'] ?? 'Untitled',
      fileUrl: json['file_path'] ?? '',
      fileType: json['file_type'] ?? 'pdf',
    );
  }
}
