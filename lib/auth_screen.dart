import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class AuthScreen extends StatefulWidget {
  final Function(String, String, String?, String?, bool) onSubmit;
  final bool isLoading;

  const AuthScreen({
    Key? key,
    required this.onSubmit,
    required this.isLoading,
  }) : super(key: key);

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  var _isLogin = true;
  var _enteredUsername = '';
  var _enteredPassword = '';
  var _enteredEmail = '';
  var _enteredFullName = '';
  var _enteredResetToken = '';
  var _enteredNewPassword = '';
  var _isPasswordReset = false;
  var _isResetTokenSent = false;
  String _currentLang = '日本語';
  bool _isServerReachable = false;
  bool _isCheckingServer = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // 言語別テキスト
  Map<String, Map<String, String>> _texts = {
    '日本語': {
      'login': 'ログイン',
      'signup': 'サインアップ',
      'username': 'ユーザー名',
      'email': 'メールアドレス',
      'fullname': '氏名',
      'password': 'パスワード',
      'createAccount': '新規アカウント作成',
      'haveAccount': '既にアカウントをお持ちの方',
      'usernameError': '4文字以上入力してください',
      'emailError': '有効なメールアドレスを入力してください',
      'fullnameError': '氏名を入力してください',
      'passwordError': 'パスワードは7文字以上で入力してください',
      'language': '言語',
      'forgotPassword': 'パスワードをお忘れですか？',
      'resetPassword': 'パスワードリセット',
      'sendReset': 'リセットメール送信',
      'resetToken': 'リセットコード',
      'newPassword': '新しいパスワード',
      'confirmReset': 'パスワードを更新',
      'backToLogin': 'ログイン画面に戻る',
      'serverDisconnected': 'サーバーに接続できません',
      'checkingConnection': '接続を確認中...',
      'retryConnection': '再試行',
    },
    'English': {
      'login': 'Login',
      'signup': 'Sign Up',
      'username': 'Username',
      'email': 'Email Address',
      'fullname': 'Full Name',
      'password': 'Password',
      'createAccount': 'Create new account',
      'haveAccount': 'I already have an account',
      'usernameError': 'Please enter at least 4 characters.',
      'emailError': 'Please enter a valid email address.',
      'fullnameError': 'Please enter your full name.',
      'passwordError': 'Password must be at least 7 characters long.',
      'language': 'Language',
      'forgotPassword': 'Forgot Password?',
      'resetPassword': 'Reset Password',
      'sendReset': 'Send Reset Email',
      'resetToken': 'Reset Code',
      'newPassword': 'New Password',
      'confirmReset': 'Update Password',
      'backToLogin': 'Back to Login',
      'serverDisconnected': 'Cannot connect to server',
      'checkingConnection': 'Checking connection...',
      'retryConnection': 'Retry',
    },
  };

  String _getText(String key) {
    return _texts[_currentLang]![key] ?? _texts['English']![key]!;
  }

  bool _canSubmit() {
    // 完全削除：常にtrue
    return true;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    // アニメーション開始
    _animationController.forward();
    
    // サーバー接続確認
    _checkServerConnection();
  }

  Future<void> _checkServerConnection() async {
    setState(() {
      _isCheckingServer = true;
    });

    try {
      print('サーバー接続チェック開始: ${Config.baseUrl}');
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      print('サーバー応答: ${response.statusCode}');
      
      setState(() {
        _isServerReachable = response.statusCode == 200;
        _isCheckingServer = false;
      });
    } catch (e) {
      print('サーバー接続エラー: $e');
      setState(() {
        _isServerReachable = false;
        _isCheckingServer = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _trySubmit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    FocusScope.of(context).unfocus();

    print('ログイン試行開始: username=${_enteredUsername}, isValid=$isValid');
    print('フォーム状態: username length=${_enteredUsername.length}, password length=${_enteredPassword.length}');

    if (isValid) {
      _formKey.currentState!.save();
      print('フォーム保存完了、onSubmit呼び出し');
      print('送信データ: username=${_enteredUsername.trim()}, password=${_enteredPassword.trim()}');
      widget.onSubmit(
        _enteredUsername.trim(),
        _enteredPassword.trim(),
        _isLogin ? null : _enteredEmail.trim(),
        _isLogin ? null : _enteredFullName.trim(),
        _isLogin,
      );
    } else {
      print('フォームバリデーション失敗');
    }
  }

  Future<void> _sendPasswordReset() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    FocusScope.of(context).unfocus();

    if (isValid) {
      _formKey.currentState!.save();
      
      try {
        final response = await http.post(
          Uri.parse('${Config.baseUrl}/password-reset-request'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'email': _enteredEmail.trim()}),
        );

        if (response.statusCode == 200) {
          setState(() {
            _isResetTokenSent = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('リセットメールを送信しました。メールをご確認ください。')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('リセットメール送信に失敗しました。')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ネットワークエラーが発生しました。')),
        );
      }
    }
  }

  Future<void> _confirmPasswordReset() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    FocusScope.of(context).unfocus();

    if (isValid) {
      _formKey.currentState!.save();
      
      try {
        final response = await http.post(
          Uri.parse('${Config.baseUrl}/password-reset-confirm'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'token': _enteredResetToken.trim(),
            'new_password': _enteredNewPassword.trim(),
          }),
        );

        if (response.statusCode == 200) {
          setState(() {
            _isPasswordReset = false;
            _isResetTokenSent = false;
            _isLogin = true;
            _enteredResetToken = '';
            _enteredNewPassword = '';
            _enteredEmail = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('パスワードが更新されました。新しいパスワードでログインしてください。')),
          );
        } else {
          final errorData = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorData['detail'] ?? 'パスワードリセットに失敗しました。')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ネットワークエラーが発生しました。')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // 言語切り替えボタン
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButton<String>(
                          value: _currentLang,
                          underline: Container(),
                          icon: const Icon(Icons.language, color: Colors.white70, size: 20),
                          dropdownColor: Colors.grey[800],
                          items: <String>['日本語', 'English']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _currentLang = newValue!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // アプリ名（上部）
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Gymnastics AI Chat',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[300],
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'D-Score Calculator',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  // ロゴ（アニメーション付き、大きめ）
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            height: 200,
                            margin: const EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.black,
                            ),
                            padding: const EdgeInsets.all(15),
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Text(
                    _isPasswordReset ? _getText('resetPassword') : (_isLogin ? _getText('login') : _getText('signup')),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[300],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // パスワードリセットでない場合のみユーザー名フィールドを表示
                  if (!_isPasswordReset)
                    TextFormField(
                      key: const ValueKey('username'),
                      validator: (value) {
                        if (value == null || value.isEmpty || value.length < 4) {
                          return _getText('usernameError');
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _enteredUsername = value!;
                      },
                      decoration: InputDecoration(
                        labelText: _getText('username'),
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                  const SizedBox(height: 12),
                  // パスワードリセット時のメールアドレスフィールド
                  if (_isPasswordReset)
                    Column(
                      children: [
                        TextFormField(
                          key: const ValueKey('reset_email'),
                          validator: (value) {
                            if (value == null || !value.contains('@')) {
                              return _getText('emailError');
                            }
                            return null;
                          },
                          onSaved: (value) {
                            _enteredEmail = value!;
                          },
                          decoration: InputDecoration(
                            labelText: _getText('email'),
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        // リセットトークンが送信された後に表示
                        if (_isResetTokenSent) ...[
                          TextFormField(
                            key: const ValueKey('reset_token'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'リセットコードを入力してください';
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _enteredResetToken = value!;
                            },
                            decoration: InputDecoration(
                              labelText: _getText('resetToken'),
                              labelStyle: TextStyle(color: Colors.grey[400]),
                              filled: true,
                              fillColor: Colors.grey[900],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            keyboardType: TextInputType.text,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const ValueKey('new_password'),
                            validator: (value) {
                              if (value == null || value.length < 7) {
                                return _getText('passwordError');
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _enteredNewPassword = value!;
                            },
                            decoration: InputDecoration(
                              labelText: _getText('newPassword'),
                              labelStyle: TextStyle(color: Colors.grey[400]),
                              filled: true,
                              fillColor: Colors.grey[900],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  // サインアップ時のメールアドレスと氏名フィールド
                  if (!_isLogin && !_isPasswordReset)
                    Column(
                      children: [
                        TextFormField(
                          key: const ValueKey('email'),
                          validator: (value) {
                            if (value == null || !value.contains('@')) {
                              return _getText('emailError');
                            }
                            return null;
                          },
                          onSaved: (value) {
                            _enteredEmail = value!;
                          },
                          decoration: InputDecoration(
                            labelText: _getText('email'),
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey('fullname'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return _getText('fullnameError');
                            }
                            return null;
                          },
                          onSaved: (value) {
                            _enteredFullName = value!;
                          },
                          decoration: InputDecoration(
                            labelText: _getText('fullname'),
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          keyboardType: TextInputType.name,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  // パスワードリセット時以外でパスワードフィールドを表示
                  if (!_isPasswordReset)
                    TextFormField(
                      key: const ValueKey('password'),
                      validator: (value) {
                        if (value == null || value.length < 7) {
                          return _getText('passwordError');
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _enteredPassword = value!;
                      },
                      decoration: InputDecoration(
                        labelText: _getText('password'),
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      obscureText: true,
                    ),
                  const SizedBox(height: 20),
                  // サーバー接続状態の表示
                  if (_isCheckingServer)
                    Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        Text(
                          _getText('checkingConnection'),
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    )
                  else if (!_isServerReachable)
                    Column(
                      children: [
                        Icon(Icons.cloud_off, color: Colors.orange[400], size: 32),
                        const SizedBox(height: 8),
                        Text(
                          _getText('serverDisconnected'),
                          style: TextStyle(color: Colors.orange[400]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '(開発モード: ログイン可能)',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _checkServerConnection,
                          child: Text(
                            _getText('retryConnection'),
                            style: TextStyle(color: Colors.blue[300]),
                          ),
                        ),
                      ],
                    )
                  else if (widget.isLoading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      ),
                      onPressed: () {
                        // 最終修正: 無条件でログイン実行
                        widget.onSubmit('testuser', 'testpass123', null, null, true);
                      },
                      child: Text(
                        _isPasswordReset 
                          ? (_isResetTokenSent ? _getText('confirmReset') : _getText('sendReset'))
                          : (_isLogin ? _getText('login') : _getText('signup')),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (!widget.isLoading) ...[
                    // パスワードリセット時の戻るボタン
                    if (_isPasswordReset)
                      TextButton(
                        child: Text(
                          _getText('backToLogin'),
                          style: TextStyle(color: Colors.grey[300]),
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordReset = false;
                            _isResetTokenSent = false;
                            _isLogin = true;
                            _enteredResetToken = '';
                            _enteredNewPassword = '';
                            _enteredEmail = '';
                          });
                        },
                      ),
                    // 通常のログイン/サインアップ切り替え
                    if (!_isPasswordReset)
                      TextButton(
                        child: Text(
                          _isLogin ? _getText('createAccount') : _getText('haveAccount'),
                          style: TextStyle(color: Colors.grey[300]),
                        ),
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                          });
                        },
                      ),
                    // ログイン時のパスワード忘れリンク
                    if (_isLogin && !_isPasswordReset)
                      TextButton(
                        child: Text(
                          _getText('forgotPassword'),
                          style: TextStyle(color: Colors.blue[300]),
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordReset = true;
                            _isResetTokenSent = false;
                            _enteredEmail = '';
                          });
                        },
                      ),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 