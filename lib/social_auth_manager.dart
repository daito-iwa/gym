import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

// ソーシャル認証の結果
class SocialAuthResult {
  final bool success;
  final String? accessToken;
  final String? idToken;
  final String? userId;
  final String? username;
  final String? email;
  final String? fullName;
  final String? avatarUrl;
  final String? provider;
  final String? errorMessage;

  SocialAuthResult({
    required this.success,
    this.accessToken,
    this.idToken,
    this.userId,
    this.username,
    this.email,
    this.fullName,
    this.avatarUrl,
    this.provider,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'access_token': accessToken,
      'id_token': idToken,
      'user_id': userId,
      'username': username,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'provider': provider,
      'error_message': errorMessage,
    };
  }

  factory SocialAuthResult.fromJson(Map<String, dynamic> json) {
    return SocialAuthResult(
      success: json['success'] ?? false,
      accessToken: json['access_token'],
      idToken: json['id_token'],
      userId: json['user_id'],
      username: json['username'],
      email: json['email'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      provider: json['provider'],
      errorMessage: json['error_message'],
    );
  }
}

// ソーシャル認証プロバイダー
enum SocialProvider { google }

// ソーシャル認証マネージャー
class SocialAuthManager {
  static final SocialAuthManager _instance = SocialAuthManager._internal();
  factory SocialAuthManager() => _instance;
  SocialAuthManager._internal();

  // Google Sign-In設定（実際のClient IDに変更してください）
  static const String _googleClientId = 'YOUR_ACTUAL_GOOGLE_CLIENT_ID.apps.googleusercontent.com';
  static const String _iosGoogleClientId = 'YOUR_ACTUAL_IOS_GOOGLE_CLIENT_ID.apps.googleusercontent.com';
  
  late GoogleSignIn _googleSignIn;
  bool _isInitialized = false;

  // 初期化
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Google Sign-In の初期化
      _googleSignIn = GoogleSignIn(
        scopes: [
          'email',
          'profile',
        ],
      );
      
      _isInitialized = true;
      print('Social Auth Manager initialized successfully');
    } catch (e) {
      print('Failed to initialize Social Auth Manager: $e');
    }
  }

  // Google Sign-In
  Future<SocialAuthResult> signInWithGoogle() async {
    try {
      await initialize();
      
      // 本番版：実際のGoogle Sign-In
      print('Google Sign-In: 認証開始');
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return SocialAuthResult(
          success: false,
          errorMessage: 'Googleサインインがキャンセルされました',
        );
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // サーバーで認証
      final result = await _authenticateWithServer(
        provider: 'google',
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
        email: googleUser.email,
        fullName: googleUser.displayName,
        avatarUrl: googleUser.photoUrl,
      );
      
      if (result.success) {
        await _saveAuthResult(result);
      }
      
      return result;
      
    } catch (e) {
      print('Google sign-in error: $e');
      return SocialAuthResult(
        success: false,
        errorMessage: 'Googleサインインに失敗しました: ${e.toString()}',
      );
    }
  }


  // サーバーでの認証処理（オフライン版）
  Future<SocialAuthResult> _authenticateWithServer({
    required String provider,
    String? idToken,
    String? accessToken,
    String? email,
    String? fullName,
    String? avatarUrl,
    String? userIdentifier,
  }) async {
    try {
      // 本番版：実際のサーバー認証
      print('サーバー認証開始: $provider');
      
      final response = await http.post(
        Uri.parse('${_getServerUrl()}/auth/social'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'provider': provider,
          'id_token': idToken,
          'access_token': accessToken,
          'email': email,
          'full_name': fullName,
          'avatar_url': avatarUrl,
          'user_identifier': userIdentifier,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        return SocialAuthResult(
          success: true,
          accessToken: data['access_token'],
          idToken: idToken,
          userId: data['user']['id'],
          username: data['user']['username'],
          email: data['user']['email'],
          fullName: data['user']['full_name'],
          avatarUrl: data['user']['avatar_url'],
          provider: provider,
        );
      } else {
        final error = jsonDecode(response.body);
        return SocialAuthResult(
          success: false,
          errorMessage: error['detail'] ?? 'サーバー認証に失敗しました',
        );
      }
      
    } catch (e) {
      print('Server authentication error: $e');
      return SocialAuthResult(
        success: false,
        errorMessage: 'サーバーとの通信に失敗しました',
      );
    }
  }

  // 認証結果をローカルに保存
  Future<void> _saveAuthResult(SocialAuthResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('social_auth_result', jsonEncode(result.toJson()));
      await prefs.setString('access_token', result.accessToken ?? '');
      await prefs.setString('user_id', result.userId ?? '');
      await prefs.setString('username', result.username ?? '');
      await prefs.setString('email', result.email ?? '');
      await prefs.setString('auth_provider', result.provider ?? '');
      print('Social auth result saved locally');
    } catch (e) {
      print('Failed to save auth result: $e');
    }
  }

  // 保存された認証結果を取得
  Future<SocialAuthResult?> getSavedAuthResult() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authResultJson = prefs.getString('social_auth_result');
      
      if (authResultJson != null) {
        final data = jsonDecode(authResultJson);
        return SocialAuthResult.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Failed to get saved auth result: $e');
      return null;
    }
  }

  // サインアウト
  Future<void> signOut() async {
    try {
      // Google Sign-Out
      if (_isInitialized) {
        await _googleSignIn.signOut();
      }
      
      // ローカルの認証情報をクリア
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('social_auth_result');
      await prefs.remove('access_token');
      await prefs.remove('user_id');
      await prefs.remove('username');
      await prefs.remove('email');
      await prefs.remove('auth_provider');
      
      print('Successfully signed out from all social providers');
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  // 現在のユーザーが認証済みかチェック
  Future<bool> isAuthenticated() async {
    final savedResult = await getSavedAuthResult();
    return savedResult?.success == true;
  }

  // 利用可能な認証プロバイダーを取得
  List<SocialProvider> getAvailableProviders() {
    return [SocialProvider.google];
  }

  // プロバイダー名を取得
  String getProviderName(SocialProvider provider) {
    switch (provider) {
      case SocialProvider.google:
        return 'Google';
    }
  }

  // プロバイダーのアイコンを取得
  String getProviderIcon(SocialProvider provider) {
    switch (provider) {
      case SocialProvider.google:
        return '🌐'; // 実際の実装では適切なアイコンを使用
    }
  }

  // 内部ヘルパーメソッド
  String _generateNonce() {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = math.Random.secure();
    return List.generate(32, (_) => charset[random.nextInt(charset.length)]).join();
  }


  String _getServerUrl() {
    // 開発環境では localhost、本番環境では実際のサーバーURL
    if (kDebugMode) {
      return 'http://127.0.0.1:8080';
    } else {
      return 'https://your-production-server.com';
    }
  }

  // デバッグ情報を取得
  Future<Map<String, dynamic>> getDebugInfo() async {
    final savedResult = await getSavedAuthResult();
    return {
      'is_initialized': _isInitialized,
      'is_authenticated': await isAuthenticated(),
      'available_providers': getAvailableProviders().map((p) => getProviderName(p)).toList(),
      'saved_auth_provider': savedResult?.provider,
      'saved_user_id': savedResult?.userId,
      'saved_email': savedResult?.email,
    };
  }
}

// ソーシャル認証用のUIウィジェット

class SocialSignInButton extends StatelessWidget {
  final SocialProvider provider;
  final VoidCallback onPressed;
  final bool isLoading;

  const SocialSignInButton({
    Key? key,
    required this.provider,
    required this.onPressed,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final manager = SocialAuthManager();
    final providerName = manager.getProviderName(provider);
    final providerIcon = manager.getProviderIcon(provider);
    
    Color backgroundColor;
    Color textColor;
    
    switch (provider) {
      case SocialProvider.google:
        backgroundColor = Colors.white;
        textColor = Colors.black87;
        break;
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : () {
          print('ソーシャルサインインボタンが押されました: ${manager.getProviderName(provider)}');
          onPressed();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[300]!),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: textColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    providerIcon,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$providerNameでサインイン',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ソーシャル認証オプション表示ウィジェット
class SocialAuthOptions extends StatefulWidget {
  final Function(SocialAuthResult) onAuthSuccess;
  final Function(String) onAuthError;

  const SocialAuthOptions({
    Key? key,
    required this.onAuthSuccess,
    required this.onAuthError,
  }) : super(key: key);

  @override
  State<SocialAuthOptions> createState() => _SocialAuthOptionsState();
}

class _SocialAuthOptionsState extends State<SocialAuthOptions> {
  final SocialAuthManager _authManager = SocialAuthManager();
  Set<SocialProvider> _loadingProviders = {};

  @override
  void initState() {
    super.initState();
    _authManager.initialize();
  }

  Future<void> _handleSocialSignIn(SocialProvider provider) async {
    print('ソーシャル認証開始: ${_authManager.getProviderName(provider)}');
    
    setState(() {
      _loadingProviders.add(provider);
    });

    try {
      SocialAuthResult result;
      
      switch (provider) {
        case SocialProvider.google:
          print('Google認証を実行中...');
          result = await _authManager.signInWithGoogle();
          break;
      }

      print('認証結果: success=${result.success}, error=${result.errorMessage}');

      if (result.success) {
        print('認証成功、onAuthSuccessコールバック呼び出し');
        widget.onAuthSuccess(result);
      } else {
        print('認証失敗: ${result.errorMessage}');
        widget.onAuthError(result.errorMessage ?? '認証に失敗しました');
      }
    } catch (e) {
      print('認証エラー: $e');
      widget.onAuthError('認証中にエラーが発生しました: $e');
    } finally {
      setState(() {
        _loadingProviders.remove(provider);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableProviders = _authManager.getAvailableProviders();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ソーシャルアカウントでサインイン',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ...availableProviders.map((provider) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SocialSignInButton(
              provider: provider,
              isLoading: _loadingProviders.contains(provider),
              onPressed: () => _handleSocialSignIn(provider),
            ),
          );
        }).toList(),
      ],
    );
  }
}