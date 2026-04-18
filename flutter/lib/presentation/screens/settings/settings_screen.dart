import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../../data/models/subscription_model.dart';
import '../../providers/ad_provider.dart';
import '../../providers/big5_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';
import '../../widgets/character_avatar_widget.dart';
import '../../../data/services/ad_service.dart';
import '../../../data/services/hint_service.dart';

/// iOS版OptionViewと同じデザインの設定画面
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final userAsync = ref.watch(userDocProvider);
    final isPremium = ref.watch(effectiveIsPremiumProvider);
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);
    final colorSettings = ref.watch(colorSettingsProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ヘッダー
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'オプション',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),

              // 上部バナー広告（無料ユーザーのみ）
              if (shouldShowBannerAd)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: BannerAdContainer(adUnitId: AdConfig.settingsTopBannerAdUnitId),
                  ),
                ),

              // プレミアムアップグレード（無料ユーザーのみ）
              if (!isPremium)
                SliverToBoxAdapter(
                  child: _PremiumUpgradeCard(
                    accentColor: accentColor,
                    onTap: () => context.push('/premium'),
                  ),
                ),

              // 設定項目
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // ユーザー情報
                    _UserInfoCard(
                      user: userAsync.valueOrNull,
                      userId: ref.watch(currentUserIdProvider) ?? '',
                    ),

                    const SizedBox(height: 8),

                    // 通知設定
                    _SettingsCard(
                      title: '通知設定',
                      subtitle: '予定・日記の通知を管理',
                      icon: Icons.notifications_outlined,
                      onTap: () => context.push('/notification-settings'),
                    ),

                    // 音量設定
                    _SettingsCard(
                      title: '音量設定',
                      subtitle: 'BGM・キャラクター音声の音量調整',
                      icon: Icons.volume_up_outlined,
                      onTap: () => context.push('/volume-settings'),
                    ),

                    // 背景色・文字色
                    _SettingsCard(
                      title: '背景色・文字色',
                      subtitle: colorSettings.useGradient ? 'グラデーション' : '一色',
                      icon: Icons.palette_outlined,
                      onTap: () => context.push('/theme-settings'),
                    ),

                    // タグ管理
                    _SettingsCard(
                      title: 'タグ管理',
                      subtitle: '予定のタグを作成・編集',
                      icon: Icons.label_outlined,
                      onTap: () => context.push('/tag-management'),
                    ),

                    // 使い方ガイド
                    _SettingsCard(
                      title: '使い方ガイド',
                      subtitle: '機能の説明・操作方法を確認',
                      icon: Icons.help_outline,
                      onTap: () => context.push('/help-guide'),
                    ),

                    const SizedBox(height: 16),

                    // SNS・サポート
                    _SocialSupportCard(
                      onInstagramTap: () => _openInstagram(),
                      onContactTap: () => context.push('/feedback'),
                    ),

                    const SizedBox(height: 16),

                    // 利用規約・プライバシーポリシー
                    _SettingsCard(
                      title: '利用規約',
                      subtitle: 'サービス利用規約を確認',
                      icon: Icons.article_outlined,
                      onTap: () => _openTermsOfService(context),
                    ),
                    _SettingsCard(
                      title: 'プライバシーポリシー',
                      subtitle: '個人情報の取り扱いについて',
                      icon: Icons.privacy_tip_outlined,
                      onTap: () => _openPrivacyPolicy(context),
                    ),

                    const SizedBox(height: 16),

                    // 下部バナー広告（無料ユーザーのみ）
                    if (shouldShowBannerAd)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: BannerAdContainer(adUnitId: AdConfig.settingsBottomBannerAdUnitId),
                      ),

                    // 性格診断リセット
                    _DangerButton(
                      title: '性格診断をリセット',
                      onTap: () => _confirmResetDiagnosis(context, ref),
                    ),

                    // ログアウト
                    _DangerButton(
                      title: 'ログアウト',
                      onTap: () => _confirmLogout(context, ref),
                    ),

                    // アカウント削除
                    _DangerButton(
                      title: 'アカウントを削除',
                      onTap: () => _confirmDeleteAccount(context, ref),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openInstagram() async {
    const instagramUrl = 'https://www.instagram.com/darias_1024/';
    final uri = Uri.parse(instagramUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openTermsOfService(BuildContext context) {
    context.push('/terms');
  }

  void _openPrivacyPolicy(BuildContext context) {
    context.push('/privacy');
  }

  Future<void> _confirmResetDiagnosis(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('性格診断をリセット'),
        content: const Text(
          'これまでの診断結果・回答・キャラクター属性（夢・口癖など）がすべて削除されます。\nリセット後は最初から診断をやり直せます。\n\nよろしいですか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('リセットする'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final user = ref.read(userDocProvider).valueOrNull;
      final characterId = user?.characterId;
      if (characterId == null) return;

      try {
        await ref
            .read(big5DiagnosisControllerProvider.notifier)
            .resetDiagnosis(characterId);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('性格診断をリセットしました'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('リセットに失敗しました: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    final isPremium = ref.read(effectiveIsPremiumProvider);
    final subscription = ref.read(currentSubscriptionProvider);
    final isAppStorePremium = isPremium && subscription.paymentMethod == PaymentMethod.appStore;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      // App Store の有料ユーザーには手動キャンセルの案内を表示
      if (isAppStorePremium && context.mounted) {
        final understood = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('サブスクリプションについて'),
            content: const Text(
              'App Storeのサブスクリプションはアカウント削除後も自動的にはキャンセルされません。\n\n'
              '【iOSでのキャンセル手順】\n'
              '設定 → Apple ID → サブスクリプション → DARIAS → サブスクリプションをキャンセル\n\n'
              'アカウント削除前にキャンセルしましたか？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('戻る（キャンセルする）'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('削除を続ける'),
              ),
            ],
          ),
        );
        if (understood != true || !context.mounted) return;
      }

      final finalConfirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        final password = await _showPasswordDialog(context);
        if (password == null || !context.mounted) return;

        try {
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

          final credential = EmailAuthProvider.credential(
            email: user.email!,
            password: password,
          );
          await user.reauthenticateWithCredential(credential);

          // Cloud Function でFirestoreデータ全削除 + Google Playキャンセル
          // Auth削除より先に実行（Auth削除後はFirestoreにアクセスできなくなるため）
          final callable = FirebaseFunctions.instance.httpsCallable('deleteUserAccount');
          await callable.call();

          // SharedPreferencesのヒントキーを削除
          await HintService.clearAllForUser(user.uid);

          // Firestoreデータ削除完了後にAuth削除
          await user.delete();

          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('アカウントを削除しました'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } on FirebaseAuthException catch (e) {
          debugPrint('❌ アカウント削除 FirebaseAuthException: code=${e.code}, message=${e.message}');
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_getDeleteErrorMessage(e.code))),
            );
          }
        } on FirebaseFunctionsException catch (e) {
          debugPrint('❌ アカウント削除 FirebaseFunctionsException: code=${e.code}, message=${e.message}');
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('データ削除中にエラーが発生しました: ${e.message}')),
            );
          }
        } catch (e, st) {
          debugPrint('❌ アカウント削除エラー: $e\n$st');
          if (context.mounted) {
            Navigator.of(context).pop();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('パスワードを入力'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('セキュリティのため、パスワードを入力してください。'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'パスワード',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
      case 'invalid-credential': // Firebase Auth SDK 新バージョンでのエラーコード
        return 'パスワードが正しくありません';
      case 'requires-recent-login':
        return 'セキュリティのため、再度ログインしてください';
      case 'too-many-requests':
        return 'リクエストが多すぎます。しばらくしてからお試しください';
      case 'network-request-failed':
        return 'ネットワークエラーが発生しました。接続を確認してください';
      case 'user-not-found':
        return 'ユーザーが見つかりません';
      default:
        return 'エラーが発生しました ($code)';
    }
  }
}

/// プレミアムアップグレードカード
class _PremiumUpgradeCard extends StatelessWidget {
  final Color accentColor;
  final VoidCallback onTap;

  const _PremiumUpgradeCard({
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withValues(alpha: 0.05),
                accentColor.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // プレミアムアイコン
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.yellow, Colors.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'プレミアムにアップグレード',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '広告なし・無制限チャット・特別機能',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '月額980円',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 設定カード
/// ユーザー情報カード
class _UserInfoCard extends ConsumerWidget {
  final dynamic user; // UserModel?
  final String userId;

  const _UserInfoCard({required this.user, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = user?.name as String?;
    final email = user?.email as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            CharacterAvatarWidget(
              userId: userId,
              size: 44,
              fallbackText: '__icon_person__',
              fallbackBackgroundColor: AppColors.textPrimary.withValues(alpha: 0.08),
              fallbackTextColor: AppColors.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name?.isNotEmpty == true ? name! : '名前未設定',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;

  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: iconColor ?? AppColors.textSecondary),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textLight,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// SNS・サポートカード
class _SocialSupportCard extends StatelessWidget {
  final VoidCallback onInstagramTap;
  final VoidCallback onContactTap;

  const _SocialSupportCard({
    required this.onInstagramTap,
    required this.onContactTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            // Instagram
            GestureDetector(
              onTap: onInstagramTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.camera_alt,
                      color: Colors.purple,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '公式Instagram',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.open_in_new,
                      color: AppColors.textLight,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            Divider(
              height: 1,
              color: AppColors.textPrimary.withValues(alpha: 0.2),
            ),
            // お問い合わせ
            GestureDetector(
              onTap: onContactTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.mail,
                      color: Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'お問い合わせ',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 危険なアクションボタン（ログアウト・削除）
class _DangerButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _DangerButton({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
