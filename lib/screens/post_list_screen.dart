import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post.dart';
import 'dart:collection';
import 'dart:ui';
import 'post_detail_screen.dart';
import 'package:visibility_detector/visibility_detector.dart';

class PostListScreen extends StatefulWidget {
  const PostListScreen({super.key});

  @override
  State<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen> {
  final supabase = Supabase.instance.client;
  List<Post> posts = [];
  final ScrollController _scrollController = ScrollController();
  final Map<String, String> _userColors = HashMap();
  final Map<String, String> _userEmails = HashMap();
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isFocused = false;
  final Map<String, int> _commentCounts = {};
  final Set<int> _visiblePostIds = {};

  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> fetchPosts() async {
    try {
      final response = await supabase
          .from('posts')
          .select()
          .order('created_at', ascending: true);

      final postList =
          (response as List).map((post) => Post.fromJson(post)).toList();
      setState(() {
        posts = postList;
      });
      // authorId 목록 추출
      final authorIds = postList.map((e) => e.authorId).toSet().toList();
      // 프로필 색상, 이메일 불러오기
      final profiles = await supabase
          .from('profiles')
          .select('id, color, email')
          .filter('id', 'in', '(${authorIds.join(',')})');
      setState(() {
        for (final profile in profiles) {
          _userColors[profile['id']] = profile['color'] ?? '#90caf9';
          _userEmails[profile['id']] = profile['email'] ?? '';
        }
      });
      await fetchCommentCounts(postList.map((e) => e.id).toList());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('게시물을 불러오는데 실패했습니다: $e')),
      );
    }
  }

  Future<void> fetchCommentCounts(List<int> postIds) async {
    if (postIds.isEmpty) return;
    try {
      final response = await supabase
          .from('comments')
          .select('post_id, id')
          .inFilter('post_id', postIds);
      final List data = response ?? [];
      final Map<String, int> counts = {};
      for (final postId in postIds) {
        counts[postId.toString()] = 0;
      }
      for (final row in data) {
        final postId = row['post_id'].toString();
        counts[postId] = (counts[postId] ?? 0) + 1;
      }
      setState(() {
        _commentCounts.clear();
        _commentCounts.addAll(counts);
      });
    } catch (e) {
      // ignore error for now
    }
  }

  Future<void> _submitPost() async {
    if (_formKey.currentState!.validate()) {
      try {
        final user = supabase.auth.currentUser;
        if (user == null) {
          throw Exception('로그인이 필요합니다');
        }
        await supabase.from('posts').insert({
          'content': _contentController.text,
          'author_id': user.id,
        });
        _contentController.clear();
        await fetchPosts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('메시지 전송에 실패했습니다: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF8E1), // 미니멀 연노랑
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_fire_department, color: Color(0xFFFF6F00)),
            SizedBox(width: 8),
            const Text('게시판'),
          ],
        ),
        backgroundColor: Color(0xFFFFF8E1), // 미니멀 연노랑
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFFF6F00)),
            onPressed: () async {
              await supabase.auth.signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Color(0xFFFFFDF8), // 거의 화이트에 가까운 미니멀 배경
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final isMe = post.authorId == supabase.auth.currentUser?.id;

                  return VisibilityDetector(
                    key: Key('post_${post.id}'),
                    onVisibilityChanged: (info) {
                      if (info.visibleFraction > 0) {
                        _visiblePostIds.add(post.id);
                      } else {
                        _visiblePostIds.remove(post.id);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostDetailScreen(
                                post: post,
                                userColors: _userColors,
                                userEmails: _userEmails,
                              ),
                            ),
                          );
                          // 뒤로가기 시, 현재 보이는 게시물만 댓글 수 갱신
                          if (result == 'refresh_comments') {
                            final ids = _visiblePostIds.toList();
                            await fetchCommentCounts(ids);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe) ...[
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        _parseColor(_userColors[post.authorId]),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      _userEmails[post.authorId] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: true,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFFBDBDBD), // 미니멀 그레이
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: isMe
                                        ? Color(0xFFFF6F00)
                                        : Color(0xFFF5F5F5),
                                    width: 1.2,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            post.content,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: isMe
                                                  ? Color(0xFFFF6F00)
                                                  : Colors.black87,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatDate(post.createdAt),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFFBDBDBD),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      height: 1,
                                      color: Color(0xFFF5F5F5),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          14, 8, 0, 12),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.chat_bubble_outline,
                                            size: 16,
                                            color: Color(0xFFBDBDBD),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '댓글 \\${_commentCounts[post.id.toString()] ?? 0}개',
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
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        _parseColor(_userColors[post.authorId]),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      _userEmails[post.authorId] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: true,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFFBDBDBD),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
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
            child: Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: Focus(
                      onFocusChange: (hasFocus) {
                        setState(() {
                          _isFocused = hasFocus;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _isFocused
                                ? Color(0xFFFF6F00)
                                : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextFormField(
                          controller: _contentController,
                          decoration: InputDecoration(
                            hintText: '메시지를 입력하세요...🔥',
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              color: Color(0xFFBDBDBD),
                              fontSize: 16,
                            ),
                          ),
                          maxLines: null,
                          style: const TextStyle(fontSize: 16),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '내용을 입력해주세요';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFFF6F00),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFF6F00).withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _submitPost,
                      icon: const Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
}
