import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/subscription_provider.dart';

/// プレミアム機能の種類
enum PremiumFeature {
  adFree,
  unlimitedHistory,
  latestAIModel,
  detailedAnalysis;

  String get title {
    switch (this) {
      case PremiumFeature.adFree:
        return '広告非表示';
      case PremiumFeature.unlimitedHistory:
        return 'チャット履歴';
      case PremiumFeature.latestAIModel:
        return 'AIモデル';
      case PremiumFeature.detailedAnalysis:
        return 'キャラクター分析';
    }
  }

  String get description {
    switch (this) {
      case PremiumFeature.adFree:
        return 'バナー広告とリワード広告（動画広告）が完全に非表示になり、快適にご利用いただけます。';
      case PremiumFeature.unlimitedHistory:
        return '無料版では最新50メッセージまでですが、プレミアムなら全てのチャット履歴を無制限に保存・閲覧できます。';
      case PremiumFeature.latestAIModel:
        return '最新のAIモデルを使用してより自然で高品質な会話をお楽しみいただけます。';
      case PremiumFeature.detailedAnalysis:
        return '基本分析に加えて、より高度で詳細なキャラクター解析機能をご利用いただけます。';
    }
  }

  IconData get icon {
    switch (this) {
      case PremiumFeature.adFree:
        return Icons.block;
      case PremiumFeature.unlimitedHistory:
        return Icons.history;
      case PremiumFeature.latestAIModel:
        return Icons.auto_awesome;
      case PremiumFeature.detailedAnalysis:
        return Icons.person_add;
    }
  }

  String get freeValue {
    switch (this) {
      case PremiumFeature.adFree:
        return 'バナー・リワード広告';
      case PremiumFeature.unlimitedHistory:
        return '50メッセージまで';
      case PremiumFeature.latestAIModel:
        return '標準モデル';
      case PremiumFeature.detailedAnalysis:
        return '基本分析';
    }
  }

  String get premiumValue {
    switch (this) {
      case PremiumFeature.adFree:
        return '完全非表示';
      case PremiumFeature.unlimitedHistory:
        return '無制限保存';
      case PremiumFeature.latestAIModel:
        return '最新モデル';
      case PremiumFeature.detailedAnalysis:
        return 'より高度な解析';
    }
  }
}

/// プレミアムアップグレード画面
class PremiumUpgradeScreen extends ConsumerStatefulWidget {
  const PremiumUpgradeScreen({super.key});

  @override
  ConsumerState<PremiumUpgradeScreen> createState() =>
      _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends ConsumerState<PremiumUpgradeScreen> {
  @override
  void initState() {
    super.initState();
    // 商品情報を読み込み
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionControllerProvider.notifier).reloadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionState = ref.watch(subscriptionControllerProvider);
    final monthlyProduct = ref.watch(monthlyProductProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surface.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ヘッダー
                _buildHeader(context),
                const SizedBox(height: 24),

                // 機能比較セクション
                _buildFeatureComparisonSection(context),
                const SizedBox(height: 24),

                // 料金プランセクション
                _buildPricingSection(context, monthlyProduct),
                const SizedBox(height: 24),

                // 購入セクション
                _buildPurchaseSection(
                  context,
                  subscriptionState,
                  monthlyProduct,
                ),
                const SizedBox(height: 24),

                // 法的情報セクション
                _buildLegalSection(context),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ヘッダーセクション
  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // 閉じるボタン
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),

        // クラウンアイコン
        Icon(
          Icons.workspace_premium,
          size: 60,
          color: Colors.amber,
        ),
        const SizedBox(height: 16),

        // タイトル
        Text(
          'プレミアムにアップグレード',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),

        // サブタイトル
        Text(
          '広告なしで快適なキャラクター体験を',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.8),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 機能比較セクション
  Widget _buildFeatureComparisonSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '機能比較',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        ...PremiumFeature.values.map(
          (feature) => _buildFeatureRow(context, feature),
        ),
      ],
    );
  }

  /// 機能行
  Widget _buildFeatureRow(BuildContext context, PremiumFeature feature) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // アイコン
          Icon(
            feature.icon,
            color: colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),

          // 機能名
          Expanded(
            child: Text(
              feature.title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),

          // 無料プラン
          SizedBox(
            width: 70,
            child: Column(
              children: [
                Text(
                  '無料',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                Text(
                  feature.freeValue,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.red,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // プレミアムプラン
          SizedBox(
            width: 80,
            child: Column(
              children: [
                Text(
                  'プレミアム',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                Text(
                  feature.premiumValue,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.green,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 料金プランセクション
  Widget _buildPricingSection(
    BuildContext context,
    dynamic monthlyProduct,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '料金プラン',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.primary,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                monthlyProduct?.price ?? '¥980',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ 月',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 購入セクション
  Widget _buildPurchaseSection(
    BuildContext context,
    SubscriptionState state,
    dynamic monthlyProduct,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ローディング中
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        // 購入ボタン
        else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: monthlyProduct != null
                  ? () async {
                      final success = await ref
                          .read(subscriptionControllerProvider.notifier)
                          .purchaseMonthly();
                      if (success && mounted) {
                        // 購入成功後の処理はコールバックで行われる
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.workspace_premium),
                  const SizedBox(width: 8),
                  const Text(
                    'プレミアムを開始',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 復元ボタン
          TextButton(
            onPressed: () {
              ref
                  .read(subscriptionControllerProvider.notifier)
                  .restorePurchases();
            },
            child: Text(
              '購入を復元',
              style: TextStyle(color: colorScheme.primary),
            ),
          ),
        ],

        // エラーメッセージ
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              state.error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
              textAlign: TextAlign.center,
            ),
          ),

        // 購入成功メッセージ
        if (state.purchaseSuccess)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '購入が完了しました！',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  /// 法的情報セクション
  Widget _buildLegalSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // 注意事項
        Text(
          '• 購入確定時にApple ID/Google Playアカウントに課金されます\n'
          '• 設定からサブスクリプションを管理できます',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // 利用規約・プライバシーポリシー
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _openTermsOfService,
              child: Text(
                '利用規約',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: _openPrivacyPolicy,
              child: Text(
                'プライバシーポリシー',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 利用規約を開く
  Future<void> _openTermsOfService() async {
    final uri = Uri.parse('https://example.com/terms');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// プライバシーポリシーを開く
  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse('https://example.com/privacy');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
