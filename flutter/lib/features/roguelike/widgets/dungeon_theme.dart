// features/roguelike/widgets/dungeon_theme.dart
//
// ローグライク画面で共有する配色。ダンジョン/敵のテーマカラーは
// その悩み（ボス）の元素に対応する本編の元素カラー（`ElementType.color`）に揃える。

import 'package:flutter/material.dart';
import '../models/dungeon.dart';
import '../models/enemy.dart';

const kRoguelikeBg = Color(0xFF2B2347);
const kRoguelikePink = Color(0xFFE08AAE);
const kRoguelikeInk = Color(0xFF4A4A5A);

/// カード背景色。純白だとグラデ背景から浮きすぎるため、グレーに落とす。
const kRoguelikeCard = Color(0xFFDED9E8);

/// ローグライク画面共通の背景グラデーション。
/// 上＝ダンジョンらしい夜の紫、下＝本編に合わせた薄ピンク。
const kRoguelikeBgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF2B2347), Color(0xFF4A3A5E), Color(0xFFF7D7E6)],
  stops: [0.0, 0.5, 1.0],
);

/// 元素（単漢字）→ 本編の元素カラー（`ElementType.color` と一致）。
Color elementColor(String element) => switch (element) {
      '炎' => const Color(0xFFE53935), // 赤
      '水' => const Color(0xFF1E88E5), // 青
      '風' => const Color(0xFF43A047), // 緑
      '土' => const Color(0xFF8D6E63), // 茶
      '氷' => const Color(0xFF4FC3F7), // 水色
      '雷' => const Color(0xFFFDD835), // 黄
      '光' => const Color(0xFFFFB300), // 金
      '闇' => const Color(0xFF6A1B9A), // 紫
      _    => const Color(0xFF9E9E9E), // 無・不明：グレー
    };

/// 元素カラーの上に乗せる文字色（明るい色は黒、暗い色は白）。
Color elementInk(Color c) => c.computeLuminance() > 0.5 ? const Color(0xFF333333) : Colors.white;

/// 悩み（ダンジョン）/ボスの id に対応するテーマカラー＝そのダンジョンの元素色。
Color dungeonColor(String id) => elementColor(Dungeons.byId(id).boss.element);

// --- 敵の表示ヘルパー（図鑑・敵詳細で共用） ---

/// キャラクター画像を持つ敵 id（assets/images/roguelike_enemies/{id}.png）。
/// ボス11体＋固有ザコ11体＋共通ザコ3体。これ以外は絵文字フォールバック。
const _enemyImageIds = {
  // ボス（＝ダンジョンid）
  'interpersonal', 'future_anxiety', 'self_denial', 'fear_of_judgment',
  'loneliness', 'impatience', 'anger', 'hesitation',
  'perfectionism', 'procrastination', 'inner_labyrinth',
  // 固有ザコ
  'awkward_silence', 'vague_worry', 'self_nagging', 'eyes', 'emptiness',
  'rushing_voice', 'irritation', 'two_paths', 'nitpicking', 'later', 'lingering_doubt',
  // 共通ザコ
  'haze', 'small_unease', 'idle_thoughts',
};

/// id に対応する敵キャラ画像のアセットパス。無ければ null（絵文字で代替）。
String? enemyImageAsset(String id) =>
    _enemyImageIds.contains(id) ? 'assets/images/roguelike_enemies/$id.png' : null;

/// 敵アート。画像があれば cover 表示、無ければ絵文字。未遭遇(seen=false)は「？」。
/// 角丸クリップは呼び出し側のコンテナ（clipBehavior: Clip.antiAlias）に任せる。
Widget enemyArt({required String id, required String emoji, required double size, bool seen = true}) {
  final asset = seen ? enemyImageAsset(id) : null;
  if (asset != null) {
    // 透過PNGなので contain で全身を収め、背景（コンテナのグラデ）を透かす。
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.5))),
    );
  }
  return Center(
    child: Text(seen ? emoji : '？', style: TextStyle(fontSize: size * 0.5, color: seen ? null : Colors.grey)),
  );
}

/// 敵の絵文字。ボスは対応ダンジョンの絵文字、ザコは共通の💭。
String enemyEmoji(Enemy e) {
  if (e.isBoss) {
    for (final d in Dungeons.all) {
      if (d.boss.id == e.id) return d.emoji;
    }
  }
  return '💭';
}

/// 敵のアート色＝その敵の元素色（共通ザコ＝無＝グレー）。
Color enemyColor(Enemy e) => elementColor(e.element);

/// 敵の特徴（反撃・蝕み・escalates・fleeWorsens・封じ）を文言化。
List<String> enemyTraits(Enemy e) {
  final t = <String>[];
  final d = e.counterDrain;
  if ((d['bond'] ?? 0) < 0) t.add('反撃で絆を蝕む');
  if ((d['food'] ?? 0) < 0) t.add('反撃で食料を奪う');
  if ((d['money'] ?? 0) < 0) t.add('反撃で金貨を奪う');
  if ((d['items'] ?? 0) < 0) t.add('反撃で回復薬を奪う');
  if (e.escalates) t.add('長引くほど強くなる');
  if (e.fleeWorsens) t.add('逃げると悪化する');
  if (e.trait == EnemyTrait.selfDenial) t.add('強い手を封じてくる');
  if (e.counterBaseDamage >= 4 && !t.any((x) => x.startsWith('反撃'))) t.add('反撃が痛い');
  return t;
}

/// ドロップ報酬（撃破報酬）を絵文字付きで文言化。
List<String> enemyDrops(Enemy e) {
  const labels = {'money': '💰金貨', 'food': '🍞食料', 'items': '🧪回復薬', 'hp': '❤️HP', 'maxHp': '💗最大HP'};
  final out = <String>[];
  e.defeatReward.forEach((k, v) {
    if (v != 0) out.add('${labels[k] ?? k}+$v');
  });
  return out;
}
