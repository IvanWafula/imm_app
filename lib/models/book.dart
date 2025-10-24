class Book {
  final int id;
  final String title;
  final String author;
  final String description;
  final String fileUrl;
  final String? coverImage;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.fileUrl,
    this.coverImage,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'],
      title: json['title'],
      author: json['author'] ?? 'Unknown Author',
      description: json['description'] ?? '',
      fileUrl: json['file_path'] ?? '',
      coverImage: json['cover_image'],
    );
  }
}
