import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/ad_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userDocProvider);
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DARIAS'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('エラー: $e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('ユーザー情報を取得中...'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ユーザー情報カード
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(
                                Icons.person,
                                size: 30,
                                color:
                                    Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.email,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: user.isPremium
                                          ? Colors.amber
                                          : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      user.isPremium ? 'Premium' : 'Free',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: user.isPremium
                                            ? Colors.black
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // メニューグリッド
                Text(
                  'メニュー',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.2,
                  children: [
                    _MenuCard(
                      icon: Icons.chat_bubble_outline,
                      title: 'チャット',
                      subtitle: 'キャラクターと会話',
                      color: Colors.blue,
                      onTap: () => context.go('/chat'),
                    ),
                    _MenuCard(
                      icon: Icons.psychology_outlined,
                      title: 'BIG5診断',
                      subtitle: '性格診断を受ける',
                      color: Colors.purple,
                      onTap: () => context.go('/big5'),
                    ),
                    _MenuCard(
                      icon: Icons.group_outlined,
                      title: '6人会議',
                      subtitle: 'AI会議シミュレーション',
                      color: Colors.orange,
                      onTap: () => context.go('/meeting'),
                    ),
                    _MenuCard(
                      icon: Icons.calendar_today_outlined,
                      title: 'カレンダー',
                      subtitle: 'スケジュール管理',
                      color: Colors.green,
                      onTap: () => context.go('/calendar'),
                    ),
                    _MenuCard(
                      icon: Icons.book_outlined,
                      title: '日記',
                      subtitle: '日々の記録',
                      color: Colors.pink,
                      onTap: () => context.go('/diary'),
                    ),
                    _MenuCard(
                      icon: Icons.check_circle_outline,
                      title: 'Todo',
                      subtitle: 'タスク管理',
                      color: Colors.teal,
                      onTap: () => context.go('/todo'),
                    ),
                    _MenuCard(
                      icon: Icons.note_outlined,
                      title: 'メモ',
                      subtitle: 'テキストメモ',
                      color: Colors.amber,
                      onTap: () => context.go('/memo'),
                    ),
                    _MenuCard(
                      icon: Icons.bar_chart_outlined,
                      title: '統計',
                      subtitle: '利用状況を確認',
                      color: Colors.indigo,
                      onTap: () => context.push('/statistics'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // キャラクター変更ボタン
                OutlinedButton.icon(
                  onPressed: () => context.go('/character-select'),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('キャラクターを変更'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),

                // バナー広告（プレミアムユーザーでない場合のみ）
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
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
