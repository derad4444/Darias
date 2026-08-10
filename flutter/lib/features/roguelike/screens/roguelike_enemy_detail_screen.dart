// features/roguelike/screens/roguelike_enemy_detail_screen.dart
//
// 敵図鑑の詳細画面。出会った敵をタップして開く。
// ボス（踏破済み）の場合は「踏破時の解析結果」（最新のクリアラン）を表示する。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../models/enemy.dart';
import '../models/roguelike_info.dart';
import '../providers/roguelike_provider.dart';
import '../widgets/dungeon_theme.dart';

class RoguelikeEnemyDetailScreen extends ConsumerWidget {
  final Enemy enemy;
  const RoguelikeEnemyDetailScreen({super.key, required this.enemy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final cleared = ref.watch(clearedDungeonsProvider(userId)).valueOrNull ?? const <String>{};
    final defeated = enemy.isBoss && cleared.contains(enemy.id);
    final color = enemyColor(enemy);

    return Scaffold(
      backgroundColor: kRoguelikeBg,
      appBar: AppBar(
        backgroundColor: kRoguelikeBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(enemy.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: kRoguelikeBgGradient),
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // アート＋種別
          Center(
            child: Container(
              width: 120,
              height: 120,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: enemyArt(id: enemy.id, emoji: enemyEmoji(enemy), size: 120),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Wrap(
              spacing: 6,
              children: [
                _Badge(enemy.isBoss ? 'ボス' : '通常の敵', color),
                if (defeated) _Badge('⚔️ 討伐済み', const Color(0xFF2E9E6B)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text(enemy.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white))),
          const SizedBox(height: 8),

          // 基本情報カード
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(enemy.description, style: const TextStyle(fontSize: 13, height: 1.6)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.favorite, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Text('HP ${enemy.maxHp}', style: const TextStyle(fontWeight: FontWeight.bold, color: kRoguelikeInk)),
                  ],
                ),
                if (enemy.nextAction.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('戦い方  ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Expanded(child: Text(enemy.nextAction, style: const TextStyle(fontSize: 12, color: Colors.orange))),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 敵の特徴
          _buildTraits(),

          // ドロップ報酬
          _buildDrops(),

          // 踏破時の解析結果（ボスのみ）
          if (enemy.isBoss) ...[
            const SizedBox(height: 16),
            const Text('踏破時の解析結果', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            const SizedBox(height: 8),
            if (!defeated)
              _Card(
                child: Text(
                  'まだ踏破していません。\nこの悩みを克服すると、その時の解析結果（行動特性・推定元素・称号）が見られます。',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
                ),
              )
            else
              _AnalysisSection(userId: userId, dungeonId: enemy.id),
          ],
        ],
        ),
      ),
    );
  }

  Widget _buildTraits() {
    final traits = enemyTraits(enemy);
    if (traits.isEmpty) return const SizedBox.shrink();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('敵の特徴', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kRoguelikeInk)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: traits.map((t) => _Badge(t, const Color(0xFF8E7CC3))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDrops() {
    final drops = enemyDrops(enemy);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _Card(
        child: Row(
          children: [
            Text(enemy.isBoss ? '報酬' : 'ドロップ報酬', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kRoguelikeInk)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                drops.isEmpty ? (enemy.isBoss ? '克服そのものが報酬' : 'なし') : drops.join('　'),
                style: const TextStyle(fontSize: 13, color: kRoguelikeInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 踏破時の解析結果（最新クリアラン）を表示。
class _AnalysisSection extends ConsumerWidget {
  final String userId;
  final String dungeonId;
  const _AnalysisSection({required this.userId, required this.dungeonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runAsync = ref.watch(latestClearRunProvider((userId, dungeonId)));
    return runAsync.when(
      loading: () => const _Card(child: Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))),
      error: (_, __) => const _Card(child: Text('解析結果の読み込みに失敗しました', style: TextStyle(fontSize: 13, color: Colors.grey))),
      data: (run) {
        if (run == null) {
          return const _Card(child: Text('解析結果が見つかりませんでした', style: TextStyle(fontSize: 13, color: Colors.grey)));
        }
        final el = ElementInfo.of(run.inferredElement);
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 称号・元素
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('称号', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(run.title.isEmpty ? '—' : run.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kRoguelikePink)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('推定元素', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text('${el.emoji} ${run.inferredElement}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kRoguelikeInk)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // レーダー
              const Text('行動特性グラフ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kRoguelikeInk)),
              const SizedBox(height: 8),
              SizedBox(height: 240, child: _radar(run.traits)),
              const SizedBox(height: 14),
              // 解析コメント（グラフだけでなく文章での振り返り）
              _comment(run.traits, run.inferredElement, el),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Badge(_resultLabel(run.result), const Color(0xFF8E7CC3)),
                  const Spacer(),
                  if (run.createdAt != null)
                    Text(DateFormat('yyyy/M/d 踏破').format(run.createdAt!), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _radar(Map<String, int> traits) {
    if (traits.isEmpty) {
      return const Center(child: Text('記録がありません', style: TextStyle(fontSize: 12, color: Colors.grey)));
    }
    final keys = traits.keys.toList();
    final values = traits.values.toList();
    final maxV = values.fold(0, (m, v) => v > m ? v : m);
    if (maxV == 0) {
      return const Center(child: Text('記録がありません', style: TextStyle(fontSize: 12, color: Colors.grey)));
    }
    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        dataSets: [
          RadarDataSet(
            dataEntries: values.map((v) => RadarEntry(value: v.toDouble())).toList(),
            fillColor: kRoguelikePink.withValues(alpha: 0.25),
            borderColor: kRoguelikePink,
            borderWidth: 2,
            entryRadius: 2,
          ),
        ],
        getTitle: (index, angle) => RadarChartTitle(text: keys[index]),
        titleTextStyle: const TextStyle(fontSize: 10, color: Colors.black87),
        titlePositionPercentageOffset: 0.12,
        tickCount: 4,
        ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 8),
        tickBorderData: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        gridBorderData: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        radarBorderData: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
      ),
    );
  }

  String _resultLabel(String result) => switch (result) {
        'clear' => '心の迷宮を踏破！',
        'retreat' => '迷宮から撤退',
        'timeUp' => '時間切れ帰還',
        'failed' => '冒険失敗',
        _ => result,
      };

  // 保存済みrunの特性マップから、上位（値>0・降順）の特性を返す。
  List<MapEntry<String, int>> _sortedTraits(Map<String, int> traits) {
    final list = traits.entries.where((e) => e.value > 0).toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  // 踏破＋上位特性の要約文（踏破済みのみ表示されるため踏破前提）。
  String _summaryText(List<MapEntry<String, int>> top) {
    if (top.isEmpty) {
      return 'この悩みを乗り越えました。今回は選択の記録が少なめでした。';
    }
    final t1 = top[0].key;
    final t2 = top.length > 1 ? top[1].key : null;
    final traitText = t2 != null ? '$t1や$t2' : t1;
    return '最後まで諦めず、この悩みを乗り越えました。\n$traitTextが光る冒険でした。';
  }

  // 解析コメント本体（要約＋目立った力の上位3件＋推定元素の一言）。
  Widget _comment(Map<String, int> traits, String inferredElement, ElementInfo el) {
    final top = _sortedTraits(traits);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('💬 ', style: TextStyle(fontSize: 14)),
            Text('解析コメント', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kRoguelikeInk)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kRoguelikePink.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kRoguelikePink.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_summaryText(top), style: const TextStyle(fontSize: 13, height: 1.6, color: kRoguelikeInk)),
              if (top.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('目立った力', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 4),
                ...top.take(3).map((e) {
                  final info = TraitInfo.of(e.key);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('${info.emoji} ${e.key} — ${info.description}',
                        style: const TextStyle(fontSize: 12, height: 1.4, color: kRoguelikeInk)),
                  );
                }),
              ],
              if (inferredElement != '無' && el.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('${el.emoji} ${el.description}',
                    style: const TextStyle(fontSize: 12, height: 1.5, color: kRoguelikeInk)),
              ],
              // 踏破時の傾向を日常へ橋渡しする文。結果画面と同じ文面を使い、
              // あとから見返しても「で、自分はどうすればいいのか」が分かるようにする。
              if (top.isNotEmpty && TraitAdvice.of(top.first.key) != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Text('🌱 ', style: TextStyle(fontSize: 13)),
                    Text('日常へのヒント',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(TraitAdvice.messageFor(top.first.key),
                    style: const TextStyle(fontSize: 12, height: 1.6, color: kRoguelikeInk)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kRoguelikeCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kRoguelikePink.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: child,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
