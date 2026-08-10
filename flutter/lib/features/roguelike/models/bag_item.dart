// features/roguelike/models/bag_item.dart

import 'equipment.dart';

/// 回復薬の鞄内ID（装備ではないので `Equipments` には無い）。
const String kPotionId = 'potion';

/// 宝の地図の鞄内ID。使うと宝箱の位置が判明する。
const String kTreasureMapId = 'treasure_map';

/// 回復薬1つで回復するHP量。
/// 戦闘中の「回復薬を使う」（`Enemies.healChoice`）と同じ値に揃える。
const int kPotionHealAmount = 12;

/// 鞄の中身1つ分。
///
/// **武器・防具・回復薬・宝の地図はすべて1つにつき1枠を消費する。**
/// 装備中の武器・防具も枠を使う（鞄の外に置かない）。
/// 枠を食うからこそ「強さを取るか、備えを取るか」の判断が生まれる。
class BagItem {
  final String id;

  /// 装備中か。武器・防具でのみ意味を持つ（回復薬・地図では常に false）。
  final bool equipped;

  const BagItem(this.id, {this.equipped = false});

  BagItem copyWith({bool? equipped}) =>
      BagItem(id, equipped: equipped ?? this.equipped);

  /// 装備なら対応する `Equipment`、回復薬・地図なら null。
  Equipment? get equipment => Equipments.byId(id);

  bool get isPotion => id == kPotionId;
  bool get isTreasureMap => id == kTreasureMapId;
  bool get isEquipment => equipment != null;

  String get name => switch (id) {
        kPotionId => '回復薬',
        kTreasureMapId => '宝の地図',
        _ => equipment?.name ?? '？',
      };

  String get emoji => switch (id) {
        kPotionId => '🧪',
        kTreasureMapId => '🗺️',
        _ => equipment?.emoji ?? '❔',
      };

  /// 効果の短い説明（回復薬・地図は用途）。
  String get effectLabel => switch (id) {
        kPotionId => 'HP回復',
        kTreasureMapId => '宝箱の位置が分かる',
        _ => equipment?.effectLabel ?? '',
      };

  /// 種別バッジの文言。
  String get categoryLabel => switch (id) {
        kPotionId => '回復アイテム',
        kTreasureMapId => '探索アイテム',
        _ => equipment?.kind == EquipKind.weapon ? '武器' : '防具',
      };

  /// 詳細パネルに出す説明文。
  String get description => switch (id) {
        kPotionId => '飲むと傷が癒える薬。\n戦っている最中でも使える。',
        kTreasureMapId => '宝箱の在りかが記された地図。\n使うと盤面の宝箱が見えるようになる。',
        'branch' => 'その辺で拾った手頃な枝。\n無いよりはずっとましだ。',
        'iron_sword' => '扱いやすい鉄の剣。\nひと振りの重みが心を落ち着ける。',
        'master_sword' => '名工が鍛えたひと振り。\n迷いごと断ち切れそうな切れ味。',
        'cloth_armor' => '厚手の布を重ねた服。\n無防備よりはずっと心強い。',
        'iron_armor' => '鉄を打ち出した鎧。\n重いが、その重さが守ってくれる。',
        'holy_robe' => '祈りが編み込まれたローブ。\n身にまとうと不思議と落ち着く。',
        _ => '',
      };

  /// 効果の数値表記（詳細パネル用）。
  String get effectDetail => switch (id) {
        kPotionId => '回復量：HP +$kPotionHealAmount',
        kTreasureMapId => '効果：宝箱の位置が判明',
        _ => equipment == null
            ? ''
            : (equipment!.kind == EquipKind.weapon
                ? '与ダメージ +${equipment!.power}'
                : '被ダメージ -${equipment!.power}'),
      };

  /// 買値（金貨）。
  static int priceOf(String id) => switch (id) {
        kPotionId => 3,
        kTreasureMapId => 2,
        _ => Equipments.byId(id)?.price ?? 0,
      };

  /// 売値（金貨）。**買値の半分・端数切り捨て。**
  /// 買値 > 売値が全アイテムで成立するため、売買を繰り返して金貨を
  /// 増やす抜け穴は生じない。
  static int sellPriceOf(String id) => priceOf(id) ~/ 2;

  int get price => priceOf(id);
  int get sellPrice => sellPriceOf(id);
}
