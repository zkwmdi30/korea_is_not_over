class Post {
  final int id;
  final String content;
  final DateTime createdAt;
  final String authorId;

  Post({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.authorId,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      authorId: json['author_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'author_id': authorId,
    };
  }
}
