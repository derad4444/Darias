// features/roguelike/models/equipment.dart

/// 装備の種別。武器＝与ダメ増加 / 防具＝被ダメ軽減。
enum EquipKind { weapon, armor }

/// 冒険中に装備する武器・防具。効果は固定値（`power`）。
/// ランごとにリセット（`GameState.initial` では未装備＝null）。
/// 武器/防具それぞれスロット1つで、より強い物を入手したら乗り換える。
class Equipment {
  final String id;
  final String name;
  final EquipKind kind;
  final int power; // 武器＝与ダメ+power / 防具＝被ダメ-power
  final int price; // 行商人での価格（金貨）

  const Equipment({
    required this.id,
    required this.name,
    required this.kind,
    required this.power,
    required this.price,
  });

  String get emoji => kind == EquipKind.weapon ? '⚔️' : '🛡️';

  /// 効果の短い説明（例「攻撃+3」「被ダメ-2」）。
  String get effectLabel =>
      kind == EquipKind.weapon ? '攻撃+$power' : '被ダメ-$power';
}

/// 装備カタログ。武器・防具それぞれ3ランク（固定値）。
class Equipments {
  // 武器（与ダメ+）
  static const branch = Equipment(id: 'branch', name: '木の枝', kind: EquipKind.weapon, power: 1, price: 2);
  static const ironSword = Equipment(id: 'iron_sword', name: '鉄の剣', kind: EquipKind.weapon, power: 3, price: 5);
  static const masterSword = Equipment(id: 'master_sword', name: '名刀', kind: EquipKind.weapon, power: 5, price: 9);

  // 防具（被ダメ-）
  static const clothArmor = Equipment(id: 'cloth_armor', name: '布の服', kind: EquipKind.armor, power: 1, price: 2);
  static const ironArmor = Equipment(id: 'iron_armor', name: '鉄の鎧', kind: EquipKind.armor, power: 2, price: 5);
  static const holyRobe = Equipment(id: 'holy_robe', name: '聖なるローブ', kind: EquipKind.armor, power: 3, price: 9);

  static const weapons = [branch, ironSword, masterSword];
  static const armors = [clothArmor, ironArmor, holyRobe];
  static const all = [...weapons, ...armors];

  static Equipment? byId(String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }
}
