// features/roguelike/models/adventure_title.dart

import 'action_log.dart';
import 'game_state.dart';

/// 冒険の結果（行動傾向・終了種別・推定元素）から称号を決める。
class AdventureTitle {
  static String decide({
    required ActionLog log,
    required GameResult? result,
    required String inferredElement,
  }) {
    final top = log.topTraits();
    final hasTraits = top.isNotEmpty && top.first.value > 0;
    if (!hasTraits) return '迷宮の旅人';

    // 元素傾向がはっきり出ている場合は元素称号を優先（'無'なら特性ベース）
    final elementTitle = _elementTitles[inferredElement];
    if (elementTitle != null) {
      // ボス撃破は称号に箔をつける
      return result == GameResult.clear ? '$elementTitle・踏破者' : elementTitle;
    }

    final base = _traitTitles[top.first.key] ?? '心の旅人';
    return result == GameResult.clear ? '迷宮を制した$base' : base;
  }

  static const Map<String, String> _traitTitles = {
    '挑戦性': '無謀な開拓者',
    '慎重性': '慎重な観察者',
    '好奇心': '未知を求める者',
    '計画性': '思慮深い策士',
    '直感性': '直感のままに進む者',
    '論理性': '冷静な分析者',
    '協調性': '仲間と歩む者',
    '利他性': '仲間想いの旅人',
    '執着性': '最後まで進む者',
    '柔軟性': '流れに乗る者',
  };

  static const Map<String, String> _elementTitles = {
    '炎': '最後まで進む炎',
    '水': '人を包む水',
    '風': '風のように動く者',
    '土': '揺るがぬ大地の者',
    '雷': '稲妻のごとき者',
    '氷': '静かに見極める氷',
    '光': '道を照らす者',
    '闇': '闇を覗く者',
  };
}
