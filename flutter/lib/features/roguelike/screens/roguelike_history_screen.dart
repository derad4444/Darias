// features/roguelike/screens/roguelike_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/roguelike_datasource.dart';
import '../models/dungeon.dart';
import '../models/roguelike_info.dart';
import '../providers/roguelike_provider.dart';
import '../widgets/dungeon_theme.dart';
import '../widgets/roguelike_banner.dart';
import '../../../presentation/providers/auth_provider.dart';

/// 冒険の記録一覧画面（結果画面の「記録」ボタンから push 遷移）。
/// 保存済みの過去ラン（`roguelike_runs`）を新しい順に一覧表示する。
/// 戻る操作は push 元（結果画面）へ pop で戻る。
class RoguelikeHistoryScreen extends ConsumerWidget {
  const RoguelikeHistoryScreen({super.key});

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop(); // 結果画面へ戻る
    } else {
      context.go('/roguelike/result');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final runsAsync = ref.watch(roguelikeHistoryProvider(userId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: kRoguelikeBgGradient),
        child: SafeArea(
          child: Column(
            children: [
              const RoguelikeBanner(),
              // ヘッダー
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => _back(context),
                    ),
                    const Expanded(
                      child: Text('冒険の記録', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('これまでの冒険の記録（新しい順）', style: TextStyle(fontSize: 12, color: Colors.white70)),
                ),
              ),
              Expanded(
                child: runsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => const Center(
                    child: Text('記録の読み込みに失敗しました', style: TextStyle(color: Colors.white)),
                  ),
                  data: (runs) {
                    if (runs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'まだ冒険の記録がありません。\n冒険を終えるとここに記録されます。',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, height: 1.6),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      itemCount: runs.length,
                      itemBuilder: (context, i) => _RunCard(run: runs[i]),
                    );
                  },
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

/// 記録1件のカード。
class _RunCard extends StatelessWidget {
  final RoguelikeRunSummary run;
  const _RunCard({required this.run});

  /// 存在するダンジョンIDなら対応 Dungeon を返す（無ければ null）。
  Dungeon? get _dungeon {
    if (run.dungeonId.isEmpty) return null;
    for (final d in Dungeons.all) {
      if (d.id == run.dungeonId) return d;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final (resultLabel, resultColor) = _resultStyle(run.result);
    final elemInfo = ElementInfo.of(run.inferredElement);
    final dungeon = _dungeon;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kRoguelikeCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左：ボス（ダンジョン）アイコン
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: (dungeon != null ? dungeonColor(dungeon.id) : Colors.grey).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: dungeon != null
                ? enemyArt(id: dungeon.id, emoji: dungeon.emoji, size: 52)
                : const Text('🌀', style: TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 12),
          // 右：本文
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 結果バッジ
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: resultColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: resultColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(resultLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: resultColor)),
                    ),
                    const Spacer(),
                    if (run.createdAt != null)
                      Text(_formatDate(run.createdAt!), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                // 称号
                Text(
                  run.title.isNotEmpty ? run.title : '冒険者',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kRoguelikeInk),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (run.worry.isNotEmpty)
                      _MetaChip(emoji: '📖', text: run.worry),
                    if (run.inferredElement.isNotEmpty && run.inferredElement != '無')
                      _MetaChip(emoji: elemInfo.emoji, text: '${run.inferredElement}タイプ'),
                    if (run.topTrait.isNotEmpty)
                      _MetaChip(emoji: '✨', text: run.topTrait),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static (String, Color) _resultStyle(String result) {
    switch (result) {
      case 'clear':
        return ('克服！', const Color(0xFF2E9E6B));
      case 'retreat':
        return ('撤退', const Color(0xFF3B9CA8));
      case 'timeUp':
        return ('時間切れ', const Color(0xFFE08A2B));
      case 'failed':
        return ('失敗', const Color(0xFFD96666));
      default:
        return ('冒険終了', const Color(0xFFE08AAE));
    }
  }

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _MetaChip extends StatelessWidget {
  final String emoji;
  final String text;
  const _MetaChip({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }
}
