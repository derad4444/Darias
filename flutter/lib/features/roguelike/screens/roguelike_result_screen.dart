// features/roguelike/screens/roguelike_result_screen.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_links.dart';
import '../models/game_state.dart';
import '../models/dungeon.dart';
import '../models/game_event.dart';
import '../models/adventure_title.dart';
import '../models/roguelike_info.dart';
import '../data/roguelike_datasource.dart';
import '../widgets/dungeon_theme.dart';
import '../widgets/roguelike_banner.dart';
import '../providers/roguelike_provider.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/character_provider.dart';
import '../../../presentation/screens/main/main_shell_screen.dart' show selectedTabProvider;
import '../../../presentation/widgets/character/element_effect_widget.dart' show characterGrowthAssetPath;

/// メインタブ内の「冒険」タブのインデックス（main_shell_screen の並びと一致）。
/// 並び: 0=ホーム / 1=手帳 / 2=詳細 / 3=フレンド / 4=冒険 / 5=設定
const _adventureTabIndex = 4;

class RoguelikeResultScreen extends ConsumerStatefulWidget {
  const RoguelikeResultScreen({super.key});

  @override
  ConsumerState<RoguelikeResultScreen> createState() => _RoguelikeResultScreenState();
}

class _RoguelikeResultScreenState extends ConsumerState<RoguelikeResultScreen> {
  bool _saved = false;
  bool _isSharing = false;
  final GlobalKey _shareButtonKey = GlobalKey(); // iOS popover origin 用
  final GlobalKey _shareCardKey = GlobalKey();    // オフスクリーンのシェアカード捕捉用

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveRunOnce());
  }

  Future<void> _saveRunOnce() async {
    if (_saved) return;
    final state = ref.read(roguelikeProvider);
    final userId = ref.read(currentUserIdProvider);
    if (state == null || userId == null || userId.isEmpty) return;
    _saved = true;

    final top = state.finalActionLog.topTraits();
    final inferred = state.finalActionLog.inferredElement();
    final title = AdventureTitle.decide(
      log: state.finalActionLog,
      result: state.result,
      inferredElement: inferred,
    );
    final dungeon = Dungeons.byId(state.dungeonId);
    final ds = ref.read(roguelikeDatasourceProvider);

    await ds.saveRun(
      userId: userId,
      data: {
        'characterName': state.characterName,
        'element': state.element,
        'inferredElement': inferred,
        'result': state.result?.name ?? 'retreat',
        'title': title,
        'topTrait': top.isNotEmpty ? top.first.key : '',
        'traits': state.finalActionLog.toMap(),
        'growthStage': state.growthStage.name,
        'dungeonId': state.dungeonId,
        'worry': dungeon.worry,
        'finalHp': state.hp,
        'finalFood': state.food,
        'finalMoney': state.money,
        'finalItems': state.itemCount,
        'finalBond': state.bond,
        'hadCompanion': state.hasCompanion,
        'companionName': state.companion?.name ?? '',
        'enemiesDefeated': state.enemiesDefeated,
        'visitedCount': state.visitedCount,
      },
    );

    // 図鑑（出会ったイベント・敵・獲得称号）を累積記録
    await ds.recordCodex(
      userId: userId,
      events: state.seenEvents,
      enemies: state.seenEnemies,
      title: title,
    );

    // ボス撃破（クリア）＝その悩みの克服を記録（心の図鑑）
    if (state.result == GameResult.clear) {
      await ds.recordClear(userId: userId, dungeonId: state.dungeonId, worry: dungeon.worry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roguelikeProvider);

    if (state == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/roguelike'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final result = state.result;
    final topTraits = state.finalActionLog.topTraits();
    final inferredElement = state.finalActionLog.inferredElement();
    final title = AdventureTitle.decide(log: state.finalActionLog, result: result, inferredElement: inferredElement);
    final dungeon = Dungeons.byId(state.dungeonId);

    // 図鑑・克服の進捗
    final userId = ref.read(currentUserIdProvider) ?? '';
    final clearedSet = {...(ref.watch(clearedDungeonsProvider(userId)).valueOrNull ?? const <String>{})};
    if (result == GameResult.clear) clearedSet.add(state.dungeonId);
    final codex = ref.watch(codexProvider(userId)).valueOrNull ?? const RoguelikeCodex();
    final seenEvents = {...codex.events, ...state.seenEvents};
    final seenEnemies = {...codex.enemies, ...state.seenEnemies};
    final clearedWorries = Dungeons.worries.where((d) => clearedSet.contains(d.id)).length;

    // アバター
    final details = ref.watch(characterDetailsProvider).valueOrNull;
    final signalCount = ref.watch(signalCountProvider).valueOrNull ?? 0;
    final avatarPath = characterGrowthAssetPath(
      signalCount: signalCount,
      element: details?.element,
      gender: details?.gender,
    );

    final (titleText, titleColor) = _resultHeader(result, dungeon.worry);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: kRoguelikeBgGradient),
        child: SafeArea(
        child: Column(
          children: [
            const RoguelikeBanner(),
            Expanded(
              child: Stack(
          children: [
            SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ヘッダー
              _Header(
                ribbon: titleText,
                ribbonColor: titleColor,
                shareKey: _shareButtonKey,
                isSharing: _isSharing,
                onShare: () => _captureAndShare(state, title, inferredElement, avatarPath, topTraits),
              ),

              // 克服演出（クリア時のみ）
              if (result == GameResult.clear) ...[
                const SizedBox(height: 14),
                _OvercomeCard(
                  worry: dungeon.worry,
                  flavor: dungeon.boss.defeatRewardText,
                  clearedCount: clearedWorries,
                  totalWorries: Dungeons.worries.length,
                  isFinale: dungeon.isFinale,
                  finaleUnlocked: Dungeons.finaleUnlocked(clearedSet),
                ),
              ],

              const SizedBox(height: 14),
              _CharacterCard(state: state, avatarPath: avatarPath),

              const SizedBox(height: 14),
              _SummaryCard(
                text: _generateSummary(state, topTraits),
                bagStyle: state.bagStyleLabel,
              ),

              const SizedBox(height: 14),
              // 推定元素 ＋ TOP3
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _ElementCard(element: inferredElement, strength: state.finalActionLog.elementStrengthLabel(), homeElement: state.element)),
                    const SizedBox(width: 12),
                    Expanded(flex: 1, child: _TopTraitsCard(top: topTraits)),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              _RadarCard(traits: state.finalActionLog.toMap()),

              const SizedBox(height: 14),
              _CodexCard(
                eventsSeen: seenEvents.length,
                eventsTotal: GameEvents.all.length,
                enemiesSeen: seenEnemies.length,
                enemiesTotal: Dungeons.allEnemies.length,
                worriesCleared: clearedWorries,
                worriesTotal: Dungeons.worries.length,
              ),

              if (state.notableActions.isNotEmpty) ...[
                const SizedBox(height: 14),
                _NotableActionsCard(actions: _topNotable(state.notableActions)),
              ],

              // 冒険での振る舞いを日常に翻訳して返す。
              // 「◯◯が光る冒険でした」だけだと読み流されてしまうため。
              if (topTraits.isNotEmpty && topTraits.first.value > 0) ...[
                const SizedBox(height: 14),
                _LifeAdviceCard(topTraits: topTraits),
              ],

              const SizedBox(height: 14),
              _MessageCard(text: _generateMessage(state, topTraits, inferredElement)),

              const SizedBox(height: 20),
              _Buttons(ref: ref),
            ],
          ),
        ),
            // オフスクリーンのシェアカード（画面外でキャプチャ専用）
            Positioned(
              left: -9999,
              top: 0,
              child: RepaintBoundary(
                key: _shareCardKey,
                child: _ShareCard(
                  ribbon: titleText,
                  ribbonColor: titleColor,
                  state: state,
                  title: title,
                  element: inferredElement,
                  avatarPath: avatarPath,
                  topTraits: topTraits,
                ),
              ),
            ),
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

  /// シェアカードを画像化してテキストと共に共有する（本編の進化ダイアログと同方式）。
  /// 画像生成できない環境（web等）はテキストのみにフォールバック。
  Future<void> _captureAndShare(
    GameState state, String title, String inferred, String avatarPath, List<MapEntry<String, int>> topTraits) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    final worry = Dungeons.byId(state.dungeonId).worry;
    final verb = state.result == GameResult.clear ? '「$worry」を克服しました！' : '「$worry」に挑みました。';
    final topText = topTraits.isNotEmpty && topTraits.first.value > 0 ? topTraits.first.key : '';
    final text = 'DARIAS 心の迷宮 — $verb\n称号「$title」'
        '${topText.isNotEmpty ? '／際立った傾向: $topText' : ''}'
        '${inferred != '無' ? '／元素:$inferred' : ''}\n#DARIAS #心の迷宮\n${AppLinks.share}';

    // シェアボタンの位置（iOS の popover origin。渡さないと iOS16+ で無言失敗する）
    final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

    try {
      final boundary = _shareCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('share card not ready');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('image encode failed');
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/darias_roguelike.png')
          .writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: text, sharePositionOrigin: origin);
    } catch (_) {
      // 画像生成不可（web等）はテキストのみ
      await Share.share(text, sharePositionOrigin: origin);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  /// notableActions を delta 降順・ラベル重複排除で上位3件にする。
  List<NotableAction> _topNotable(List<NotableAction> all) {
    final sorted = [...all]..sort((a, b) => b.delta.compareTo(a.delta));
    final seen = <String>{};
    final out = <NotableAction>[];
    for (final a in sorted) {
      if (seen.add(a.label)) out.add(a);
      if (out.length >= 3) break;
    }
    return out;
  }

  (String, Color) _resultHeader(GameResult? result, String worry) {
    switch (result) {
      case GameResult.clear:
        return ('「$worry」を克服！', const Color(0xFF2E9E6B));
      case GameResult.retreat:
        return ('迷宮から撤退', const Color(0xFF3B9CA8));
      case GameResult.timeUp:
        return ('時間切れ帰還', const Color(0xFFE08A2B));
      case GameResult.failed:
        return ('冒険失敗', const Color(0xFFD96666));
      case null:
        return ('冒険終了！', const Color(0xFFE08AAE));
    }
  }

  String _generateSummary(GameState state, List<MapEntry<String, int>> topTraits) {
    final hasTraits = topTraits.isNotEmpty && topTraits.first.value > 0;
    if (!hasTraits) {
      return '${state.characterName}の冒険が終わりました。今回はまだ多くの選択が行われていませんでした。次の冒険ではもっと多くのことが見えてくるかもしれません。';
    }
    final t1 = topTraits[0].key;
    final t2 = topTraits.length > 1 ? topTraits[1].key : null;
    final phase = switch (state.result) {
      GameResult.clear => '最後まで諦めず、悩みを乗り越えました。',
      GameResult.retreat => '途中で退く判断をしました。引き際を見極めるのも力です。',
      GameResult.timeUp => '行動の限界まで歩き、帰還しました。',
      GameResult.failed => '途中で力尽きましたが、その過程に多くのものが見えました。',
      null => '今回の冒険を振り返ります。',
    };
    // 「◯◯が光る冒険でした」で止めず、その特性が何をしていたかまで言う。
    // 抽象的な特性名だけだと自分のことだと感じられないため。
    final a1 = TraitAdvice.of(t1);
    final detail = a1 != null ? '${a1.inGame}ね。' : '';
    final traitText = t2 != null ? '$t1と$t2' : t1;
    return '$phase\n$traitTextが光る冒険でした。$detail';
  }

  String _generateMessage(GameState state, List<MapEntry<String, int>> topTraits, String inferred) {
    final name = state.characterName;
    if (topTraits.isEmpty || topTraits.first.value == 0) {
      return '$nameの新たな一面は、次の冒険でもっと見えてくるかもしれません。';
    }
    final t1 = topTraits[0].key;
    final hint = state.hasCompanion
        ? '次の冒険では、仲間との絆をもっと深めてみると、さらに大きな力が引き出されるかもしれません。'
        : '次の冒険では、誰かと手を取り合うと、また違う一面が見えるかもしれません。';
    final elem = inferred != '無' ? '$inferredのような' : '';
    return 'あなたは$t1を備えた$elem冒険者です。\n$hint';
  }
}

// ===== ヘッダー =====
class _Header extends StatelessWidget {
  final String ribbon;
  final Color ribbonColor;
  final GlobalKey shareKey;
  final bool isSharing;
  final VoidCallback onShare;
  const _Header({required this.ribbon, required this.ribbonColor, required this.shareKey, required this.isSharing, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Spacer(),
            // リボン風ラベル
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                color: ribbonColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ribbonColor.withValues(alpha: 0.5)),
              ),
              child: Text(ribbon, style: TextStyle(color: ribbonColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const Spacer(),
            // シェア（GlobalKey 付き＝iOS popover origin 用）
            SizedBox(
              key: shareKey,
              child: OutlinedButton.icon(
                onPressed: isSharing ? null : onShare,
                icon: isSharing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.ios_share, size: 16),
                label: const Text('シェア', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('おつかれさまでした！', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 2),
        const Text('あなたの心の迷宮での冒険の記録です', style: TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}

// ===== 共通カード枠 =====
class _Card extends StatelessWidget {
  final Widget child;
  final Color? color;
  const _Card({required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? kRoguelikeCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

Widget _cardTitle(String text) => Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));

// ===== キャラクター＋ステータス =====
class _CharacterCard extends StatelessWidget {
  final GameState state;
  final String avatarPath;
  const _CharacterCard({required this.state, required this.avatarPath});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 72, height: 72,
                  child: Image.asset(avatarPath, fit: BoxFit.cover, errorBuilder: (context, error, stack) => const Center(child: Text('🧑', style: TextStyle(fontSize: 40)))),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF2C94C).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                child: Text(state.growthStage.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _StatMini(emoji: '🚩', label: '到達層', value: '${state.reachedDepth}/${state.totalDepth}')),
                    Expanded(child: _StatMini(emoji: '⚔️', label: '倒した敵', value: '${state.enemiesDefeated}体')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _StatMini(emoji: '🍞', label: '残り食料', value: '${state.food}')),
                    Expanded(child: _StatMini(emoji: '💰', label: '金貨', value: '${state.money}')),
                  ],
                ),
                if (state.hasCompanion) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _StatMini(emoji: '🤝', label: '絆（${state.companion!.name}）', value: '${state.bond}')),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  const _StatMini({required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}

// ===== 冒険のまとめ =====
class _SummaryCard extends StatelessWidget {
  final String text;

  /// 鞄の使い方の一言（空なら出さない）。持ち物の選択が診断に効いていることを
  /// ユーザーに伝えるための行（設計書 §7.3）。
  final String bagStyle;

  const _SummaryCard({required this.text, required this.bagStyle});

  @override
  Widget build(BuildContext context) {
    return _Card(
      color: const Color(0xFFFFF3F6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardTitle('冒険のまとめ'),
                const SizedBox(height: 8),
                Text(text, style: const TextStyle(fontSize: 13, height: 1.6)),
                if (bagStyle.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('🎒', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          bagStyle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB5713C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text('👻', style: TextStyle(fontSize: 34)),
        ],
      ),
    );
  }
}

// ===== 推定元素 =====
class _ElementCard extends StatelessWidget {
  final String element;     // 今回の冒険から推定した元素
  final String strength;
  final String homeElement; // 本編キャラの元素
  const _ElementCard({required this.element, required this.strength, required this.homeElement});

  /// 本編元素と今回の傾向を比べたひとこと。
  String _compareText() {
    final home = homeElement;
    if (home == '無') {
      return element == '無'
          ? '本編でも今回も、まだ型は定まっていません。'
          : '本編では型なしですが、今回は$elementのように振る舞いました。';
    }
    if (element == '無') {
      return '本編は$homeElementタイプ。今回は型が定まりませんでした。';
    }
    if (element == home) {
      return '本編の$homeElementタイプらしい戦い方でした。';
    }
    return '本編は$homeElementタイプですが、今回は$elementのように振る舞いました。';
  }

  @override
  Widget build(BuildContext context) {
    final info = ElementInfo.of(element);
    final homeInfo = ElementInfo.of(homeElement);
    return _Card(
      child: Column(
        children: [
          _cardTitle('元素'),
          const SizedBox(height: 10),
          Text(info.emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 2),
          const Text('今回の冒険での傾向', style: TextStyle(fontSize: 9, color: Colors.grey)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFE08AAE).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
            child: Text(element == '無' ? '型なし' : '$elementタイプ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          if (strength.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(strength, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
          const SizedBox(height: 8),
          Text(info.description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, height: 1.5)),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          // 本編の元素を必ず併記する
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(homeInfo.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text('本編: ${homeElement == '無' ? '型なし' : '$homeElementタイプ'}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(_compareText(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, height: 1.4, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ===== 上位の行動特性 TOP3 =====
class _TopTraitsCard extends StatelessWidget {
  final List<MapEntry<String, int>> top;
  const _TopTraitsCard({required this.top});

  @override
  Widget build(BuildContext context) {
    const medals = ['🥇', '🥈', '🥉'];
    final shown = top.where((e) => e.value > 0).take(3).toList();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('上位の行動特性 TOP3'),
          const SizedBox(height: 10),
          if (shown.isEmpty)
            const Text('まだ特性が現れていません', style: TextStyle(fontSize: 12, color: Colors.grey))
          else
            ...List.generate(shown.length, (i) {
              final e = shown[i];
              final info = TraitInfo.of(e.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Text(medals[i], style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(info.emoji, style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(info.description, style: const TextStyle(fontSize: 9, color: Colors.grey), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFD96666))),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ===== 行動特性レーダー =====
class _RadarCard extends StatelessWidget {
  final Map<String, int> traits;
  const _RadarCard({required this.traits});

  @override
  Widget build(BuildContext context) {
    final keys = traits.keys.toList();
    final values = traits.values.toList();
    final maxV = values.fold(0, (m, v) => v > m ? v : m);
    return _Card(
      child: Column(
        children: [
          _cardTitle('行動特性グラフ（10特性）'),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: maxV == 0
                ? const Center(child: Text('まだ行動が記録されていません', style: TextStyle(fontSize: 12, color: Colors.grey)))
                : RadarChart(
                    RadarChartData(
                      radarShape: RadarShape.polygon,
                      dataSets: [
                        RadarDataSet(
                          dataEntries: values.map((v) => RadarEntry(value: v.toDouble())).toList(),
                          fillColor: const Color(0xFFE08AAE).withValues(alpha: 0.25),
                          borderColor: const Color(0xFFE08AAE),
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
                  ),
          ),
        ],
      ),
    );
  }
}

// ===== 冒険で解放したもの（図鑑） =====
class _CodexCard extends StatelessWidget {
  final int eventsSeen, eventsTotal, enemiesSeen, enemiesTotal, worriesCleared, worriesTotal;
  const _CodexCard({
    required this.eventsSeen,
    required this.eventsTotal,
    required this.enemiesSeen,
    required this.enemiesTotal,
    required this.worriesCleared,
    required this.worriesTotal,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      color: const Color(0xFFF1F7FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('冒険で解放したもの'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _CodexRow(emoji: '📜', label: 'イベント図鑑', value: '$eventsSeen/$eventsTotal')),
              Expanded(child: _CodexRow(emoji: '👾', label: '敵図鑑', value: '$enemiesSeen/$enemiesTotal')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _CodexRow(emoji: '📖', label: '克服した悩み', value: '$worriesCleared/$worriesTotal')),
            ],
          ),
        ],
      ),
    );
  }
}

class _CodexRow extends StatelessWidget {
  final String emoji, label, value;
  const _CodexRow({required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ===== 印象的だった行動 =====
/// 冒険での振る舞いを日常に翻訳して返すカード。
///
/// 上位2特性について「冒険では何をしていたか → それは日常のどこで効くか →
/// 次に何を試すか」の3段で見せる。診断を読み物で終わらせず、
/// **現実の行動に接続する**のがこの画面の狙い。
class _LifeAdviceCard extends StatelessWidget {
  final List<MapEntry<String, int>> topTraits;
  const _LifeAdviceCard({required this.topTraits});

  @override
  Widget build(BuildContext context) {
    // 上位2つまで。3つ出すと読む気が失せるため絞る。
    final picks = topTraits
        .where((e) => e.value > 0 && TraitAdvice.of(e.key) != null)
        .take(2)
        .toList();
    if (picks.isEmpty) return const SizedBox.shrink();

    return _Card(
      color: const Color(0xFFFFF8EC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _cardTitle('この力を、暮らしでも'),
              const SizedBox(width: 6),
              const Text('🌱', style: TextStyle(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '冒険で見えたあなたの動き方は、そのまま日常でも使えます。',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < picks.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _adviceBlock(picks[i].key),
          ],
        ],
      ),
    );
  }

  Widget _adviceBlock(String trait) {
    final info = TraitInfo.of(trait);
    final advice = TraitAdvice.of(trait)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(info.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(trait,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          ],
        ),
        const SizedBox(height: 6),
        _line('🗺️', '冒険での姿', advice.inGame, const Color(0xFF7A6A55)),
        const SizedBox(height: 4),
        _line('🏠', '日常での強み', advice.inLife, const Color(0xFF3F7FA8)),
        const SizedBox(height: 4),
        _line('💡', 'アドバイス', advice.tryNext, const Color(0xFFC2541E)),
      ],
    );
  }

  Widget _line(String emoji, String label, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 5),
        SizedBox(
          // 「日常での強み」が6文字なので折り返さない幅を確保する
          width: 74,
          child: Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 12, height: 1.55, color: Color(0xFF333333))),
        ),
      ],
    );
  }
}

class _NotableActionsCard extends StatelessWidget {
  final List<NotableAction> actions;
  const _NotableActionsCard({required this.actions});

  @override
  Widget build(BuildContext context) {
    return _Card(
      color: const Color(0xFFFFF3F6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('今回の冒険で印象的だった行動'),
          const SizedBox(height: 10),
          ...actions.map((a) {
            final info = TraitInfo.of(a.trait);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(info.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('「${a.label}」', style: const TextStyle(fontSize: 13))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE08AAE).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: Text('${a.trait} +${a.delta}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD96666))),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ===== ひとことメッセージ =====
class _MessageCard extends StatelessWidget {
  final String text;
  const _MessageCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return _Card(
      color: const Color(0xFFFFFBF0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardTitle('ひとことメッセージ'),
                const SizedBox(height: 8),
                Text(text, style: const TextStyle(fontSize: 13, height: 1.7)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text('🧚‍♀️', style: TextStyle(fontSize: 34)),
        ],
      ),
    );
  }
}

// ===== ボタン =====
class _Buttons extends StatelessWidget {
  final WidgetRef ref;
  const _Buttons({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 左：ホーム（色付きのメインボタン）
        Expanded(
          flex: 2,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              backgroundColor: const Color(0xFFE08AAE),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              // ホーム（冒険タブ＝ダンジョン選択・アプリのタブバーあり）へ戻る。
              // 状態クリアを先にやると結果画面が state==null で単独ルート /roguelike
              // （タブバーなし）へ誘導してしまうため、遷移を先に行い、クリアは遷移後に回す。
              final notifier = ref.read(roguelikeProvider.notifier);
              ref.read(selectedTabProvider.notifier).state = _adventureTabIndex; // 冒険タブ＝ダンジョン選択
              context.go('/');
              WidgetsBinding.instance.addPostFrameCallback((_) => notifier.resetGame());
            },
            child: const Text('🏠 ホーム', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        // 右：記録
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            onPressed: () => context.push('/roguelike/history'), // 記録一覧へ（戻るで結果画面に復帰）
            child: const Text('📖 記録', style: TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }
}

// ===== SNSシェア用カード（画面外でキャプチャしてPNG共有） =====
class _ShareCard extends StatelessWidget {
  final String ribbon;
  final Color ribbonColor;
  final GameState state;
  final String title;
  final String element;
  final String avatarPath;
  final List<MapEntry<String, int>> topTraits;

  const _ShareCard({
    required this.ribbon,
    required this.ribbonColor,
    required this.state,
    required this.title,
    required this.element,
    required this.avatarPath,
    required this.topTraits,
  });

  @override
  Widget build(BuildContext context) {
    final elemInfo = ElementInfo.of(element);
    final shown = topTraits.where((e) => e.value > 0).take(3).toList();
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF1F6), Color(0xFFF1F7FF)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('心の迷宮 — Inner Quest', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: ribbonColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ribbonColor.withValues(alpha: 0.5)),
              ),
              child: Text(ribbon, style: TextStyle(color: ribbonColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 16),
            ClipOval(
              child: Container(
                width: 96, height: 96,
                color: Colors.white,
                child: Image.asset(avatarPath, fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const Center(child: Text('🧑', style: TextStyle(fontSize: 52)))),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  Text('🏅 称号', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 2),
                  Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(elemInfo.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(element == '無' ? '型なし' : '$elementタイプ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            if (shown.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: shown.map((e) {
                  final info = TraitInfo.of(e.key);
                  return Column(
                    children: [
                      Text(info.emoji, style: const TextStyle(fontSize: 18)),
                      Text(e.key, style: const TextStyle(fontSize: 11)),
                      Text('${e.value}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFD96666))),
                    ],
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 14),
            const Text('DARIAS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFE08AAE), letterSpacing: 2)),
          ],
        ),
      ),
    );
  }
}

// ===== 克服の演出（クリア時） =====
class _OvercomeCard extends StatelessWidget {
  final String worry;
  final String flavor;
  final int clearedCount;
  final int totalWorries;
  final bool isFinale;
  final bool finaleUnlocked;

  const _OvercomeCard({
    required this.worry,
    required this.flavor,
    required this.clearedCount,
    required this.totalWorries,
    required this.isFinale,
    required this.finaleUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    final green = Colors.green.shade600;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [green.withValues(alpha: 0.18), green.withValues(alpha: 0.04)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: green.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text('🎉 悩みを乗り越えた', style: TextStyle(fontSize: 12, color: green, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('「$worry」を克服した', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
          if (flavor.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(flavor, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, height: 1.6, color: Colors.white)),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text('📖 心の図鑑　克服した悩み $clearedCount / $totalWorries',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: green)),
          ),
          if (isFinale) ...[
            const SizedBox(height: 10),
            const Text('全ての悩みを束ねる存在を越えた。あなたは一回り大きくなった。', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ] else if (finaleUnlocked) ...[
            const SizedBox(height: 10),
            const Text('🌀 全ての悩みを克服した！\n最終ダンジョン「心の迷宮の守護者」が解禁された。', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ],
      ),
    );
  }
}
