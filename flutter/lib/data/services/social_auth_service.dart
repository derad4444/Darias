import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google / Apple のサインインを扱うサービス
///
/// Firebase Auth に渡す資格情報を作るところまでを担当し、サインイン自体は
/// [AuthController] が行う。連携（linkWithCredential）や再認証でも同じ
/// 資格情報を使い回せるようにするため、ここでは資格情報だけを返している。
class SocialAuthService {
  /// iOS用のOAuthクライアントID（`ios/GoogleService-Info.plist` の CLIENT_ID）
  static const _iosClientId =
      '881831618841-6c6581ubbavfaobbl5qtt02hpafqffo6.apps.googleusercontent.com';

  /// WebクライアントID（`android/app/google-services.json` の client_type 3）。
  /// Androidでは、これを serverClientId に渡さないと idToken が返ってこない
  static const _webClientId =
      '881831618841-9u8pbt5bhum6fbg5l7oujje3cu4ftlnu.apps.googleusercontent.com';

  static bool _initialized = false;

  /// Googleサインインが使える環境か
  ///
  /// Webはサインイン用のボタンをGoogleのSDKに描画させる必要があり、アプリ側の
  /// ボタンからは開始できないため対象外にしている。
  static bool get isGoogleAvailable => !kIsWeb;

  /// Appleサインインが使える環境か
  ///
  /// Androidでも技術的には動くが、Apple Developer側でService IDとリダイレクト先の
  /// 設定が別途必要になるため、いまはiOSだけに出している。
  static bool get isAppleAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS ? _iosClientId : null,
      serverClientId: _webClientId,
    );
    _initialized = true;
  }

  /// Googleの資格情報を取得する（ユーザーが途中でやめたら null）
  static Future<AuthCredential?> googleCredential() async {
    await _ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'missing-google-id-token',
          message: 'Googleから認証情報を取得できませんでした',
        );
      }
      return GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// Appleのプロバイダー設定
  ///
  /// Appleは資格情報を先に取り出せないので、Firebase Auth のプロバイダー経由の
  /// API（signInWithProvider / linkWithProvider / reauthenticateWithProvider）を使う。
  static AppleAuthProvider appleProvider() {
    return AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
  }

  /// Googleのサインアウト（アプリからログアウトしたら、次回また選び直せるようにする）
  static Future<void> signOutGoogle() async {
    if (!isGoogleAvailable || !_initialized) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('Googleサインアウトに失敗: $e');
    }
  }
}
