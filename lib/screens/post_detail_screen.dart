import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post.dart';
import 'dart:collection';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  final Map<String, String> userColors;
  final Map<String, String> userEmails;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.userColors,
    required this.userEmails,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final supabase = Supabase.instance.client;
  final _commentController = TextEditingController();
  final Map<String, List<Map<String, dynamic>>> _comments = {};
  final Map<String, String> _commentUserColors = {};
  final Map<String, String> _commentUserEmails = {};

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final response = await supabase
          .from('comments')
          .select()
          .eq('post_id', widget.post.id)
          .order('created_at', ascending: true);
      final comments = (response as List)
          .map((c) => {
                'id': c['id'],
                'content': c['content'],
                'authorId': c['author_id'],
                'createdAt': DateTime.parse(c['created_at']),
              })
          .toList();
      setState(() {
        _comments[widget.post.id.toString()] = comments;
      });
      // 댓글 작성자 id 목록 추출
      final authorIds = comments
          .map((e) => e['authorId'])
          .where((id) => id != null)
          .toSet()
          .toList();
      if (authorIds.isNotEmpty) {
        final profiles = await supabase
            .from('profiles')
            .select('id, color, email')
            .filter('id', 'in', '(${authorIds.join(',')})');
        setState(() {
          for (final profile in profiles) {
            _commentUserColors[profile['id']] = profile['color'] ?? '#90caf9';
            _commentUserEmails[profile['id']] = profile['email'] ?? '';
          }
        });
      }
    } catch (e) {
      // ignore error for now
    }
  }

  void _addComment() async {
    if (_commentController.text.isEmpty) return;
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }
    try {
      await supabase.from('comments').insert({
        'post_id': widget.post.id,
        'author_id': user.id,
        'content': _commentController.text,
      });
      _commentController.clear();
      await _loadComments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 작성에 실패했습니다: $e')),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null) return const Color(0xFF90CAF9);
    if (colorStr.startsWith('hsl')) {
      final hsl = colorStr.replaceAll(RegExp(r'[^0-9.,%]'), '').split(',');
      final h = double.tryParse(hsl[0]) ?? 210;
      final s = double.tryParse(hsl[1].replaceAll('%', '')) ?? 70;
      final l = double.tryParse(hsl[2].replaceAll('%', '')) ?? 60;
      return HSLColor.fromAHSL(1, h, s / 100, l / 100).toColor();
    }
    return Color(int.parse(colorStr.replaceFirst('#', '0xff')));
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.post.authorId == supabase.auth.currentUser?.id;
    final comments = _comments[widget.post.id.toString()] ?? [];

    return Scaffold(
      backgroundColor: Color(0xFFFFF8E1),
      appBar: AppBar(
        title: const Text('게시물'),
        backgroundColor: Color(0xFFFFF8E1),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFFF6F00)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 원본 메시지
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe) ...[
                              CircleAvatar(
                                backgroundColor: _parseColor(
                                    widget.userColors[widget.post.authorId]),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        widget.userEmails[
                                                widget.post.authorId] ??
                                            '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatDate(widget.post.createdAt),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFBDBDBD),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.post.content,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isMe
                                          ? Color(0xFFFF6F00)
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 12),
                              CircleAvatar(
                                backgroundColor: _parseColor(
                                    widget.userColors[widget.post.authorId]),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        height: 1,
                        color: Color(0xFFF5F5F5),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 16,
                              color: Color(0xFFBDBDBD),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '댓글 ${comments.length}개',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFBDBDBD),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // 댓글 목록
                if (comments.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 12),
                    child: Text(
                      '댓글',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ),
                  ...comments
                      .map((comment) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: _parseColor(
                                      _commentUserColors[comment['authorId']] ??
                                          widget
                                              .userColors[comment['authorId']]),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Color(0xFFF5F5F5),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              12, 12, 12, 4),
                                          child: Row(
                                            children: [
                                              Text(
                                                _commentUserEmails[
                                                        comment['authorId']] ??
                                                    widget.userEmails[
                                                        comment['authorId']] ??
                                                    '',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _formatDate(
                                                    comment['createdAt']),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFFBDBDBD),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              12, 0, 12, 12),
                                          child: Text(
                                            comment['content'],
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ],
              ],
            ),
          ),
          // 댓글 입력 필드
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: '댓글을 입력하세요...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          color: Color(0xFFBDBDBD),
                          fontSize: 14,
                        ),
                      ),
                      maxLines: null,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFFF6F00),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    onPressed: _addComment,
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
