import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userDocProvider);
    final isPremium = ref.watch(effectiveIsPremiumProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('設定'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          // アカウント情報
          _SectionHeader(title: 'アカウント'),
          userAsync.when(
            data: (user) => _SettingsTile(
              icon: Icons.person,
              title: user?.email ?? 'ログイン中',
              subtitle: isPremium ? 'プレミアム会員' : '無料会員',
              trailing: isPremium
                  ? const Icon(Icons.star, color: Colors.amber)
                  : const Icon(Icons.chevron_right),
              onTap: () => context.push('/profile'),
            ),
            loading: () => const _SettingsTile(
              icon: Icons.person,
              title: '読み込み中...',
            ),
            error: (e, st) => _SettingsTile(
              icon: Icons.person,
              title: 'エラー',
              subtitle: e.toString(),
            ),
          ),

          // プレミアムアップグレード（非プレミアムユーザーのみ表示）
          if (!isPremium)
            _SettingsTile(
              icon: Icons.workspace_premium,
              title: 'プレミアムにアップグレード',
              subtitle: '広告なしで快適な体験を',
              trailing: const Icon(Icons.star, color: Colors.amber),
              onTap: () => context.push('/premium'),
            ),

          const Divider(),

          // セキュリティ
          _SectionHeader(title: 'セキュリティ'),
          _SettingsTile(
            icon: Icons.lock,
            title: 'パスワード変更',
            subtitle: 'パスワードを変更',
            onTap: () => context.push('/change-password'),
          ),

          const Divider(),

          // 表示設定
          _SectionHeader(title: '表示設定'),
          _SettingsTile(
            icon: Icons.palette,
            title: 'テーマ',
            subtitle: 'テーマモードとカラーの設定',
            onTap: () => context.push('/theme-settings'),
          ),
          _SettingsTile(
            icon: Icons.label,
            title: 'タグ管理',
            subtitle: 'タグの追加・編集・削除',
            onTap: () => context.push('/tag-management'),
          ),
          _SettingsTile(
            icon: Icons.text_fields,
            title: 'フォント設定',
            subtitle: 'フォントサイズ・行間の設定',
            onTap: () => context.push('/font-settings'),
          ),
          _SettingsTile(
            icon: Icons.volume_up,
            title: '音量設定',
            subtitle: 'BGM・キャラクター音声の設定',
            onTap: () => context.push('/volume-settings'),
          ),

          const Divider(),

          // 通知設定
          _SectionHeader(title: '通知'),
          _SettingsTile(
            icon: Icons.notifications,
            title: '通知設定',
            subtitle: 'プッシュ通知の設定',
            onTap: () => context.push('/notification-settings'),
          ),

          const Divider(),

          // データ管理
          _SectionHeader(title: 'データ管理'),
          _SettingsTile(
            icon: Icons.psychology,
            title: 'BIG5診断結果',
            subtitle: '性格診断の結果を確認',
            onTap: () => context.push('/big5/results'),
          ),
          _SettingsTile(
            icon: Icons.history,
            title: '履歴',
            subtitle: 'チャット・会議の履歴を確認',
            onTap: () => context.push('/history'),
          ),
          _SettingsTile(
            icon: Icons.download,
            title: 'データエクスポート',
            subtitle: 'データをJSON形式で出力',
            onTap: () => context.push('/data-export'),
          ),
          _SettingsTile(
            icon: Icons.upload,
            title: 'データインポート',
            subtitle: 'JSONデータを読み込み',
            onTap: () => context.push('/data-import'),
          ),

          const Divider(),

          // プライバシー
          _SectionHeader(title: 'プライバシー'),
          _SettingsTile(
            icon: Icons.privacy_tip,
            title: 'プライバシー設定',
            subtitle: 'データ収集・広告の設定',
            onTap: () => context.push('/privacy-settings'),
          ),

          const Divider(),

          // サポート
          _SectionHeader(title: 'サポート'),
          _SettingsTile(
            icon: Icons.help,
            title: 'ヘルプ',
            onTap: () => context.push('/help'),
          ),
          _SettingsTile(
            icon: Icons.feedback,
            title: 'フィードバック',
            subtitle: 'ご意見・ご要望をお送りください',
            onTap: () => context.push('/feedback'),
          ),
          _SettingsTile(
            icon: Icons.mail,
            title: 'お問い合わせ',
            subtitle: 'darias.app4@gmail.com',
            onTap: () => _openContact(context),
          ),
          _SettingsTile(
            icon: Icons.description,
            title: '利用規約',
            onTap: () => _openTerms(context),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip,
            title: 'プライバシーポリシー',
            onTap: () => _openPrivacyPolicy(context),
          ),

          const Divider(),

          // アプリ情報
          _SectionHeader(title: 'アプリ情報'),
          _SettingsTile(
            icon: Icons.info,
            title: 'アプリについて',
            subtitle: 'バージョン情報・ライセンス',
            onTap: () => context.push('/about'),
          ),

          const Divider(),

          // アカウント操作
          _SectionHeader(title: 'アカウント操作'),
          _SettingsTile(
            icon: Icons.logout,
            title: 'ログアウト',
            textColor: Colors.orange,
            onTap: () => _confirmLogout(context, ref),
          ),
          _SettingsTile(
            icon: Icons.delete_forever,
            title: 'アカウント削除',
            textColor: Colors.red,
            onTap: () => _confirmDeleteAccount(context, ref),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テーマ設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('システム設定に従う'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('ライトモード'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('ダークモード'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('通知設定'),
        content: const Text('通知設定はデバイスの設定アプリから変更できます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openHelp(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ヘルプページは準備中です')),
    );
  }

  Future<void> _openContact(BuildContext context) async {
    final uri = Uri.parse('mailto:darias.app4@gmail.com?subject=Dariasアプリについて');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メールアプリを開けませんでした')),
        );
      }
    }
  }

  void _openTerms(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('利用規約ページは準備中です')),
    );
  }

  void _openPrivacyPolicy(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('プライバシーポリシーページは準備中です')),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アカウント削除'),
        content: const Text(
          'アカウントを削除すると、すべてのデータが完全に削除され、復元できなくなります。\n\n本当に削除しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // 最終確認
      final finalConfirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('最終確認'),
          content: const Text('この操作は取り消せません。アカウントとすべてのデータを完全に削除しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('完全に削除'),
            ),
          ],
        ),
      );

      if (finalConfirm == true && context.mounted) {
        // パスワード再入力ダイアログ
        final password = await _showPasswordDialog(context);
        if (password == null || !context.mounted) return;

        try {
          // ローディング表示
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );

          final user = FirebaseAuth.instance.currentUser;
          if (user == null || user.email == null) {
            throw Exception('ユーザーが見つかりません');
          }

          // 再認証
          final credential = EmailAuthProvider.credential(
            email: user.email!,
            password: password,
          );
          await user.reauthenticateWithCredential(credential);

          // Firestoreのユーザーデータを削除
          await ref.read(firestoreProvider)
              .collection('users')
              .doc(user.uid)
              .delete();

          // Authのユーザーを削除
          await user.delete();

          if (context.mounted) {
            Navigator.of(context).pop(); // ローディングを閉じる
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('アカウントを削除しました'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } on FirebaseAuthException catch (e) {
          if (context.mounted) {
            Navigator.of(context).pop(); // ローディングを閉じる
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_getDeleteErrorMessage(e.code))),
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.of(context).pop(); // ローディングを閉じる
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('エラーが発生しました: $e')),
            );
          }
        }
      }
    }
  }

  Future<String?> _showPasswordDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('パスワードを入力'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('セキュリティのため、パスワードを入力してください。'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'パスワード',
                border: OutlineInputBorder(),
              ),
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除を続行'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String _getDeleteErrorMessage(String code) {
    switch (code) {
      case 'wrong-password':
        return 'パスワードが正しくありません';
      case 'requires-recent-login':
        return 'セキュリティのため、再度ログインしてください';
      case 'too-many-requests':
        return 'リクエストが多すぎます。しばらくしてからお試しください';
      default:
        return 'エラーが発生しました ($code)';
    }
  }
}

/// セクションヘッダー
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 設定タイル
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? textColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(
        title,
        style: TextStyle(color: textColor),
      ),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}
