// 生体認証管理クラス

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

// アプリ専用の生体認証タイプ
enum AppBiometricType { none, fingerprint, face, iris }

// 生体認証結果
class BiometricAuthResult {
  final bool success;
  final String? errorMessage;
  final AppBiometricType? usedBiometricType;
  
  BiometricAuthResult({
    required this.success,
    this.errorMessage,
    this.usedBiometricType,
  });
}

// 生体認証マネージャー
class BiometricAuthManager {
  static final BiometricAuthManager _instance = BiometricAuthManager._internal();
  factory BiometricAuthManager() => _instance;
  BiometricAuthManager._internal();
  
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // 設定キー
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _userCredentialsKey = 'user_credentials_encrypted';
  
  // 生体認証が利用可能かチェック
  Future<bool> isBiometricAvailable() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } on PlatformException catch (e) {
      print('Biometric availability check failed: $e');
      return false;
    }
  }
  
  // 利用可能な生体認証タイプを取得
  Future<List<AppBiometricType>> getAvailableBiometrics() async {
    try {
      if (!await isBiometricAvailable()) {
        return [AppBiometricType.none];
      }
      
      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      List<AppBiometricType> biometricTypes = [];
      
      for (BiometricType biometric in availableBiometrics) {
        switch (biometric) {
          case BiometricType.fingerprint:
            biometricTypes.add(AppBiometricType.fingerprint);
            break;
          case BiometricType.face:
            biometricTypes.add(AppBiometricType.face);
            break;
          case BiometricType.iris:
            biometricTypes.add(AppBiometricType.iris);
            break;
          default:
            break;
        }
      }
      
      return biometricTypes.isEmpty ? [AppBiometricType.none] : biometricTypes;
    } catch (e) {
      print('Get available biometrics failed: $e');
      return [AppBiometricType.none];
    }
  }
  
  // 生体認証設定状態をチェック
  Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricEnabledKey) ?? false;
    } catch (e) {
      print('Check biometric enabled failed: $e');
      return false;
    }
  }
  
  // 生体認証を有効/無効に設定
  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, enabled);
      
      if (!enabled) {
        // 無効化する場合は保存された認証情報も削除
        await _clearStoredCredentials();
      }
    } catch (e) {
      print('Set biometric enabled failed: $e');
    }
  }
  
  // 認証情報を生体認証で保護して保存
  Future<bool> storeCredentialsWithBiometric({
    required String username,
    required String password,
    String? email,
    String? token,
  }) async {
    try {
      if (!await isBiometricAvailable()) {
        return false;
      }
      
      // 生体認証で保存確認
      final authResult = await _authenticateWithBiometric(
        reason: '認証情報を安全に保存するために生体認証が必要です',
      );
      
      if (!authResult.success) {
        return false;
      }
      
      // 認証情報をJSONとして暗号化保存
      final credentialsJson = {
        'username': username,
        'password': password,
        'email': email,
        'token': token,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await _secureStorage.write(
        key: _userCredentialsKey,
        value: credentialsJson.toString(),
      );
      
      // 生体認証を有効に設定
      await setBiometricEnabled(true);
      
      return true;
    } catch (e) {
      print('Store credentials with biometric failed: $e');
      return false;
    }
  }
  
  // 生体認証で認証情報を取得
  Future<Map<String, String>?> getCredentialsWithBiometric() async {
    try {
      if (!await isBiometricEnabled()) {
        return null;
      }
      
      // 生体認証実行
      final authResult = await _authenticateWithBiometric(
        reason: '保存された認証情報にアクセスするために生体認証が必要です',
      );
      
      if (!authResult.success) {
        return null;
      }
      
      // 保存された認証情報を取得
      final credentialsString = await _secureStorage.read(key: _userCredentialsKey);
      if (credentialsString == null) {
        return null;
      }
      
      // JSONパース（簡単な実装）
      final credentials = <String, String>{};
      final parts = credentialsString
          .replaceAll('{', '')
          .replaceAll('}', '')
          .split(', ');
          
      for (String part in parts) {
        final keyValue = part.split(': ');
        if (keyValue.length == 2) {
          credentials[keyValue[0]] = keyValue[1];
        }
      }
      
      return credentials;
    } catch (e) {
      print('Get credentials with biometric failed: $e');
      return null;
    }
  }
  
  // 生体認証実行（内部メソッド）
  Future<BiometricAuthResult> _authenticateWithBiometric({
    required String reason,
  }) async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      
      if (didAuthenticate) {
        final availableBiometrics = await getAvailableBiometrics();
        AppBiometricType usedType = AppBiometricType.fingerprint;
        
        if (availableBiometrics.contains(AppBiometricType.face)) {
          usedType = AppBiometricType.face;
        } else if (availableBiometrics.contains(AppBiometricType.iris)) {
          usedType = AppBiometricType.iris;
        }
        
        return BiometricAuthResult(
          success: true,
          usedBiometricType: usedType,
        );
      } else {
        return BiometricAuthResult(
          success: false,
          errorMessage: 'ユーザーが認証をキャンセルしました',
        );
      }
    } on PlatformException catch (e) {
      String errorMessage = 'エラーが発生しました';
      
      switch (e.code) {
        case auth_error.notAvailable:
          errorMessage = '生体認証が利用できません';
          break;
        case auth_error.notEnrolled:
          errorMessage = '生体認証が設定されていません';
          break;
        case auth_error.lockedOut:
          errorMessage = '認証試行回数が上限に達しました';
          break;
        case auth_error.permanentlyLockedOut:
          errorMessage = '生体認証が永続的にロックされました';
          break;
        default:
          errorMessage = '認証に失敗しました: ${e.message}';
      }
      
      return BiometricAuthResult(
        success: false,
        errorMessage: errorMessage,
      );
    }
  }
  
  // 保存された認証情報をクリア
  Future<void> _clearStoredCredentials() async {
    try {
      await _secureStorage.delete(key: _userCredentialsKey);
    } catch (e) {
      print('Clear stored credentials failed: $e');
    }
  }
  
  // 生体認証タイプの日本語名を取得
  String getBiometricTypeName(AppBiometricType type) {
    switch (type) {
      case AppBiometricType.face:
        return Platform.isIOS ? 'Face ID' : 'Face認証';
      case AppBiometricType.fingerprint:
        return Platform.isIOS ? 'Touch ID' : '指紋認証';
      case AppBiometricType.iris:
        return 'Iris認証';
      case AppBiometricType.none:
      default:
        return '生体認証なし';
    }
  }
  
  // 生体認証タイプのアイコンを取得
  IconData getBiometricTypeIcon(AppBiometricType type) {
    switch (type) {
      case AppBiometricType.face:
        return Icons.face;
      case AppBiometricType.fingerprint:
        return Icons.fingerprint;
      case AppBiometricType.iris:
        return Icons.visibility;
      case AppBiometricType.none:
      default:
        return Icons.security;
    }
  }
  
  // デバッグ情報を取得
  Future<Map<String, dynamic>> getDebugInfo() async {
    return {
      'is_available': await isBiometricAvailable(),
      'is_enabled': await isBiometricEnabled(),
      'available_biometrics': (await getAvailableBiometrics()).map((e) => getBiometricTypeName(e)).toList(),
      'device_supported': await _localAuth.isDeviceSupported(),
      'can_check_biometrics': await _localAuth.canCheckBiometrics,
      'platform': Platform.operatingSystem,
    };
  }
}