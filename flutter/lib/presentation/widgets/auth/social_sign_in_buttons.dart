import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/last_login_method.dart';
import '../../../data/services/social_auth_service.dart';
import '../../providers/auth_provider.dart';
import '../../screens/main/main_shell_screen.dart';

/// ログイン画面・アカウント作成画面に置く Google / Apple のボタン
///
/// Googleは「登録」と「ログイン」を分けないため、どちらの画面でも同じ動きをする。
/// 初回のサインインだけ、キャラクターの性別を選ぶ画面へ送る。
class SocialSignInButtons extends ConsumerStatefulWidget {
  const SocialSignInButtons({super.key, this.lastMethod});

  /// 前回のログイン方法（一致するボタンに目印を付ける）
  final LoginMethod? lastMethod;

  @override
  ConsumerState<SocialSignInButtons> createState() => _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends ConsumerState<SocialSignInButtons> {
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _run(Future<SocialSignInResult> Function() signIn) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    // サインイン成功の瞬間にルーターがホームへ飛ばさないよう止めておく
    ref.read(socialSignInInProgressProvider.notifier).state = true;
    try {
      await _handleResult(await signIn());
    } on FirebaseAuthException catch (e) {
      debugPrint('ソーシャルログインエラー: ${e.code} ${e.message}');
      if (mounted) setState(() => _errorMessage = _messageFor(e.code));
    } catch (e) {
      debugPrint('ソーシャルログインエラー: $e');
      if (mounted) setState(() => _errorMessage = 'ログインに失敗しました。もう一度お試しください。');
    } finally {
      ref.read(socialSignInInProgressProvider.notifier).state = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResult(SocialSignInResult result) async {
    if (!mounted) return;
    switch (result.status) {
      case SocialSignInStatus.canceled:
        return;
      case SocialSignInStatus.signedIn:
        ref.read(selectedTabProvider.notifier).state = homeTabIndex;
        context.go('/');
        return;
      case SocialSignInStatus.needsInitialSetup:
        context.go('/character-gender');
        return;
      case SocialSignInStatus.needsLink:
        await _linkWithExistingAccount(result);
        return;
    }
  }

  /// 同じメールアドレスがメール／パスワードで登録済みだったときの連携
  ///
  /// パスワードで本人確認してから紐づけると、以後どちらの方法でも同じアカウントに
  /// 入れる。別アカウントを作ってしまうと、キャラクターも購読状態も分かれてしまう。
  Future<void> _linkWithExistingAccount(SocialSignInResult result) async {
    final email = result.email;
    final credential = result.pendingCredential;
    final method = result.method;
    if (email == null || credential == null || method == null) {
      setState(() => _errorMessage =
          'このメールアドレスは別の方法で登録されています。メールアドレスとパスワードでログインしてください。');
      return;
    }

    final password = await _askPassword(email);
    if (password == null || password.isEmpty || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final linked =
          await ref.read(authControllerProvider.notifier).linkWithPassword(
                email: email,
                password: password,
                credential: credential,
                method: method,
              );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${method.label}を連携しました。次回からどちらでもログインできます。')),
      );
      await _handleResult(linked);
    } on FirebaseAuthException catch (e) {
      debugPrint('連携エラー: ${e.code}');
      if (mounted) setState(() => _errorMessage = _messageFor(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _askPassword(String email) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アカウントの連携'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$email はすでにメールアドレスで登録されています。'
              'パスワードを入力すると同じアカウントにまとめられ、次回からどちらの方法でもログインできます。',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'パスワード'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('連携する'),
          ),
        ],
      ),
    );
  }

  String _messageFor(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'パスワードが違います。';
      case 'network-request-failed':
        return 'ネットワークエラーが発生しました。';
      case 'credential-already-in-use':
        return 'このアカウントはすでに別のユーザーで使われています。';
      default:
        return 'ログインに失敗しました。もう一度お試しください。';
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      if (SocialAuthService.isGoogleAvailable)
        _SocialButton(
          label: 'Googleで続ける',
          isLastUsed: widget.lastMethod == LoginMethod.google,
          onPressed: _isLoading
              ? null
              : () => _run(ref.read(authControllerProvider.notifier).signInWithGoogle),
        ),
      if (SocialAuthService.isAppleAvailable)
        _SocialButton(
          label: 'Appleで続ける',
          icon: Icons.apple,
          isLastUsed: widget.lastMethod == LoginMethod.apple,
          onPressed: _isLoading
              ? null
              : () => _run(ref.read(authControllerProvider.notifier).signInWithApple),
        ),
    ];

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade400)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'または',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade400)),
          ],
        ),
        const SizedBox(height: 12),
        for (final button in buttons) ...[
          button,
          const SizedBox(height: 8),
        ],
        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.onPressed,
    required this.isLastUsed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLastUsed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            if (isLastUsed) ...[
              const SizedBox(width: 8),
              const LastLoginBadge(),
            ],
          ],
        ),
      ),
    );
  }
}

/// 「前回はこちら」の目印
class LastLoginBadge extends StatelessWidget {
  const LastLoginBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFA084CA).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '前回はこちら',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B4E9B),
        ),
      ),
    );
  }
}
