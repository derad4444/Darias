// features/roguelike/screens/roguelike_codex_screen.dart
//
// 敵図鑑。これまでの冒険で「出会った敵」（codex.enemies）を一覧する。
// 出会った敵は通常表示、未遭遇は「？？？」のグレー表示。
// 討伐回数・初回討伐ターンは未保存のため表示しない（出会った/ボスの克服のみ反映）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../models/dungeon.dart';
import '../models/enemy.dart';
import '../providers/roguelike_provider.dart';
import '../widgets/dungeon_theme.dart';
import '../widgets/roguelike_banner.dart';

enum _CodexTab { all, normal, boss }

class RoguelikeCodexScreen extends ConsumerStatefulWidget {
  const RoguelikeCodexScreen({super.key});

  @override
  ConsumerState<RoguelikeCodexScreen> createState() => _RoguelikeCodexScreenState();
}

class _RoguelikeCodexScreenState extends ConsumerState<RoguelikeCodexScreen> {
  _CodexTab _tab = _CodexTab.all;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final codex = ref.watch(codexProvider(userId)).valueOrNull;
    final cleared = ref.watch(clearedDungeonsProvider(userId)).valueOrNull ?? const <String>{};
    final seen = codex?.enemies ?? const <String>{};

    final all = Dungeons.allEnemies;
    final bosses = all.where((e) => e.isBoss).toList();
    final normals = all.where((e) => !e.isBoss).toList();

    int seenCount(List<Enemy> list) => list.where((e) => seen.contains(e.id)).length;

    final list = switch (_tab) {
      _CodexTab.all => all,
      _CodexTab.normal => normals,
      _CodexTab.boss => bosses,
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: kRoguelikeBgGradient),
        child: SafeArea(
        child: Column(
          children: [
            const RoguelikeBanner(),
            // ヘッダー（戻る＋タイトル。ステータスバーは出さない）
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🌿 敵図鑑', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kRoguelikePink.withValues(alpha: 0.95))),
                      const Text('これまでに出会った敵の記録です', style: TextStyle(fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // タブ
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _TabChip(label: 'すべて', count: seenCount(all), total: all.length, selected: _tab == _CodexTab.all, onTap: () => setState(() => _tab = _CodexTab.all)),
                  const SizedBox(width: 8),
                  _TabChip(label: '通常の敵', count: seenCount(normals), total: normals.length, selected: _tab == _CodexTab.normal, onTap: () => setState(() => _tab = _CodexTab.normal)),
                  const SizedBox(width: 8),
                  _TabChip(label: 'ボス', count: seenCount(bosses), total: bosses.length, selected: _tab == _CodexTab.boss, onTap: () => setState(() => _tab = _CodexTab.boss)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('※出会った敵は色がつきます', style: TextStyle(fontSize: 11, color: Colors.white70)),
              ),
            ),
            // 一覧
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                children: [
                  // 図鑑コンプリート達成度（一覧の一番上に表示）
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CompleteCard(seen: seenCount(all), total: all.length),
                  ),
                  ...list.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _EnemyCard(enemy: e, seen: seen.contains(e.id), defeated: e.isBoss && cleared.contains(e.id)),
                      )),
                ],
              ),
            ),
            const RoguelikeBanner(bottom: true),
          ],
        ),
        ),
      ),
    );
  }
}

/// 上部タブ（すべて / 通常の敵 / ボス）。
class _TabChip extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.count, required this.total, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? kRoguelikePink.withValues(alpha: 0.12) : kRoguelikeCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? kRoguelikePink.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: selected ? kRoguelikePink : kRoguelikeInk)),
              const SizedBox(height: 2),
              Text('$count / $total', style: TextStyle(fontSize: 11, color: selected ? kRoguelikePink : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 敵1体のカード（全て同サイズ）。
class _EnemyCard extends StatelessWidget {
  final Enemy enemy;
  final bool seen;
  final bool defeated;
  const _EnemyCard({required this.enemy, required this.seen, required this.defeated});

  @override
  Widget build(BuildContext context) {
    final color = seen ? enemyColor(enemy) : Colors.grey;
    final typeLabel = enemy.isBoss ? 'ボス' : '通常の敵';

    final card = Container(
      decoration: BoxDecoration(
        color: kRoguelikeCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // アート
          Container(
            width: 72,
            height: 72,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.05)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: enemyArt(id: enemy.id, emoji: enemyEmoji(enemy), size: 72, seen: seen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Badge(typeLabel, color),
                    if (defeated) ...[
                      const SizedBox(width: 6),
                      _Badge('⚔️ 討伐済み', const Color(0xFF2E9E6B)),
                    ],
                    if (seen) ...[
                      const Spacer(),
                      Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  seen ? enemy.name : '？？？',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kRoguelikeInk),
                ),
                const SizedBox(height: 4),
                Text(
                  seen ? enemy.description : 'まだ出会っていません。\nこの敵に出会うと図鑑が解放されます。',
                  style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.favorite, size: 14, color: seen ? Colors.redAccent : Colors.grey),
                    const SizedBox(width: 4),
                    Text('HP ${seen ? enemy.maxHp : '???'}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: seen ? kRoguelikeInk : Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!seen) return card;
    // 出会った敵はタップで詳細画面へ。
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/roguelike/codex/enemy', extra: enemy),
        child: card,
      ),
    );
  }
}

/// 図鑑コンプリート達成度。
class _CompleteCard extends StatelessWidget {
  final int seen;
  final int total;
  const _CompleteCard({required this.seen, required this.total});

  @override
  Widget build(BuildContext context) {
    final complete = total > 0 && seen >= total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('図鑑コンプリート', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFB8860B))),
                const SizedBox(height: 2),
                Text(complete ? '図鑑が完成しました！おめでとうございます🎉' : '少しずつ、図鑑の完成を目指しましょう。', style: TextStyle(fontSize: 11, color: Colors.brown.shade400)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Text('$seen / $total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFB8860B))),
              if (complete)
                const Text('COMPLETE!', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC99A2E))),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

