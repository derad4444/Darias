import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/ad_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';

/// プロフィール編集画面
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _nicknameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    // 初期値設定
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userDocProvider).valueOrNull;
      if (user != null) {
        // ニックネームがあれば設定（現状はemailの@より前を使用）
        final emailPrefix = user.email.split('@').first;
        _nicknameController.text = emailPrefix;
      }
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final userAsync = ref.watch(userDocProvider);
    final isPremium = ref.watch(effectiveIsPremiumProvider);
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('プロフィール', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: userAsync.when(
            loading: () => Center(child: CircularProgressIndicator(color: accentColor)),
            error: (e, st) => Center(child: Text('エラー: $e')),
            data: (user) {
              if (user == null) {
                return Center(
                  child: Text(
                    'ユーザー情報が見つかりません',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 上部バナー広告
                    if (shouldShowBannerAd) ...[
                      const BannerAdContainer(),
                      const SizedBox(height: 16),
                    ],

                    // プロフィールアバター
                    _buildAvatarSection(context, accentColor, isPremium),
                    const SizedBox(height: 24),

                    // アカウント情報
                    _buildInfoCard(
                      context,
                      accentColor,
                      title: 'アカウント情報',
                      children: [
                        _InfoRow(
                          icon: Icons.email,
                          label: 'メールアドレス',
                          value: user.email,
                          accentColor: accentColor,
                        ),
                        Divider(height: 24, color: AppColors.textLight.withValues(alpha: 0.3)),
                        _InfoRow(
                          icon: Icons.badge,
                          label: '会員ステータス',
                          value: isPremium ? 'プレミアム会員' : '無料会員',
                          valueColor: isPremium ? Colors.amber : null,
                          accentColor: accentColor,
                        ),
                        Divider(height: 24, color: AppColors.textLight.withValues(alpha: 0.3)),
                        _InfoRow(
                          icon: Icons.calendar_today,
                          label: '登録日',
                          value: _formatDate(user.createdAt),
                          accentColor: accentColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ニックネーム設定
                    _buildInfoCard(
                      context,
                      accentColor,
                      title: '表示名',
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _nicknameController,
                            decoration: InputDecoration(
                              labelText: 'ニックネーム',
                              hintText: 'アプリ内での表示名を入力',
                              hintStyle: TextStyle(color: AppColors.textLight),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(Icons.person_outline, color: accentColor),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'この名前はアプリ内で表示されます',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 選択中のキャラクター
                    if (user.characterId != null)
                      _buildInfoCard(
                        context,
                        accentColor,
                        title: 'パートナー',
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: accentColor.withValues(alpha: 0.1),
                                child: Icon(
                                  Icons.smart_toy,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getCharacterName(user.characterId!),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '選択中のキャラクター',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.go('/character-select'),
                                child: Text('変更', style: TextStyle(color: accentColor)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),

                    // 保存ボタン
                    GestureDetector(
                      onTap: _isSaving ? null : _saveProfile,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accentColor, accentColor.withValues(alpha: 0.8)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isSaving)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            else
                              const Icon(Icons.save, color: Colors.white),
                            const SizedBox(width: 8),
                            const Text(
                              '保存',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 下部バナー広告
                    if (shouldShowBannerAd) ...[
                      const SizedBox(height: 24),
                      const BannerAdContainer(),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(BuildContext context, Color accentColor, bool isPremium) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: accentColor.withValues(alpha: 0.1),
                child: Icon(
                  Icons.person,
                  size: 50,
                  color: accentColor,
                ),
              ),
              if (isPremium)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('プロフィール画像の変更機能は準備中です')),
              );
            },
            icon: Icon(Icons.camera_alt, size: 18, color: accentColor),
            label: Text('写真を変更', style: TextStyle(color: accentColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    Color accentColor, {
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  String _getCharacterName(String characterId) {
    const characterNames = {
      'character_1': 'キャラクター1',
      'character_2': 'キャラクター2',
      'character_3': 'キャラクター3',
    };
    return characterNames[characterId] ?? characterId;
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      // TODO: プロフィール保存処理を実装
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プロフィールを保存しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color accentColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: accentColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: valueColor != null ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
