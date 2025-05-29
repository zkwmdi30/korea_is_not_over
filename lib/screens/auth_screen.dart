import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _isLogin = ValueNotifier<bool>(true);
  final supabase = Supabase.instance.client;
  bool _isEmailFocused = false;
  bool _isPasswordFocused = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (_formKey.currentState!.validate()) {
      try {
        if (_isLogin.value) {
          // 로그인
          await supabase.auth.signInWithPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );
        } else {
          // 회원가입
          final response = await supabase.auth.signUp(
            email: _emailController.text,
            password: _passwordController.text,
            emailRedirectTo: null,
          );
          if (response.user != null) {
            // 회원가입 성공 시 프로필에 색상 저장
            final userId = response.user!.id;
            final color = _generateColorFromId(userId);
            await supabase.from('profiles').upsert({
              'id': userId,
              'email': _emailController.text,
              'color': color,
            });
            // 바로 로그인
            await supabase.auth.signInWithPassword(
              email: _emailController.text,
              password: _passwordController.text,
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isLogin.value ? '로그인 실패: $e' : '회원가입 실패: $e'),
            ),
          );
        }
      }
    }
  }

  String _generateColorFromId(String id) {
    // 간단한 해시 기반 색상 생성 (HSL)
    final hash = id.codeUnits.fold(0, (prev, elem) => prev + elem);
    final hue = hash % 360;
    return 'hsl($hue, 70%, 60%)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF8E1), // 연노랑
              Color(0xFFFFA000), // 노란 주황
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                // 로고/앱명
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.forum,
                    color: Color(0xFFD32F2F), // 진한 빨강
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Korea Is Over',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD32F2F),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 32),
                // 카드 형태 입력 영역
                Container(
                  width: 340,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Focus(
                          onFocusChange: (hasFocus) {
                            setState(() {
                              _isEmailFocused = hasFocus;
                            });
                          },
                          child: TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: '이메일',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD32F2F), width: 2),
                              ),
                              filled: true,
                              fillColor: _isEmailFocused
                                  ? Color(0xFFFFF8E1)
                                  : Colors.grey[50],
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '이메일을 입력해주세요';
                              }
                              if (!value.contains('@')) {
                                return '올바른 이메일 형식이 아닙니다';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Focus(
                          onFocusChange: (hasFocus) {
                            setState(() {
                              _isPasswordFocused = hasFocus;
                            });
                          },
                          child: TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: '비밀번호',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD32F2F), width: 2),
                              ),
                              filled: true,
                              fillColor: _isPasswordFocused
                                  ? Color(0xFFFFF8E1)
                                  : Colors.grey[50],
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '비밀번호를 입력해주세요';
                              }
                              if (value.length < 6) {
                                return '비밀번호는 6자 이상이어야 합니다';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _handleAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD32F2F),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _isLogin,
                              builder: (context, isLogin, _) {
                                return Text(
                                  isLogin ? '로그인' : '회원가입',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<bool>(
                          valueListenable: _isLogin,
                          builder: (context, isLogin, _) {
                            return TextButton(
                              onPressed: () {
                                _isLogin.value = !_isLogin.value;
                              },
                              child: Text(
                                isLogin
                                    ? '계정이 없으신가요? 회원가입'
                                    : '이미 계정이 있으신가요? 로그인',
                                style: const TextStyle(
                                  color: Color(0xFFD32F2F),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
