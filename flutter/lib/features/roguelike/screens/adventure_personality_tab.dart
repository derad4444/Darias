// features/roguelike/screens/adventure_personality_tab.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../data/roguelike_datasource.dart';
import '../models/action_log.dart';
import '../models/dungeon.dart';
import '../models/roguelike_info.dart';
import '../providers/roguelike_provider.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/character_provider.dart';
import '../../../presentation/widgets/ads/screen_banner.dart';
import '../../../data/services/ad_service.dart';

const _kPink = Color(0xFFE08AAE);

/// キャラクター詳細画面の「冒険の性格」タブ。
/// 全踏破後に、全ラン横断の行動傾向・推定元素と、AI生成の総合診断を表示する。
class AdventurePersonalityTab extends ConsumerStatefulWidget {
  final Color textColor;
  final Color accentColor;
  const AdventurePersonalityTab({super.key, required this.textColor, required this.accentColor});

  @override
  ConsumerState<AdventurePersonalityTab> createState() => _AdventurePersonalityTabState();
}

class _AdventurePersonalityTabState extends ConsumerState<AdventurePersonalityTab> {
  bool _generating = false;
  bool _sharing = false;
  final GlobalKey _shareCardKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScreenBanner(adUnitId: AdConfig.adventurePersonalityTopBannerAdUnitId),
        Expanded(child: _content(context)),
        ScreenBanner(adUnitId: AdConfig.adventurePersonalityBottomBannerAdUnitId),
      ],
    );
  }

  Widget _content(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final cleared = ref.watch(clearedDungeonsProvider(userId)).valueOrNull ?? const <String>{};
    final finale = Dungeons.all.firstWhere((d) => d.isFinale, orElse: () => Dungeons.all.last);
    final fullCleared = cleared.contains(finale.id);

    if (!fullCleared) {
      return _lockedView(cleared);
    }

    final aggAsync = ref.watch(aggregatedTraitsProvider(userId));
    final diagnosis = ref.watch(roguelikeDiagnosisProvider(userId)).valueOrNull;
    final currentRunCount = ref.watch(roguelikeRunCountProvider(userId)).valueOrNull;

    return aggAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('読み込みに失敗しました', style: TextStyle(color: widget.textColor))),
      data: (agg) {
        final element = agg.inferredElement();
        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const SizedBox(height: 12),
                  _TraitsCard(traits: agg),
                  const SizedBox(height: 12),
                  _ElementCard(element: element, strength: agg.elementStrengthLabel()),
                  const SizedBox(height: 12),
                  _diagnosisSection(diagnosis, agg, element, currentRunCount),
                ],
              ),
            ),
            // オフスクリーンのシェアカード（キャプチャ専用）
            if (diagnosis != null)
              Positioned(
                left: -9999,
                top: 0,
                child: RepaintBoundary(
                  key: _shareCardKey,
                  child: _ShareCard(diagnosis: diagnosis, traits: agg),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _header() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🧭 冒険の性格（総合診断）',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.textColor)),
          const SizedBox(height: 2),
          Text('心の迷宮を全踏破したあなたの、冒険中の選択から見えた総合診断です。',
              style: TextStyle(fontSize: 12, color: widget.textColor.withValues(alpha: 0.7))),
        ],
      );

  Widget _lockedView(Set<String> cleared) {
    final clearedCount = Dungeons.worries.where((d) => cleared.contains(d.id)).length;
    final total = Dungeons.worries.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔒', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text('冒険の総合診断は\n「心の迷宮」を全踏破すると解禁されます。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.6, color: widget.textColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('克服した悩み  $clearedCount / $total ＋ 最終ダンジョン',
                style: TextStyle(fontSize: 12, color: widget.textColor.withValues(alpha: 0.7))),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : clearedCount / total,
                  minHeight: 8,
                  backgroundColor: widget.textColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(widget.accentColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _diagnosisSection(RoguelikeDiagnosis? diagnosis, ActionLog agg, String element, int? currentRunCount) {
    if (diagnosis == null) {
      return _card(
        child: Column(
          children: [
            const Text('🔮', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            const Text('あなたの冒険を総括する診断を生成します。',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.6)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _kPink, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
                onPressed: _generating ? null : () => _generate(agg, element),
                child: _generating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('🔮 総合診断を生成する'),
              ),
            ),
          ],
        ),
      );
    }
    // 「更新」は前回生成時からダンジョン結果が変わった（ラン数が増えた）ときだけ表示。
    // 連打での無駄な再生成を防ぐ。旧データ（runCount 未保存）は表示、件数取得中は非表示。
    final savedRc = diagnosis.runCount;
    final resultChanged = savedRc == null ||
        (currentRunCount != null && currentRunCount != savedRc);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          color: const Color(0xFFFFF3F6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardTitle('あなたはこういう選択を多く取ります'),
              const SizedBox(height: 8),
              Text(diagnosis.summary, style: const TextStyle(fontSize: 13, height: 1.7)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          color: const Color(0xFFFFFBF0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardTitle('この傾向を、こう活かしましょう'),
              const SizedBox(height: 8),
              Text(diagnosis.advice, style: const TextStyle(fontSize: 13, height: 1.7)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            if (resultChanged) ...[
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: _generating ? null : () => _generate(agg, element),
                  icon: _generating
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 16),
                  label: const Text('更新', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: SizedBox(
                key: _shareButtonKey,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _kPink, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: _sharing ? null : () => _share(diagnosis),
                  icon: _sharing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.ios_share, size: 16),
                  label: const Text('診断をシェア', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
        if (diagnosis.updatedAt != null) ...[
          const SizedBox(height: 8),
          Text('生成日: ${_fmtDate(diagnosis.updatedAt!)}',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: widget.textColor.withValues(alpha: 0.5))),
        ],
      ],
    );
  }

  Future<void> _generate(ActionLog agg, String element) async {
    final userId = ref.read(currentUserIdProvider) ?? '';
    if (userId.isEmpty) return;
    setState(() => _generating = true);
    try {
      final details = ref.read(characterDetailsProvider).valueOrNull;
      final name = details?.typeName ?? 'あなた';
      final homeElement = details?.element ?? '無';
      final top = agg.topTraits().where((e) => e.value > 0).map((e) => e.key).join(' / ');
      final ds = ref.read(roguelikeDatasourceProvider);
      final res = await ds.generateDiagnosisText(
        userId: userId,
        characterName: name,
        topTraits: top.isEmpty ? '（傾向がまだ弱い）' : top,
        inferredElement: element,
        homeElement: homeElement,
      );
      if (res.summary.isEmpty) throw Exception('empty result');
      final rc = await ds.runCount(userId: userId); // 生成時点のラン数を記録
      await ds.saveDiagnosis(
        userId: userId,
        summary: res.summary,
        advice: res.advice,
        element: element,
        topTrait: agg.topTraits().isNotEmpty ? agg.topTraits().first.key : '',
        runCount: rc,
      );
      ref.invalidate(roguelikeRunCountProvider(userId)); // 現在ラン数を再取得し「更新」ボタンを隠す
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('診断の生成に失敗しました。通信環境を確認して再度お試しください。')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _share(RoguelikeDiagnosis diagnosis) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final text = 'DARIAS 心の迷宮 — 全踏破！ 私の冒険の性格診断\n'
        '「${diagnosis.summary}」\n#DARIAS #心の迷宮';
    final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    try {
      final boundary = _shareCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('card not ready');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('encode failed');
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/darias_diagnosis.png').writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: text, sharePositionOrigin: origin);
    } catch (_) {
      await Share.share(text, sharePositionOrigin: origin);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  static String _fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)}';
  }

  Widget _card({required Widget child, Color? color}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: child,
      );

  Widget _cardTitle(String text) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF3A3A3A)));
}

// ===== 総合の行動傾向（レーダー＋TOP3） =====
class _TraitsCard extends StatelessWidget {
  final ActionLog traits;
  const _TraitsCard({required this.traits});

  @override
  Widget build(BuildContext context) {
    final map = traits.toMap();
    final keys = map.keys.toList();
    final values = map.values.toList();
    final maxV = values.fold(0, (m, v) => v > m ? v : m);
    final top = traits.topTraits().where((e) => e.value > 0).toList();
    const medals = ['🥇', '🥈', '🥉'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('総合の行動傾向', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF3A3A3A))),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: maxV == 0
                ? const Center(child: Text('まだ記録がありません', style: TextStyle(fontSize: 12, color: Colors.grey)))
                : RadarChart(
                    RadarChartData(
                      radarShape: RadarShape.polygon,
                      dataSets: [
                        RadarDataSet(
                          dataEntries: values.map((v) => RadarEntry(value: v.toDouble())).toList(),
                          fillColor: _kPink.withValues(alpha: 0.25),
                          borderColor: _kPink,
                          borderWidth: 2,
                          entryRadius: 2,
                        ),
                      ],
                      getTitle: (index, angle) => RadarChartTitle(text: keys[index]),
                      titleTextStyle: const TextStyle(fontSize: 9, color: Colors.black87),
                      titlePositionPercentageOffset: 0.12,
                      tickCount: 4,
                      ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 8),
                      tickBorderData: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      gridBorderData: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      radarBorderData: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                    ),
                  ),
          ),
          if (top.isNotEmpty) ...[
            const Divider(height: 20),
            ...List.generate(top.length, (i) {
              final e = top[i];
              final info = TraitInfo.of(e.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Text(medals[i], style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 6),
                    Text(info.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFD96666))),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ===== 総合の推定元素 =====
class _ElementCard extends StatelessWidget {
  final String element;
  final String strength;
  const _ElementCard({required this.element, required this.strength});

  @override
  Widget build(BuildContext context) {
    final info = ElementInfo.of(element);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          const Text('総合の推定元素', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF3A3A3A))),
          const SizedBox(height: 8),
          Text(info.emoji, style: const TextStyle(fontSize: 38)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: _kPink.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
            child: Text(element == '無' ? '型なし' : '$elementタイプ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          if (strength.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(strength, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
          const SizedBox(height: 8),
          Text(info.description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, height: 1.5)),
        ],
      ),
    );
  }
}

// ===== SNSシェア用カード（画面外でキャプチャ） =====
class _ShareCard extends StatelessWidget {
  final RoguelikeDiagnosis diagnosis;
  final ActionLog traits;
  const _ShareCard({required this.diagnosis, required this.traits});

  @override
  Widget build(BuildContext context) {
    final element = diagnosis.element;
    final elemInfo = ElementInfo.of(element);
    final top = traits.topTraits().where((e) => e.value > 0).take(3).toList();
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF1F6), Color(0xFFF1F7FF)]),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('心の迷宮 — 全踏破 総合診断', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(elemInfo.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 8),
                Text(element == '無' ? '型なし' : '$elementタイプ', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            if (top.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(top.map((e) => e.key).join(' ・ '), style: const TextStyle(fontSize: 13, color: Color(0xFFD96666), fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(14)),
              child: Text(diagnosis.summary, style: const TextStyle(fontSize: 13, height: 1.7)),
            ),
            const SizedBox(height: 14),
            const Text('DARIAS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kPink, letterSpacing: 2)),
          ],
        ),
      ),
    );
  }
}
