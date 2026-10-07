import 'package:flutter/material.dart';

/// バッジ診断のバッジ（5つの性格軸 × 第1弾・第2弾）
///
/// キーは Cloud Functions の `src/personality/badgeQuestions.js` と共通。
/// 設計は `shared/docs/functions/バッジ診断_設計書.md`。
class BadgeDef {
  final String key;
  final String axis;
  final int round;
  final String name;

  /// 何を測るバッジかの短い説明（バッジ画面に出す）
  final String description;
  final IconData icon;

  const BadgeDef({
    required this.key,
    required this.axis,
    required this.round,
    required this.name,
    required this.description,
    required this.icon,
  });

  String get label => '$nameバッジ';
}

/// 1つのバッジに答える質問の数
const int kQuestionsPerBadge = 2;

const _axisDescriptions = {
  'energy': 'ひとりの時間と、人と過ごす時間',
  'judgment': '気持ちと理屈、どちらで決めるか',
  'processing': '直感と分析、どちらで考えるか',
  'relationship': '自分のやり方と、周りとの協調',
  'lifestyle': '計画と、その場の流れ',
};

const _axisIcons = {
  'energy': Icons.groups_rounded,
  'judgment': Icons.favorite_rounded,
  'processing': Icons.lightbulb_rounded,
  'relationship': Icons.handshake_rounded,
  'lifestyle': Icons.flag_rounded,
};

const kBadgeAxes = ['energy', 'judgment', 'processing', 'relationship', 'lifestyle'];

const _round1Names = {
  'energy': 'つながり',
  'judgment': 'こころ',
  'processing': 'ひらめき',
  'relationship': 'きずな',
  'lifestyle': 'あゆみ',
};

// 第2弾は第1弾より深い印象の名前にする
const _round2Names = {
  'energy': '共鳴',
  'judgment': '心核',
  'processing': '洞察',
  'relationship': '信頼',
  'lifestyle': '道標',
};

/// 弾ごとのバッジ一覧（並び順はホームとバッジ画面の表示順）
List<BadgeDef> badgesOfRound(int round) => [
      for (final axis in kBadgeAxes)
        BadgeDef(
          key: 'r${round}_$axis',
          axis: axis,
          round: round,
          name: (round == 1 ? _round1Names : _round2Names)[axis]!,
          description: _axisDescriptions[axis]!,
          icon: _axisIcons[axis]!,
        ),
    ];

final Map<String, BadgeDef> kBadges = {
  for (final b in [...badgesOfRound(1), ...badgesOfRound(2)]) b.key: b,
};
