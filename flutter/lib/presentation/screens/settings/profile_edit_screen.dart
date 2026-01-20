import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
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
    final userAsync = ref.watch(userDocProvider);
    final isPremium = ref.watch(effectiveIsPremiumProvider);
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('プロフィール'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('エラー: $e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('ユーザー情報が見つかりません'));
          }

          return SingleChildScrollView(
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
                _buildAvatarSection(context, colorScheme, isPremium),
                const SizedBox(height: 24),

                // アカウント情報
                _buildInfoCard(
                  context,
                  colorScheme,
                  title: 'アカウント情報',
                  children: [
                    _InfoRow(
                      icon: Icons.email,
                      label: 'メールアドレス',
                      value: user.email,
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.badge,
                      label: '会員ステータス',
                      value: isPremium ? 'プレミアム会員' : '無料会員',
                      valueColor: isPremium ? Colors.amber : null,
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.calendar_today,
                      label: '登録日',
                      value: _formatDate(user.createdAt),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ニックネーム設定
                _buildInfoCard(
                  context,
                  colorScheme,
                  title: '表示名',
                  children: [
                    TextField(
                      controller: _nicknameController,
                      decoration: InputDecoration(
                        labelText: 'ニックネーム',
                        hintText: 'アプリ内での表示名を入力',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'この名前はアプリ内で表示されます',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 選択中のキャラクター
                if (user.characterId != null)
                  _buildInfoCard(
                    context,
                    colorScheme,
                    title: 'パートナー',
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(
                            Icons.smart_toy,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(_getCharacterName(user.characterId!)),
                        subtitle: const Text('選択中のキャラクター'),
                        trailing: TextButton(
                          onPressed: () => context.go('/character-select'),
                          child: const Text('変更'),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),

                // 保存ボタン
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: const Text('保存'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
    );
  }

  Widget _buildAvatarSection(
    BuildContext context,
    ColorScheme colorScheme,
    bool isPremium,
  ) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.person,
                  size: 50,
                  color: colorScheme.onPrimaryContainer,
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
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('写真を変更'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    ColorScheme colorScheme, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  String _getCharacterName(String characterId) {
    // キャラクターIDからキャラクター名を取得
    // 実際にはキャラクターマスターデータから取得する
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

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: valueColor,
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
