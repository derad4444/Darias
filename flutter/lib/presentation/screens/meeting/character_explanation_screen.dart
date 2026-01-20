import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// キャラクター説明画面
class CharacterExplanationScreen extends StatelessWidget {
  const CharacterExplanationScreen({super.key});

  static const List<_CharacterInfo> characters = [
    _CharacterInfo(
      id: 'original',
      name: '今の自分',
      icon: Icons.person,
      color: Colors.blue,
      description: '現在のあなたの考え方や価値観',
      traits: [
        '現実的な視点で物事を考える',
        '今の状況を踏まえた判断',
        '実際の経験に基づく意見',
        'バランスの取れた視点',
      ],
    ),
    _CharacterInfo(
      id: 'opposite',
      name: '真逆の自分',
      icon: Icons.swap_horiz,
      color: Colors.orange,
      description: 'あなたとは正反対の性格を持つ自分',
      traits: [
        '普段とは異なる視点を提供',
        '意外な発見をもたらす',
        '固定観念を打ち破る',
        '新しい可能性を示す',
      ],
    ),
    _CharacterInfo(
      id: 'ideal',
      name: '理想の自分',
      icon: Icons.star,
      color: Colors.purple,
      description: 'なりたい姿、目指している理想の自分',
      traits: [
        '長期的な視点を持つ',
        '理想の価値観で判断',
        '目標達成を重視',
        '成長を促す視点',
      ],
    ),
    _CharacterInfo(
      id: 'shadow',
      name: '本音の自分',
      icon: Icons.face,
      color: Colors.red,
      description: '普段は隠している本当の気持ち',
      traits: [
        '率直な感情を表現',
        '本心からの意見',
        '建前を排除した視点',
        '抑圧された欲求を代弁',
      ],
    ),
    _CharacterInfo(
      id: 'child',
      name: '子供の頃の自分',
      icon: Icons.child_care,
      color: Colors.green,
      description: '純粋で素直だった子供時代の自分',
      traits: [
        '純粋な感性で物事を見る',
        '素直な感情表現',
        '夢や希望を大切にする',
        'シンプルな幸せを追求',
      ],
    ),
    _CharacterInfo(
      id: 'wise',
      name: '未来の自分(70歳)',
      icon: Icons.elderly,
      color: Color(0xFF795548),
      description: '人生経験を積んだ未来の自分',
      traits: [
        '長い人生経験からの知恵',
        '俯瞰的な視点',
        '本当に大切なものを見抜く',
        '後悔しない選択を促す',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('自分会議の説明'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ヘッダー説明
          _HeaderSection(),
          const SizedBox(height: 24),

          // 各キャラクターの説明
          ...characters.map((char) => _CharacterCard(character: char)),

          // 補足説明
          const SizedBox(height: 24),
          _TipsSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _CharacterInfo {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String description;
  final List<String> traits;

  const _CharacterInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
    required this.traits,
  });
}

class _HeaderSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.groups,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          '6人の自分について',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'あなたのBIG5性格診断データを基に、\n6つの異なる自分が多角的に議論します',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final _CharacterInfo character;

  const _CharacterCard({required this.character});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: character.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    character.icon,
                    color: character.color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        character.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        character.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // 特徴
            ...character.traits.map((trait) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: character.color,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trait,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _TipsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb,
                color: Colors.amber.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                '会議のポイント',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BulletPoint(text: '今の自分と真逆の自分が異なる視点で議論'),
          _BulletPoint(text: '理想の自分が目標達成の視点を提供'),
          _BulletPoint(text: '本音の自分が率直な感情を表現'),
          _BulletPoint(text: '子供の頃の自分が純粋な視点を追加'),
          _BulletPoint(text: '未来の自分が長期的な視野で結論'),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;

  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: TextStyle(
              color: Colors.amber.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
