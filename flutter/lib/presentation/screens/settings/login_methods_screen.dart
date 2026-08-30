import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/last_login_method.dart';
import '../../../data/services/social_auth_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

/// ログイン方法の管理画面
///
/// 1つのアカウントに複数のログイン方法を紐づけられる。ログイン中は本人確認が
/// 済んでいるので、ここからならパスワードを聞かずに追加できる（ログイン画面での
/// 連携はパスワードでの本人確認が要るため、パスワードを持たない Google / Apple
/// 起点のアカウントでは連携できない。その入口がここ）。
class LoginMethodsScreen extends ConsumerStatefulWidget {
  const LoginMethodsScreen({super.key});

  @override
  ConsumerState<LoginMethodsScreen> createState() => _LoginMethodsScreenState();
}

class _LoginMethodsScreenState extends ConsumerState<LoginMethodsScreen> {
  bool _isBusy = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  Set<String> get _linkedProviderIds =>
      _user?.providerData.map((info) => info.providerId).toSet() ?? {};

  Future<void> _run(Future<bool> Function() action, String doneMessage) async {
    setState(() => _isBusy = true);
    try {
      final changed = await action();
      if (!mounted) return;
      setState(() {});
      if (changed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(doneMessage)),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('ログイン方法の変更に失敗: ${e.code} ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_messageFor(e.code))),
        );
      }
    } catch (e) {
      debugPrint('ログイン方法の変更に失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('変更に失敗しました。もう一度お試しください。')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _messageFor(String code) {
    switch (code) {
      case 'credential-already-in-use':
      case 'email-already-in-use':
        return 'そのアカウントは、すでに別のDARIASアカウントで使われています。';
      case 'provider-already-linked':
        return 'すでに連携済みです。';
      case 'requires-recent-login':
        return '安全のため、一度ログインし直してから操作してください。';
      case 'weak-password':
        return 'パスワードは6文字以上で入力してください。';
      case 'last-provider':
        return 'ログイン方法が1つだけのため解除できません。';
      case 'network-request-failed':
        return 'ネットワークエラーが発生しました。';
      default:
        return '変更に失敗しました。もう一度お試しください。';
    }
  }

  Future<void> _linkEmail() async {
    final user = _user;
    if (user == null) return;
    final result = await _askEmailAndPassword(user.email);
    if (result == null || !mounted) return;
    await _run(() async {
      await ref.read(authControllerProvider.notifier).linkEmailPassword(
            email: result.email,
            password: result.password,
          );
      return true;
    }, 'メールアドレスでもログインできるようになりました。');
  }

  Future<void> _unlink(LoginMethod method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${method.label}の連携を解除'),
        content: Text('${method.label}ではログインできなくなります。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('解除する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await ref
          .read(authControllerProvider.notifier)
          .unlinkProvider(method.providerId);
      return true;
    }, '${method.label}の連携を解除しました。');
  }

  /// メールログインを足すときの入力（メールアドレスが無いアカウントもあるので両方聞ける形にする）
  Future<({String email, String password})?> _askEmailAndPassword(
    String? currentEmail,
  ) {
    final emailController = TextEditingController(text: currentEmail ?? '');
    final passwordController = TextEditingController();
    return showDialog<({String email, String password})>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メールアドレスでのログインを追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'パスワードを決めると、メールアドレスとパスワードでもログインできるようになります。',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              readOnly: currentEmail != null,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(hintText: 'メールアドレス'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'パスワード（6文字以上）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              final email = emailController.text.trim();
              final password = passwordController.text;
              if (email.isEmpty || password.isEmpty) return;
              Navigator.pop(context, (email: email, password: password));
            },
            child: const Text('設定する'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final textColor = ref.watch(colorSettingsProvider).textColor;
    final linked = _linkedProviderIds;

    final rows = <Widget>[
      _MethodRow(
        method: LoginMethod.email,
        isLinked: linked.contains(LoginMethod.email.providerId),
        subtitle: linked.contains(LoginMethod.email.providerId)
            ? (_user?.email ?? '')
            : 'パスワードを決めて、メールでもログインできるようにする',
        isBusy: _isBusy,
        onLink: _linkEmail,
        onUnlink: () => _unlink(LoginMethod.email),
      ),
      if (SocialAuthService.isGoogleAvailable)
        _MethodRow(
          method: LoginMethod.google,
          isLinked: linked.contains(LoginMethod.google.providerId),
          subtitle: linked.contains(LoginMethod.google.providerId)
              ? _emailOf(LoginMethod.google.providerId)
              : 'Googleアカウントでもログインできるようにする',
          isBusy: _isBusy,
          onLink: () => _run(
            ref.read(authControllerProvider.notifier).linkGoogle,
            'Googleを連携しました。',
          ),
          onUnlink: () => _unlink(LoginMethod.google),
        ),
      if (SocialAuthService.isAppleAvailable)
        _MethodRow(
          method: LoginMethod.apple,
          isLinked: linked.contains(LoginMethod.apple.providerId),
          subtitle: linked.contains(LoginMethod.apple.providerId)
              ? _emailOf(LoginMethod.apple.providerId)
              : 'Apple IDでもログインできるようにする',
          isBusy: _isBusy,
          onLink: () => _run(
            ref.read(authControllerProvider.notifier).linkApple,
            'Appleを連携しました。',
          ),
          onUnlink: () => _unlink(LoginMethod.apple),
        ),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text('ログイン方法', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '連携しておくと、どの方法でも同じアカウントにログインできます。'
                'キャラクターや購読の状態は1つのままです。',
                style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 12),
              ...rows,
              if (linked.length <= 1) ...[
                const SizedBox(height: 12),
                Text(
                  'ログイン方法が1つだけのときは解除できません。',
                  style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _emailOf(String providerId) {
    final info = _user?.providerData
        .where((info) => info.providerId == providerId)
        .firstOrNull;
    return info?.email ?? '連携済み';
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.method,
    required this.isLinked,
    required this.subtitle,
    required this.isBusy,
    required this.onLink,
    required this.onUnlink,
  });

  final LoginMethod method;
  final bool isLinked;
  final String subtitle;
  final bool isBusy;
  final VoidCallback onLink;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      method.label,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    if (isLinked) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA084CA).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '連携済み',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B4E9B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          isLinked
              ? TextButton(
                  onPressed: isBusy ? null : onUnlink,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('解除'),
                )
              : TextButton(
                  onPressed: isBusy ? null : onLink,
                  child: const Text('連携する'),
                ),
        ],
      ),
    );
  }
}
