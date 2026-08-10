// features/roguelike/screens/roguelike_game_screen.dart

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/game_state.dart';
import '../models/game_event.dart';
import '../models/enemy.dart';
import '../models/dungeon.dart';
import '../models/outcome.dart';
import '../models/map_cell.dart';
import '../models/element_affinity.dart';
import '../providers/roguelike_provider.dart';
import '../widgets/map_grid_widget.dart';
import '../widgets/resource_bar_widget.dart';
import '../widgets/bag_sheet.dart';
import '../widgets/dungeon_theme.dart';
import '../widgets/roguelike_banner.dart';
import '../../../presentation/providers/character_provider.dart';
import '../../../presentation/providers/ad_provider.dart';
import '../../../presentation/providers/subscription_provider.dart' show effectiveIsPremiumProvider;
import '../../../presentation/screens/main/main_shell_screen.dart' show selectedTabProvider;
import '../../../presentation/widgets/character/element_effect_widget.dart' show characterGrowthAssetPath;

const _kPink = Color(0xFFE08AAE);

class RoguelikeGameScreen extends ConsumerWidget {
  const RoguelikeGameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(roguelikeProvider);

    if (gameState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/roguelike'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (gameState.phase == GamePhase.victory || gameState.phase == GamePhase.gameOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/roguelike/result'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final details = ref.watch(characterDetailsProvider).valueOrNull;
    final signalCount = ref.watch(signalCountProvider).valueOrNull ?? 0;
    final avatarPath = characterGrowthAssetPath(signalCount: signalCount, element: details?.element, gender: details?.gender);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: kRoguelikeBgGradient),
        child: SafeArea(
          child: Column(
            children: [
              const RoguelikeBanner(),
              ResourceBarWidget(
                state: gameState,
                avatarPath: avatarPath,
                onMenu: () => _confirmQuit(context, ref),
                onOpenBag: () => showBagSheet(context),
              ),
              Expanded(
                child: switch (gameState.phase) {
                  GamePhase.exploring => _ExploringView(state: gameState, ref: ref, avatarPath: avatarPath),
                  GamePhase.event => _EventView(state: gameState, ref: ref),
                  GamePhase.battle => _BattleView(state: gameState, avatarPath: avatarPath),
                  _ => const SizedBox.shrink(),
                },
              ),
              // 下部バナーはゲーム画面の縦スペースを圧迫するため非表示（上部バナーのみ）
            ],
          ),
        ),
      ),
    );
  }

  void _confirmQuit(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('冒険を中断しますか？'),
        content: const Text('中断すると今回の冒険は記録されず、ダンジョン選択に戻ります。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('続ける')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // ダンジョン選択（冒険タブ・タブバーあり）へ戻る。
              // 状態クリアを先にやると state==null で単独ルート /roguelike へ
              // 誘導されるため、遷移を先に行いクリアは遷移後に回す。
              final notifier = ref.read(roguelikeProvider.notifier);
              ref.read(selectedTabProvider.notifier).state = 4; // 冒険タブ＝ダンジョン選択
              context.go('/');
              WidgetsBinding.instance.addPostFrameCallback((_) => notifier.resetGame());
            },
            child: const Text('中断する', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ===== 探索ビュー =====
class _ExploringView extends StatefulWidget {
  final GameState state;
  final WidgetRef ref;
  final String avatarPath;
  const _ExploringView({required this.state, required this.ref, required this.avatarPath});

  @override
  State<_ExploringView> createState() => _ExploringViewState();
}

class _ExploringViewState extends State<_ExploringView> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // マップは下（スタート＝現在地）から表示する。初期表示で現在地までスクロールを合わせる。
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToPlayer(animate: false));
  }

  @override
  void didUpdateWidget(covariant _ExploringView old) {
    super.didUpdateWidget(old);
    // 現在地が進んだら（上方向へ）追従スクロールする。
    if (old.state.playerLayer != widget.state.playerLayer ||
        old.state.playerIndex != widget.state.playerIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToPlayer(animate: true));
    }
  }

  /// 現在地ノードがビューポート下寄りに来るようスクロール位置を合わせる。
  void _scrollToPlayer({required bool animate}) {
    if (!_scroll.hasClients) return;
    final s = widget.state;
    final layerCount = s.map.length;
    // _Card の上パディング(16) + マップ内での現在地の y 座標。
    final playerY = 16 + (layerCount - 1 - s.playerLayer + 0.5) * MapGridWidget.layerGap;
    final vh = _scroll.position.viewportDimension;
    final max = _scroll.position.maxScrollExtent;
    final target = (playerY - vh * 0.55).clamp(0.0, max);
    if (animate) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              child: Column(
                children: [
                  _Card(
                    child: MapGridWidget(
                      state: state,
                      onCellTap: (layer, index) => widget.ref.read(roguelikeProvider.notifier).moveToCell(layer, index),
                      characterAssetPath: widget.avatarPath,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _Legend(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 行き先の種類の凡例（折りたたみ）。
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    const items = [
      (CellType.enemy, '必ず戦闘'),
      (CellType.chest, 'イベント'),
      (CellType.rest, 'イベント'),
      (CellType.merchant, 'イベント'),
      (CellType.companion, 'イベント'),
      (CellType.mystery, 'イベント'),
      (CellType.empty, '何も起きない'),
      (CellType.boss, '最終・必ず到達'),
    ];
    return _Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          title: const Text('行き先の種類（凡例）', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: items.map((it) {
                final t = it.$1;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text('${t.label}（${it.$2}）', style: const TextStyle(fontSize: 12)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== イベントビュー =====
class _EventView extends StatelessWidget {
  final GameState state;
  final WidgetRef ref;
  const _EventView({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final event = state.currentEvent;
    final lastChoice = state.lastChoice;
    if (event == null) return const SizedBox.shrink();

    if (lastChoice != null) {
      return _EventResultView(event: event, choice: lastChoice, outcome: state.lastOutcome, notice: state.eventNotice, ref: ref);
    }

    final choices = GameEvents.forStage(event.choices, state.growthStage)
        .where((c) => !c.requiresCompanion || state.hasCompanion)
        .where((c) => !c.requiresItem || state.itemCount > 0)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                Text(event.description, style: const TextStyle(height: 1.6, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('どうする？　（行動を選んでください）', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          ),
          ...choices.map((choice) => _ChoiceCard(
                emoji: _eventIcon(choice),
                title: choice.label,
                tag: null,
                // 追加食料コスト（extraFoodCost）を上乗せして 🍞 コストとして表示する。
                cost: choice.extraFoodCost > 0
                    ? {...choice.upfrontCost, 'food': (choice.upfrontCost['food'] ?? 0) - choice.extraFoodCost}
                    : choice.upfrontCost,
                extraAction: 0,
                description: choice.riskHint,
                successRate: choice.successRate,
                isGuaranteed: choice.isGuaranteed,
                showRate: true,
                onTap: () => ref.read(roguelikeProvider.notifier).chooseEvent(choice),
              )),
        ],
      ),
    );
  }

  String _eventIcon(EventChoice c) {
    final l = c.label;
    if (l.contains('回復薬')) return '🧪';
    if (l.contains('調べ') || l.contains('確認') || l.contains('観察')) return '🔍';
    if (l.contains('食料')) return '🍞';
    if (l.contains('お金') || l.contains('買')) return '💰';
    if (l.contains('立ち去') || l.contains('無視') || l.contains('休ま')) return '🚶';
    if (l.contains('休')) return '🔥';
    return '✨';
  }
}

// ===== 戦闘ビュー =====
// 成功/失敗を即座に伝えるため、結果が確定するたびに中央バッジをポップ表示し、
// 失敗時は画面を小刻みに横揺れさせる。ログを開かなくても成否が分かるようにする狙い。
class _BattleView extends ConsumerStatefulWidget {
  final GameState state;
  final String avatarPath;
  const _BattleView({required this.state, required this.avatarPath});

  @override
  ConsumerState<_BattleView> createState() => _BattleViewState();
}

class _BattleViewState extends ConsumerState<_BattleView> with TickerProviderStateMixin {
  late final AnimationController _badgeCtrl; // 中央バッジの拡大フェード
  late final AnimationController _shakeCtrl; // 失敗時の横揺れ
  OutcomeTier? _flashTier; // 表示中のバッジ段階
  int _msgIndex = 0; // メッセージ順送りの現在位置
  bool _adBusy = false; // 広告表示中（ボタン二度押し防止）

  @override
  void initState() {
    super.initState();
    _badgeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    // 撃破時に出すリワード広告を事前ロードしておく（AdController の初期化で loadAd される）。
    ref.read(adControllerProvider);
  }

  /// リワード広告を表示してから完了を待つ。プレミアム/Web、読み込み失敗・スキップでも
  /// そのまま進める（広告が出ないせいで進めなくなるのを防ぐ）。
  Future<void> _watchAd() async {
    if (ref.read(effectiveIsPremiumProvider) || kIsWeb) return;
    try {
      await ref.read(rewardedAdManagerProvider).showAndAwaitReward();
    } catch (_) {}
  }

  /// ザコ撃破「次に進む」: 広告 → 探索継続。
  Future<void> _proceedExplore() async {
    if (_adBusy) return;
    setState(() => _adBusy = true);
    await _watchAd();
    if (!mounted) return;
    ref.read(roguelikeProvider.notifier).closeBattle();
  }

  /// ボス撃破「結果を見る」: 広告 → 結果画面（クリア記録）。
  Future<void> _seeResult() async {
    if (_adBusy) return;
    setState(() => _adBusy = true);
    await _watchAd();
    if (!mounted) return;
    ref.read(roguelikeProvider.notifier).confirmBossVictory();
  }

  /// 「進まない／見ない」: 記録せずダンジョン選択（冒険タブ）へ戻る。
  void _quitToSelection() {
    if (_adBusy) return;
    final notifier = ref.read(roguelikeProvider.notifier);
    ref.read(selectedTabProvider.notifier).state = 4; // 冒険タブ＝ダンジョン選択
    context.go('/');
    WidgetsBinding.instance.addPostFrameCallback((_) => notifier.resetGame());
  }

  @override
  void didUpdateWidget(covariant _BattleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 戦闘アクションの通し番号が進んだ＝新しい結果が出たので、
    // メッセージ送りを先頭に戻し、成功/失敗演出を再生する。
    if (widget.state.battleActionSeq != oldWidget.state.battleActionSeq) {
      _msgIndex = 0;
      if (widget.state.lastBattleTier != null) {
        _playFlash(widget.state.lastBattleTier!);
      }
    }
  }

  void _playFlash(OutcomeTier tier) {
    setState(() => _flashTier = tier);
    _badgeCtrl.forward(from: 0);
    if (tier == OutcomeTier.failure) _shakeCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _badgeCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final enemy = state.currentEnemy;
    if (enemy == null) return const SizedBox.shrink();

    final filtered = Enemies.forStage(enemy.choices, state.growthStage)
        .where((c) => !c.requiresCompanion || state.hasCompanion)
        .where((c) => !c.requiresItem || state.itemCount > 0)
        // 「1回のみ」の選択肢は、この戦闘で使用済みなら出さない。
        .where((c) => !c.oncePerBattle || !state.usedChoices.contains(c.label))
        .toList();
    // 「逃げる」は常に一番下に並べる（他の順序は維持）。
    final choices = [...filtered.where((c) => !c.isFlee), ...filtered.where((c) => c.isFlee)];
    final isDefeated = enemy.isDefeated;
    // 広告を出さない条件は _watchAd() と揃える。文言と実挙動を食い違わせない。
    final noAd = ref.watch(effectiveIsPremiumProvider) || kIsWeb;
    // メッセージ送り中は選択肢を隠し、メッセージウィンドウを表示する。
    final messages = state.battleMessages;
    final showingMessages = messages.isNotEmpty;

    final content = Column(
      children: [
        // 固定: 敵カード（キャラクター＆敵の画像・HP・ターン）。スクロールしない。
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: _EnemyCard(enemy: enemy, state: state, avatarPath: widget.avatarPath),
        ),
        const SizedBox(height: 14),
        if (showingMessages)
          // メッセージウィンドウ（タップで1文ずつ送る）。
          Expanded(child: _messageWindow(messages))
        else ...[
          // スクロール: 「どうする？」＋選択肢リストのみ。
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDefeated)
                    _Card(
                      child: Column(
                        children: [
                          Text('${enemy.name}を乗り越えた！', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E9E6B))),
                          const SizedBox(height: 6),
                          Text(
                            noAd
                                ? (enemy.isBoss ? '結果を確認しますか？' : '探索を続けますか？')
                                : (enemy.isBoss
                                    ? '広告を見て結果を確認しますか？'
                                    : '広告を見て探索を続けますか？'),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: _kPink, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
                              onPressed: _adBusy ? null : (enemy.isBoss ? _seeResult : _proceedExplore),
                              child: _adBusy
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text(
                                      noAd
                                          ? (enemy.isBoss ? '結果を見る' : '次に進む')
                                          : (enemy.isBoss
                                              ? '🎬 結果を見る'
                                              : '🎬 次に進む'),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                              onPressed: _adBusy ? null : _quitToSelection,
                              child: Text(enemy.isBoss ? '見ない（ダンジョン選択へ）' : '進まない（ダンジョン選択へ）', style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text('どうする？　（行動を選んでください）', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                    ),
                    ...choices.map((c) {
                      final sealed = state.sealedChoices.contains(c.label);
                      final rep = _repOutcome(c);
                      final (tagText, tagColor) = _battleTag(c, rep);
                      return _ChoiceCard(
                        emoji: _battleIcon(c),
                        title: c.label,
                        tag: c.isFlee ? null : (tagText, tagColor),
                        cost: c.upfrontCost,
                        extraAction: 0,
                        description: c.riskHint,
                        successRate: c.successRate,
                        isGuaranteed: c.isGuaranteed,
                        showRate: !c.isFlee,
                        sealed: sealed,
                        damageInfo: c.isFlee ? null : _damageInfo(rep, widget.state.weaponAtk, widget.state.armorDef),
                        fleeNote: c.isFlee ? '離脱を試みる' : null,
                        onTap: sealed ? null : () => ref.read(roguelikeProvider.notifier).performBattleAction(c),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          // 下部バー
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              color: kRoguelikeCard,
              border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
            ),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showLog(context),
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('ログ', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFF6E9BE6).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
                    child: const Text('行動を選択してください', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    return Stack(
      children: [
        // 失敗時は本体ごと小刻みに横揺れさせる。
        AnimatedBuilder(
          animation: _shakeCtrl,
          builder: (context, child) {
            final t = _shakeCtrl.value;
            final dx = t == 0 ? 0.0 : math.sin(t * math.pi * 8) * 10 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: content,
        ),
        // 中央バッジ（タップは透過させる）。
        if (_flashTier != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _badgeCtrl,
                builder: (context, _) => Center(child: _buildBadge(_flashTier!, _badgeCtrl.value)),
              ),
            ),
          ),
      ],
    );
  }

  /// 中央バッジ本体。v は 0→1 の進捗。序盤で拡大フェードイン、終盤でフェードアウト。
  Widget _buildBadge(OutcomeTier tier, double v) {
    final (label, color) = switch (tier) {
      OutcomeTier.great   => ('✨大成功！✨', const Color(0xFFF2B705)),
      OutcomeTier.success => ('成功', const Color(0xFF2E9E6B)),
      OutcomeTier.failure => ('失敗…', const Color(0xFFE45B5B)),
    };
    // フェード: 最初の15%で出現、最後の30%で消滅。
    final opacity = v < 0.15
        ? (v / 0.15)
        : v > 0.7
            ? ((1 - v) / 0.3).clamp(0.0, 1.0)
            : 1.0;
    // スケール: 出現時に少しオーバーシュートしてから落ち着く。
    final scale = 0.6 + 0.4 * Curves.easeOutBack.transform((v / 0.3).clamp(0.0, 1.0));
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ),
      ),
    );
  }

  /// メッセージウィンドウ（RPG風）。タップで1文ずつ送り、最後の文でタップすると
  /// 順送りを終える（戦闘継続なら選択肢へ、保留中の遷移があればその画面へ）。
  Widget _messageWindow(List<String> messages) {
    final idx = _msgIndex.clamp(0, messages.length - 1);
    final isLast = idx >= messages.length - 1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!isLast) {
          setState(() => _msgIndex = idx + 1);
        } else {
          ref.read(roguelikeProvider.notifier).finishBattleMessages();
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          children: [
            // 敵カード（キャラクター）のすぐ下に表示する（上寄せ）。
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kRoguelikeCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kPink.withValues(alpha: 0.3)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(messages[idx], style: const TextStyle(fontSize: 15, height: 1.6)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${idx + 1} / ${messages.length}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(width: 10),
                      Text(isLast ? 'タップで続ける ▶' : 'タップで次へ ▶', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kPink)),
                    ],
                  ),
                ],
              ),
            ),
            // 残りの領域もタップで送れるように空けておく。
            const Spacer(),
          ],
        ),
      ),
    );
  }

  void _showLog(BuildContext context) {
    final history = widget.state.battleHistory;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('行動ログ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('この戦闘で行った行動と成果', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            if (history.isEmpty)
              const Text('まだ行動していません', style: TextStyle(color: Colors.grey, fontSize: 13))
            else
              ...history.map((l) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('• $l', style: const TextStyle(fontSize: 13)))),
          ],
        ),
      ),
    );
  }

  /// 代表的な結果（最も重みの大きい outcome）。
  Outcome? _repOutcome(BattleChoice c) {
    if (c.outcomes.isEmpty) return null;
    return c.outcomes.reduce((a, b) => b.weight > a.weight ? b : a);
  }

  (String, Color) _battleTag(BattleChoice c, Outcome? rep) {
    if (c.requiresItem) return ('回復', const Color(0xFF3B9CA8));
    if (c.requiresCompanion) return ('特効', const Color(0xFF2E9E6B));
    final dmg = rep?.damageToEnemy ?? 0;
    if (c.isGuaranteed && dmg >= 12) return ('特効', const Color(0xFF8E7CC3));
    if (c.successRate >= 100) return ('安定', const Color(0xFF5B8DEF));
    return ('攻撃', _kPink);
  }

  String _battleIcon(BattleChoice c) {
    if (c.isFlee) return '👟';
    if (c.requiresItem) return '🧪';
    final l = c.label;
    if (l.contains('観察') || l.contains('分析')) return '🔍';
    if (l.contains('仲間') || l.contains('話') || l.contains('相談')) return '💬';
    if (l.contains('交渉')) return '🤝';
    if (l.contains('目標') || l.contains('思い出') || l.contains('深呼吸') || l.contains('一つずつ') || l.contains('物差し') || l.contains('本音') || l.contains('決め') || l.contains('60点') || l.contains('5分')) return '✨';
    return '⚔️';
  }

  /// 想定ダメージ/効果の文字列。ダメージがあれば敵/自、無ければ resourceChanges。
  /// 装備補正（武器＝与ダメ+／防具＝被ダメ-）を反映する（元素倍率は含まない目安）。
  ({String enemy, String self, String? effect}) _damageInfo(Outcome? rep, int weaponAtk, int armorDef) {
    if (rep == null) return (enemy: '0', self: '0', effect: null);
    if (rep.damageToEnemy > 0) {
      final toEnemy = rep.damageToEnemy + weaponAtk;
      final toSelf = rep.damageToPlayer > 0 ? (rep.damageToPlayer - armorDef).clamp(1, 999) : 0;
      return (enemy: '$toEnemy', self: '$toSelf', effect: null);
    }
    // 回復・絆など
    final ch = rep.resourceChanges;
    final parts = <String>[];
    const labels = {'hp': '❤️', 'food': '🍞', 'money': '💰', 'items': '🧪', 'bond': '🤝'};
    ch.forEach((k, v) {
      if (v != 0) parts.add('${labels[k] ?? k}${v > 0 ? '+' : ''}$v');
    });
    return (enemy: '0', self: '0', effect: parts.isEmpty ? null : parts.join(' '));
  }
}

// ===== 敵カード =====
class _EnemyCard extends StatelessWidget {
  final Enemy enemy;
  final GameState state;
  final String avatarPath;
  const _EnemyCard({required this.enemy, required this.state, required this.avatarPath});

  @override
  Widget build(BuildContext context) {
    final ratio = enemy.maxHp > 0 ? (enemy.currentHp / enemy.maxHp).clamp(0.0, 1.0) : 0.0;
    final emoji = enemy.isBoss ? Dungeons.byId(state.dungeonId).emoji : '💭';
    final match = elementMatch(state.element, enemy.element);
    final c = enemyColor(enemy); // 敵の元素色
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withValues(alpha: 0.55), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: enemyArt(id: enemy.id, emoji: emoji, size: 48),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(enemy.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('HP ${enemy.currentHp} / ${enemy.maxHp}', style: const TextStyle(fontSize: 13, color: kRoguelikeInk, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (enemy.element != '無') _ElementMatchBadge(enemyElement: enemy.element, match: match),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: ratio, minHeight: 8, backgroundColor: c.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation(c)),
          ),
          const SizedBox(height: 12),
          Text(enemy.description, style: const TextStyle(fontSize: 13, height: 1.5)),
          const SizedBox(height: 12),
          // シーン（プレースホルダ：グラデ背景＋キャラ／敵の絵文字）
          Container(
            height: 110,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFEAF7EC), Color(0xFFF3F0FA)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ClipOval(child: SizedBox(width: 56, height: 56, child: Image.asset(avatarPath, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Center(child: Text('🧑', style: TextStyle(fontSize: 34)))))),
                SizedBox(
                  width: 84,
                  height: 84,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: enemyArt(id: enemy.id, emoji: emoji, size: 84),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: kRoguelikeCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withValues(alpha: 0.06))),
                child: Text('ターン ${state.battleTurns + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              if (!enemy.isDefeated)
                Flexible(child: Text('次: ${enemy.nextAction}', style: const TextStyle(fontSize: 11, color: Colors.orange), overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 敵の元素＋本編元素との相性（有利/不利/互角）バッジ。
class _ElementMatchBadge extends StatelessWidget {
  final String enemyElement;
  final ElementMatch match;
  const _ElementMatchBadge({required this.enemyElement, required this.match});

  @override
  Widget build(BuildContext context) {
    final ec = elementColor(enemyElement);
    final (label, mc) = switch (match) {
      ElementMatch.advantage => ('有利', const Color(0xFF2E9E6B)),
      ElementMatch.disadvantage => ('不利', const Color(0xFFE0685E)),
      ElementMatch.neutral => ('互角', Colors.grey),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('敵の元素', style: TextStyle(fontSize: 9, color: Colors.grey)),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 元素チップ（元素色）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: ec, borderRadius: BorderRadius.circular(10)),
              child: Text(enemyElement, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: elementInk(ec))),
            ),
            const SizedBox(width: 4),
            // 有利/不利チップ（意味色）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: mc.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: mc.withValues(alpha: 0.5)),
              ),
              child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: mc)),
            ),
          ],
        ),
      ],
    );
  }
}

// ===== 共通：行動選択カード（戦闘・イベント共通） =====
class _ChoiceCard extends StatelessWidget {
  final String emoji;
  final String title;
  final (String, Color)? tag;
  final Map<String, int> cost;
  final int extraAction;
  final String description;
  final int successRate;
  final bool isGuaranteed;
  final bool showRate;
  final bool sealed;
  final ({String enemy, String self, String? effect})? damageInfo;
  final String? fleeNote;
  final VoidCallback? onTap;

  const _ChoiceCard({
    required this.emoji,
    required this.title,
    required this.tag,
    required this.cost,
    required this.extraAction,
    required this.description,
    required this.successRate,
    required this.isGuaranteed,
    required this.showRate,
    this.sealed = false,
    this.damageInfo,
    this.fleeNote,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = tag?.$2 ?? _kPink;
    final rateColor = successRate >= 85 ? const Color(0xFF2E9E6B) : successRate >= 60 ? Colors.orange : Colors.red;
    return Opacity(
      opacity: sealed ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Color.alphaBlend(tint.withValues(alpha: 0.07), Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tint.withValues(alpha: 0.25)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44, height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: tint.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  // 中央：タイトル＋タグ＋コスト＋説明
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(sealed ? '$title（封じられている）' : title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            if (tag != null) _chip(tag!.$1, tag!.$2),
                            ..._costChips(),
                          ],
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(description, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 右：成功率＋想定ダメージ
                  SizedBox(
                    width: 96,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (showRate)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('成功率 ', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text(isGuaranteed ? '確定' : '$successRate%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: rateColor)),
                            ],
                          ),
                        if (fleeNote != null)
                          Text('$fleeNote\n（成功率 70%）', textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        if (damageInfo != null) ...[
                          const SizedBox(height: 2),
                          // この値は代表的な結果（最も出やすい outcome）に基づく想定値。
                          // 確定枠は変動しないので「確定」と明示し、それ以外は「想定」と明示する。
                          Text(
                            damageInfo!.effect != null
                                ? (isGuaranteed ? '効果（確定）' : '想定効果')
                                : (isGuaranteed ? 'ダメージ（確定）' : '想定ダメージ'),
                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                          if (damageInfo!.effect != null)
                            Text(damageInfo!.effect!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
                          else ...[
                            Text('敵に ${damageInfo!.enemy}', style: const TextStyle(fontSize: 11)),
                            Text('自分に ${damageInfo!.self}', style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _costChips() {
    const labels = {'hp': '❤️HP', 'food': '🍞食料', 'money': '💰金貨', 'items': '🧪回復薬', 'bond': '🤝絆'};
    final chips = <Widget>[];
    cost.forEach((k, v) {
      if (v != 0) chips.add(_chip('${labels[k] ?? k} $v', Colors.grey));
    });
    if (extraAction > 0) chips.add(_chip('👣 -$extraAction', Colors.grey));
    return chips;
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color == Colors.grey ? Colors.grey.shade700 : color)),
      );
}

// ===== イベント結果ビュー =====
class _EventResultView extends StatelessWidget {
  final GameEvent event;
  final EventChoice choice;
  final Outcome? outcome;
  final String? notice;
  final WidgetRef ref;
  const _EventResultView({required this.event, required this.choice, required this.outcome, required this.notice, required this.ref});

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    final showBadge = o != null && !choice.isGuaranteed;
    final mergedChanges = <String, int>{};
    choice.upfrontCost.forEach((k, v) => mergedChanges[k] = (mergedChanges[k] ?? 0) + v);
    o?.resourceChanges.forEach((k, v) => mergedChanges[k] = (mergedChanges[k] ?? 0) + v);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          _Card(
            child: Column(
              children: [
                Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 6),
                Text('「${choice.label}」を選んだ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 14),
                if (showBadge) _OutcomeBadge(tier: o.tier),
                if (showBadge) const SizedBox(height: 14),
                Text(o?.resultText ?? '', textAlign: TextAlign.center, style: const TextStyle(height: 1.7, fontSize: 14)),
                const SizedBox(height: 18),
                _ResourceDeltaRow(changes: mergedChanges),
                if (notice != null && notice!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: _kPink.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _kPink.withValues(alpha: 0.4))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('👥', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Flexible(child: Text(notice!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kPink, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
              onPressed: () => ref.read(roguelikeProvider.notifier).closeEvent(),
              child: const Text('続ける'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceDeltaRow extends StatelessWidget {
  final Map<String, int> changes;
  const _ResourceDeltaRow({required this.changes});

  @override
  Widget build(BuildContext context) {
    final labels = {'hp': '❤️HP', 'food': '🍞食料', 'money': '💰金貨', 'items': '🧪回復薬', 'bond': '🤝絆'};
    final chips = changes.entries.where((e) => e.value != 0).map((e) => '${labels[e.key] ?? e.key} ${e.value > 0 ? '+' : ''}${e.value}').toList();
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: chips.map((text) {
        final isPositive = text.contains('+');
        return Chip(
          label: Text(text, style: TextStyle(color: isPositive ? const Color(0xFF2E9E6B) : Colors.red, fontSize: 12)),
          backgroundColor: (isPositive ? const Color(0xFF2E9E6B) : Colors.red).withValues(alpha: 0.1),
          side: BorderSide.none,
        );
      }).toList(),
    );
  }
}

class _OutcomeBadge extends StatelessWidget {
  final OutcomeTier tier;
  const _OutcomeBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (tier) {
      OutcomeTier.great => (Colors.amber.shade700, Icons.auto_awesome, '大成功！'),
      OutcomeTier.success => (const Color(0xFF2E9E6B), Icons.check_circle, '成功'),
      OutcomeTier.failure => (Colors.red, Icons.cancel, '失敗'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}

// ===== 共通カード枠 =====
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
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}
