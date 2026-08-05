// features/roguelike/screens/roguelike_home_screen.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/character_provider.dart';
import '../../../presentation/providers/ad_provider.dart';
import '../../../presentation/providers/subscription_provider.dart' show effectiveIsPremiumProvider;
import '../../../presentation/widgets/character/element_effect_widget.dart' show characterGrowthAssetPath;
import '../data/roguelike_datasource.dart';
import '../models/game_state.dart';
import '../models/dungeon.dart';
import '../providers/roguelike_provider.dart';
import '../widgets/dungeon_theme.dart';
import '../widgets/roguelike_banner.dart';

const _kPink = kRoguelikePink;
const _kInk = kRoguelikeInk;

/// 全ダンジョン共通のマップ層数（GameState.mapLayerCount と一致）。
const _kLayerCount = GameState.mapLayerCount;

/// ダンジョンの本日の挑戦可否（スタミナ）。
/// playable=挑戦可（基本1回 or プレミアム）/ adNeeded=広告で+1回可 / exhausted=回復待ち。
enum StaminaMode { playable, adNeeded, exhausted }

class RoguelikeHomeScreen extends ConsumerWidget {
  const RoguelikeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider) ?? '';
    // 自分のキャラクターなので details/current を購読する。
    // userCharacterDetailsProvider は keepAlive 付きの一度きり取得（フレンド表示用）で、
    // 性格タイプが変わってもアプリを再起動するまで古い元素のままになる。
    // ここで渡す element は startGame() を通じて戦闘の元素相性にも使われる。
    final characterDetailsAsync = ref.watch(characterDetailsProvider);
    final signalCount = ref.watch(signalCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: kRoguelikeBgGradient),
        child: SafeArea(
        child: Column(
          children: [
            const RoguelikeBanner(),
            Expanded(
              child: characterDetailsAsync.when(
                data: (detail) {
                  if (detail == null) {
                    return const Center(child: Text('キャラクターデータが見つかりません'));
                  }
                  final stage = GrowthStageExt.fromSignalCount(signalCount);
                  final element = detail.element ?? '無';
                  final name = detail.typeName ?? 'キャラクター';
                  final avatarPath = characterGrowthAssetPath(
                    signalCount: signalCount,
                    element: detail.element,
                    gender: detail.gender,
                  );
                  return _HomeBody(stage: stage, element: element, characterName: name, avatarPath: avatarPath, userId: userId, ref: ref);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('データの読み込みに失敗しました')),
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

class _HomeBody extends StatelessWidget {
  final GrowthStage stage;
  final String element;
  final String characterName;
  final String avatarPath;
  final String userId;
  final WidgetRef ref;

  const _HomeBody({
    required this.stage,
    required this.element,
    required this.characterName,
    required this.avatarPath,
    required this.userId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final cleared = ref.watch(clearedDungeonsProvider(userId)).valueOrNull ?? const <String>{};
    final clearedCount = Dungeons.worries.where((d) => cleared.contains(d.id)).length;
    final total = Dungeons.worries.length;

    // スタミナ（無料は基本1回＋広告で+1回・プレミアム無制限）。
    // 回復は「基本プレイから24時間経過」で判定する。
    final premium = ref.watch(effectiveIsPremiumProvider);
    final stamina = ref.watch(roguelikeStaminaProvider(userId)).valueOrNull ?? const RoguelikeStamina();
    ref.watch(adControllerProvider); // リワード広告を事前ロード
    final now = DateTime.now();
    final baseRecovered = stamina.basePlayAt == null || now.difference(stamina.basePlayAt!).inMinutes >= 24 * 60;
    final baseUsed = !premium && !baseRecovered;
    final adUsed = !premium && !baseRecovered && stamina.adPlayUsed;
    final mode = (premium || !baseUsed)
        ? StaminaMode.playable
        : (!adUsed ? StaminaMode.adNeeded : StaminaMode.exhausted);
    // 回復ゲージ（基本プレイから24時間で満タン）と残り時間。
    final elapsedMin = stamina.basePlayAt == null ? (24 * 60) : now.difference(stamina.basePlayAt!).inMinutes;
    final recoveredFrac =
        (premium || mode == StaminaMode.playable) ? 1.0 : (elapsedMin / (24 * 60)).clamp(0.0, 1.0);
    final remainingMin = (24 * 60 - elapsedMin).clamp(0, 24 * 60);
    final hoursLeft = (remainingMin / 60).ceil().clamp(1, 24);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー（マスコット＋見出し＋敵図鑑ボタン）
          _Header(onCodex: () => context.push('/roguelike/codex')),
          const SizedBox(height: 16),
          // スタミナ（本日の挑戦状況）を「冒険の準備をしよう」ヘッダーの下に表示。
          _StaminaBanner(premium: premium, mode: mode, value: recoveredFrac, hoursLeft: hoursLeft),
          const SizedBox(height: 16),

          // 冒険の準備（冒険者情報）
          _PrepCard(characterName: characterName, stage: stage, avatarPath: avatarPath),
          const SizedBox(height: 20),

          // ダンジョン選択
          const Row(
            children: [
              Text('🌱 ', style: TextStyle(fontSize: 16)),
              Text('ダンジョンを選択', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 4),
          Text('克服 $clearedCount / $total', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 12),

          ...Dungeons.all.map((d) {
            final isCleared = cleared.contains(d.id);
            final locked = d.isFinale && !Dungeons.finaleUnlocked(cleared);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DungeonCard(
                dungeon: d,
                cleared: isCleared,
                locked: locked,
                clearedCount: clearedCount,
                total: total,
                staminaMode: mode,
                onStart: (locked || mode == StaminaMode.exhausted)
                    ? null
                    : () async {
                        await _startDungeon(
                          context,
                          d,
                          viaAd: mode == StaminaMode.adNeeded,
                          premium: premium,
                        );
                      },
              ),
            );
          }),
        ],
      ),
    );
  }

  /// ダンジョンを開始する。無料ユーザーはスタミナを消費（広告経由は動画視聴後）。
  Future<void> _startDungeon(BuildContext context, Dungeon d,
      {required bool viaAd, required bool premium}) async {
    // 広告経由（本日ぶん消費後の+1回）はリワード動画を視聴してから。
    if (viaAd && !premium && !kIsWeb) {
      try {
        await ref.read(rewardedAdManagerProvider).showAndAwaitReward();
      } catch (_) {}
    }
    // 無料ユーザーは消費を記録。基本1回は時刻を更新（24時間の起点）、広告+1回は基本時刻を維持。
    if (!premium) {
      final st = ref.read(roguelikeStaminaProvider(userId)).valueOrNull ?? const RoguelikeStamina();
      await ref.read(roguelikeDatasourceProvider).setStamina(
            userId: userId,
            stamina: viaAd
                ? RoguelikeStamina(basePlayAt: st.basePlayAt, adPlayUsed: true)
                : RoguelikeStamina(basePlayAt: DateTime.now(), adPlayUsed: false),
          );
    }
    ref.read(roguelikeProvider.notifier).startGame(
          stage: stage,
          element: element,
          characterName: characterName,
          dungeon: d,
        );
    if (context.mounted) context.go('/roguelike/game');
  }
}

/// マスコット＋見出し＋敵図鑑ボタン（アイコンのみ）。
class _Header extends StatelessWidget {
  final VoidCallback onCodex;
  const _Header({required this.onCodex});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('👻', style: TextStyle(fontSize: 40)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '冒険の準備をしよう！',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kPink.withValues(alpha: 0.95)),
              ),
              const SizedBox(height: 2),
              const Text('ダンジョンを選んで、心の迷宮へ出発しよう', style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // 敵図鑑（アイコンのみ・タイトル横）
        Tooltip(
          message: '敵図鑑',
          child: Material(
            color: _kPink.withValues(alpha: 0.10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: _kPink.withValues(alpha: 0.35)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onCodex,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.menu_book_outlined, size: 22, color: _kPink),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 冒険の準備カード（冒険者名・成長段階）。名前は省略せず全表示する。
class _PrepCard extends StatelessWidget {
  final String characterName;
  final GrowthStage stage;
  final String avatarPath;
  const _PrepCard({required this.characterName, required this.stage, required this.avatarPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kRoguelikeCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kPink.withValues(alpha: 0.18)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🌱 ', style: TextStyle(fontSize: 15)),
              Text('冒険の準備', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _kInk)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // キャラクター画像（本編アバター）
              ClipOval(
                child: Container(
                  width: 72,
                  height: 72,
                  color: _kPink.withValues(alpha: 0.06),
                  child: Image.asset(avatarPath, fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Center(child: Text('🧑', style: TextStyle(fontSize: 40)))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _InfoRow(label: '冒険者', value: characterName),
                    const SizedBox(height: 8),
                    _InfoRow(label: '成長段階', value: stage.label),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ラベル＋値の横並び行。値は省略せず折り返す。
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: _kPink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPink.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 76, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _kInk)),
          ),
        ],
      ),
    );
  }
}

/// 画像風ダンジョンカード。悩み・克服状況・分岐マップの層数を表示し、難易度・報酬・推奨Lvは出さない。
class _DungeonCard extends StatelessWidget {
  final Dungeon dungeon;
  final bool cleared;
  final bool locked;
  final int clearedCount;
  final int total;
  final VoidCallback? onStart;
  final StaminaMode staminaMode;

  const _DungeonCard({
    required this.dungeon,
    required this.cleared,
    required this.locked,
    required this.clearedCount,
    required this.total,
    required this.onStart,
    required this.staminaMode,
  });

  @override
  Widget build(BuildContext context) {
    final color = dungeonColor(dungeon.id);

    return Opacity(
      opacity: locked ? 0.7 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: kRoguelikeCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左：キャラクター画像エリア
            _DungeonArt(id: dungeon.id, emoji: dungeon.emoji, color: color, locked: locked),
            const SizedBox(width: 12),
            // 右：情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          dungeon.isFinale ? '【最終】${dungeon.worry}' : dungeon.worry,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _kInk),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(dungeon.emoji, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  if (cleared) ...[
                    const SizedBox(height: 6),
                    _Badge('克服済み ✓', const Color(0xFF2E9E6B)),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    dungeon.tagline,
                    style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  if (locked)
                    _UnlockRow(clearedCount: clearedCount, total: total, color: color)
                  else
                    Row(
                      children: [
                        Icon(Icons.account_tree_outlined, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text('分岐マップ・全$_kLayerCount層', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: onStart,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: elementInk(color),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            switch (staminaMode) {
                              StaminaMode.playable => '出発する 👟',
                              StaminaMode.adNeeded => '🎬 広告で挑戦',
                              StaminaMode.exhausted => '本日終了',
                            },
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
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

class _DungeonArt extends StatelessWidget {
  final String id;
  final String emoji;
  final Color color;
  final bool locked;
  const _DungeonArt({required this.id, required this.emoji, required this.color, required this.locked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: locked
          ? Icon(Icons.lock_outline, size: 30, color: color.withValues(alpha: 0.8))
          : enemyArt(id: id, emoji: emoji, size: 76),
    );
  }
}

class _UnlockRow extends StatelessWidget {
  final int clearedCount;
  final int total;
  final Color color;
  const _UnlockRow({required this.clearedCount, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? (clearedCount / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lock_outline, size: 13, color: Colors.grey),
            const SizedBox(width: 4),
            const Expanded(child: Text('全ての悩みを克服すると解禁', style: TextStyle(fontSize: 11, color: Colors.grey))),
            Text('$clearedCount / $total', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: Colors.grey.withValues(alpha: 0.18),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
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

/// 本日の挑戦可否（スタミナ）を示すバナー。ゲージは常時表示（満タン時も）。
/// 回復は「前回の基本プレイから24時間」で満タンになる。
class _StaminaBanner extends StatelessWidget {
  final bool premium;
  final StaminaMode mode;
  final double value; // 回復ゲージ（1.0＝満タン）
  final int hoursLeft; // 回復までの残り時間
  const _StaminaBanner({
    required this.premium,
    required this.mode,
    required this.value,
    required this.hoursLeft,
  });

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String text, bool waiting) = premium
        ? (const Color(0xFF2E9E6B), Icons.all_inclusive, 'プレミアム：ダンジョンは何度でも挑戦できます', false)
        : switch (mode) {
            StaminaMode.playable =>
              (const Color(0xFF3B9CA8), Icons.bolt, '今日の挑戦：あと1回（さらに広告で+1回）', false),
            StaminaMode.adNeeded =>
              (const Color(0xFFE08A2B), Icons.smart_display_outlined, '本日の1回は挑戦済み。広告を見ればもう1回挑戦できます', true),
            StaminaMode.exhausted =>
              (const Color(0xFF8AA0B4), Icons.hourglass_bottom, '今日はもう挑戦しました。次の挑戦までお待ちください', true),
          };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        // 透明度を下げて（不透明に）見やすくする。白地に色を薄く重ねた不透明色。
        color: Color.alphaBlend(color.withValues(alpha: 0.16), Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                waiting ? '回復まで 約$hoursLeft時間' : '満タン',
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (waiting)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('前回の挑戦から24時間で回復', style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.75))),
            ),
        ],
      ),
    );
  }
}
