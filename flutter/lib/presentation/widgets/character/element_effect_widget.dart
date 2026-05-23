import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../presentation/providers/theme_provider.dart';

enum ElementType {
  none(    '無属性', Color(0xFF9E9E9E), 1),
  fire(    '炎属性', Color(0xFFE53935), 3),
  water(   '水属性', Color(0xFF1E88E5), 1),
  wind(    '風属性', Color(0xFF43A047), 3),
  earth(   '土属性', Color(0xFF8D6E63), 1),
  ice(     '氷属性', Color(0xFF4FC3F7), 1),
  thunder( '雷属性', Color(0xFFFDD835), 4),
  light(   '光属性', Color(0xFFFFB300), 4),
  dark(    '闇属性', Color(0xFF6A1B9A), 3);

  const ElementType(this.label, this.color, this.defaultPattern);
  final String label;
  final Color color;
  /// ユーザーが選択した確定パターン番号
  final int defaultPattern;
}

const int kMaxPatterns = 5;

// Firestoreの元素文字列（例: "炎"）→ ElementType 変換
ElementType? elementTypeFromString(String? element) {
  switch (element) {
    case '炎': return ElementType.fire;
    case '水': return ElementType.water;
    case '風': return ElementType.wind;
    case '土': return ElementType.earth;
    case '氷': return ElementType.ice;
    case '雷': return ElementType.thunder;
    case '光': return ElementType.light;
    case '闇': return ElementType.dark;
    case '無': return ElementType.none;
    default:   return null;
  }
}

/// signalCount・element・gender から成長段階のローカルアセットパスを返す
String characterGrowthAssetPath({
  required int signalCount,
  required String? element,
  required String? gender,
}) {
  if (signalCount < 30 || element == null) {
    return 'assets/images/character_growth/赤ちゃん.png';
  }
  if (signalCount < 100) {
    return 'assets/images/character_growth/幼少期_$element.png';
  }
  final g = gender == '男性' ? '男性' : '女性';
  return 'assets/images/character_growth/成人_${g}_$element.png';
}

class ElementEffectWidget extends StatefulWidget {
  final ElementType element;
  /// 省略すると element.defaultPattern（ユーザー確定パターン）を使用
  final int? pattern;

  const ElementEffectWidget({
    super.key,
    required this.element,
    this.pattern,
  });

  @override
  State<ElementEffectWidget> createState() => _ElementEffectWidgetState();
}

class _ElementEffectWidgetState extends State<ElementEffectWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void didUpdateWidget(ElementEffectWidget old) {
    super.didUpdateWidget(old);
    final oldP = old.pattern ?? old.element.defaultPattern;
    final newP = widget.pattern ?? widget.element.defaultPattern;
    if (old.element != widget.element || oldP != newP) {
      _ctrl.reset();
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: Size.infinite,
        painter: _buildPainter(
            widget.element,
            widget.pattern ?? widget.element.defaultPattern,
            _ctrl.value),
      ),
    );
  }
}

CustomPainter _buildPainter(ElementType el, int p, double t) {
  switch (el) {
    case ElementType.none:
      return [_NoneP1(t), _NoneP2(t), _NoneP3(t), _NoneP4(t), _NoneP5(t)][p.clamp(1, 5) - 1];
    case ElementType.fire:
      return [_FireP1(t), _FireP2(t), _FireP3(t), _FireP4(t), _FireP5(t)][p.clamp(1, 5) - 1];
    case ElementType.water:
      return [_WaterP1(t), _WaterP2(t), _WaterP3(t), _WaterP4(t), _WaterP5(t)][p.clamp(1, 5) - 1];
    case ElementType.wind:
      return [_WindP1(t), _WindP2(t), _WindP3(t), _WindP4(t), _WindP5(t)][p.clamp(1, 5) - 1];
    case ElementType.earth:
      return [_EarthP1(t), _EarthP2(t), _EarthP3(t), _EarthP4(t), _EarthP5(t)][p.clamp(1, 5) - 1];
    case ElementType.ice:
      return [_IceP1(t), _IceP2(t), _IceP3(t), _IceP4(t), _IceP5(t)][p.clamp(1, 5) - 1];
    case ElementType.thunder:
      return [_ThunderP1(t), _ThunderP2(t), _ThunderP3(t), _ThunderP4(t), _ThunderP5(t)][p.clamp(1, 5) - 1];
    case ElementType.light:
      return [_LightP1(t), _LightP2(t), _LightP3(t), _LightP4(t), _LightP5(t)][p.clamp(1, 5) - 1];
    case ElementType.dark:
      return [_DarkP1(t), _DarkP2(t), _DarkP3(t), _DarkP4(t), _DarkP5(t)][p.clamp(1, 5) - 1];
  }
}

// ─── 共通ユーティリティ ─────────────────────────────
Paint _blurPaint(Color color, double blur) =>
    Paint()..color = color..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

Paint _strokePaint(Color color, double width, double blur) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

// ══════════════════════════════════════════════════════
// 無属性 — 淡いラベンダー / シルバー
// ══════════════════════════════════════════════════════

/// P1: 柔らかいオーラがパルス
class _NoneP1 extends CustomPainter {
  final double t;
  _NoneP1(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height * .45);
    final pulse = .5 + .5 * sin(t * pi * 2);
    final r = s.width * (.50 + .04 * pulse);
    final op = .18 + .12 * pulse;
    canvas.drawCircle(c, r,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withAlpha((op * 255).toInt()),
            const Color(0xFFCE93D8).withAlpha((op * .6 * 255).toInt()),
            Colors.transparent,
          ], stops: const [0, .55, 1]).createShader(Rect.fromCircle(center: c, radius: r))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
  }

  @override
  bool shouldRepaint(_NoneP1 o) => o.t != t;
}

/// P2: 8つの星がランダムに瞬く
class _NoneP2 extends CustomPainter {
  final double t;
  _NoneP2(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .45;
    for (int i = 0; i < 8; i++) {
      final b = i / 8.0;
      final angle = b * pi * 2 + t * .6 * pi;
      final r = s.width * (.38 + .06 * sin(b * 5.1));
      final x = cx + r * cos(angle), y = cy + r * .75 * sin(angle);
      final tw = .5 + .5 * sin(t * pi * 2 * (1.3 + b * .7) + b * 9);
      final sz = 3.0 + 4.0 * tw;
      final p = Paint()
        ..color = const Color(0xFFE1BEE7).withAlpha(((0.3 + .65 * tw) * 255).toInt())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      for (int j = 0; j < 4; j++) {
        final a = j * pi / 4;
        canvas.drawLine(Offset(x + cos(a) * sz, y + sin(a) * sz),
            Offset(x - cos(a) * sz, y - sin(a) * sz), p..strokeWidth = 1.5);
      }
      canvas.drawCircle(Offset(x, y), sz * .4, p);
    }
  }

  @override
  bool shouldRepaint(_NoneP2 o) => o.t != t;
}

/// P3: 楕円リングが広がってフェード
class _NoneP3 extends CustomPainter {
  final double t;
  _NoneP3(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height * .45);
    for (int i = 0; i < 3; i++) {
      final ph = (t * .6 + i / 3.0) % 1.0;
      final r = s.width * (.22 + .32 * ph);
      canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 2, height: r * 1.3),
          _strokePaint(
              const Color(0xFFCE93D8).withAlpha(((1 - ph) * .5 * 255).toInt()),
              2.0 - 1.5 * ph,
              5));
    }
  }

  @override
  bool shouldRepaint(_NoneP3 o) => o.t != t;
}

/// P4: シルバーの光子がゆっくり漂う
class _NoneP4 extends CustomPainter {
  final double t;
  static const int _n = 16;
  _NoneP4(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .45;
    for (int i = 0; i < _n; i++) {
      final seed = i * 2.399;
      final driftT = (t * .5 + i / _n) % 1.0;
      final angle = seed * pi * 2 + sin(driftT * pi * 2) * .6;
      final r = s.width * (.2 + .22 * sin(seed * 1.7)) + sin(driftT * pi) * s.width * .08;
      final x = cx + r * cos(angle), y = cy + r * .8 * sin(angle);
      final op = sin(driftT * pi) * .7;
      canvas.drawCircle(Offset(x, y), 2.5 + 1.5 * sin(seed),
          _blurPaint(Colors.white.withAlpha((op * 255).toInt()), 3));
    }
  }

  @override
  bool shouldRepaint(_NoneP4 o) => o.t != t;
}

/// P5: 銀の粉が上から降り注ぐ
class _NoneP5 extends CustomPainter {
  final double t;
  static const int _n = 22;
  _NoneP5(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    for (int i = 0; i < _n; i++) {
      final seed = i * 1.618;
      final ph = (t * .7 + i / _n) % 1.0;
      final x = cx + sin(seed * 4.1) * s.width * .38;
      final y = s.height * ph;
      final op = sin(ph * pi) * .75;
      canvas.drawCircle(Offset(x, y), 1.5 + 2.0 * sin(seed * 2.1),
          _blurPaint(Color.lerp(Colors.white, const Color(0xFFCE93D8), ph)!
              .withAlpha((op * 255).toInt()), 2));
    }
  }

  @override
  bool shouldRepaint(_NoneP5 o) => o.t != t;
}

// ══════════════════════════════════════════════════════
// 炎属性
// ══════════════════════════════════════════════════════

/// P1: 炎の柱 — 粒子が上昇
class _FireP1 extends CustomPainter {
  final double t;
  static const int _n = 22;
  _FireP1(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, baseY = s.height * .88;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, baseY), width: s.width * .45, height: s.height * .08),
        _blurPaint(const Color(0xFFFF6B35).withAlpha(100), 12));
    for (int i = 0; i < _n; i++) {
      final ph = (t + i / _n) % 1.0;
      final seed = i * 2.399;
      final x = cx + sin(seed) * s.width * .18 +
          sin(seed * 1.7 + t * pi * 4) * s.width * .06 * ph;
      final y = baseY - s.height * .55 * ph;
      canvas.drawCircle(Offset(x, y),
          (5.0 + 6.0 * (1 - ph)) * (.7 + .3 * sin(seed)),
          _blurPaint(
              Color.lerp(const Color(0xFFFFD740), const Color(0xFFDD2C00), ph)!
                  .withAlpha(((1 - ph) * .85 * 255).toInt()), 4));
    }
  }

  @override
  bool shouldRepaint(_FireP1 o) => o.t != t;
}

/// P2: 爆発放射 — 全方向に炎が弾ける
class _FireP2 extends CustomPainter {
  final double t;
  static const int _n = 30;
  _FireP2(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .5;
    final burst = .5 + .5 * sin(t * pi * 2 * 1.5);
    canvas.drawCircle(Offset(cx, cy), s.width * .15 * (.8 + .2 * burst),
        _blurPaint(const Color(0xFFFFFFE0).withAlpha((180 * burst).toInt()), 14));
    for (int i = 0; i < _n; i++) {
      final ph = (t * 1.2 + i / _n) % 1.0;
      final seed = i * 2.399;
      final r = s.width * .48 * ph;
      canvas.drawCircle(
          Offset(cx + r * cos(seed * pi * 2), cy + r * .8 * sin(seed * pi * 2)),
          (6.0 * (1 - ph)).clamp(.5, 8.0),
          _blurPaint(
              Color.lerp(const Color(0xFFFFE57F), const Color(0xFFE64A19), ph)!
                  .withAlpha(((1 - ph) * .9 * 255).toInt()), 3));
    }
  }

  @override
  bool shouldRepaint(_FireP2 o) => o.t != t;
}

/// P3: 腰まわりを炎のリングが回転
class _FireP3 extends CustomPainter {
  final double t;
  static const int _n = 24;
  _FireP3(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .62;
    for (int i = 0; i < _n; i++) {
      final angle = (i / _n + t * .8) * pi * 2;
      final pulse = .5 + .5 * sin(i / _n * pi * 6 + t * pi * 8);
      canvas.drawCircle(
          Offset(cx + s.width * .42 * cos(angle), cy + s.height * .07 * sin(angle)),
          5.0 + 4.0 * pulse,
          _blurPaint(
              Color.lerp(const Color(0xFFFF6D00), const Color(0xFFFFD600), pulse)!
                  .withAlpha(((.5 + .4 * pulse) * 255).toInt()), 5));
    }
  }

  @override
  bool shouldRepaint(_FireP3 o) => o.t != t;
}

/// P4: 残り火が散る — 高くから炎塵が降る
class _FireP4 extends CustomPainter {
  final double t;
  static const int _n = 25;
  _FireP4(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    // 下のグロー
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, s.height * .88), width: s.width * .5, height: s.height * .07),
        _blurPaint(const Color(0xFFFF6B35).withAlpha(70), 15));
    for (int i = 0; i < _n; i++) {
      final seed = i * 2.399;
      // 高所から放物線で落ちる
      final ph = (t * .9 + i / _n) % 1.0;
      final xOff = sin(seed * 3.7) * s.width * .35;
      final vx = cos(seed) * s.width * .04;
      final x = cx + xOff + vx * ph * 10;
      final y = s.height * .1 + s.height * .75 * ph + s.height * .3 * ph * ph;
      if (y > s.height) continue;
      final op = (1 - ph) * .8;
      canvas.drawCircle(Offset(x, y), 2.0 + 2.5 * (1 - ph),
          _blurPaint(
              Color.lerp(const Color(0xFFFFD740), const Color(0xFFBF360C), ph)!
                  .withAlpha((op * 255).toInt()), 3));
    }
  }

  @override
  bool shouldRepaint(_FireP4 o) => o.t != t;
}

/// P5: 細い炎柱が集中して上昇 (コアビーム)
class _FireP5 extends CustomPainter {
  final double t;
  static const int _n = 18;
  _FireP5(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    // 中心の強いグロー
    final pulse = .5 + .5 * sin(t * pi * 2 * 2);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, s.height / 2),
            width: s.width * .08, height: s.height),
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                const Color(0xFFFF6D00).withAlpha(180),
                const Color(0xFFFFD600).withAlpha((200 * pulse).toInt()),
                Colors.transparent,
              ],
              stops: const [0, .4, 1]).createShader(Rect.fromLTWH(0, 0, s.width, s.height))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    for (int i = 0; i < _n; i++) {
      final ph = (t * 1.3 + i / _n) % 1.0;
      final sway = sin(i * 2.1 + t * pi * 6) * s.width * .03;
      final x = cx + sway;
      final y = s.height * .9 - s.height * .8 * ph;
      canvas.drawCircle(Offset(x, y), (4.0 * (1 - ph)).clamp(.5, 4),
          _blurPaint(
              Color.lerp(const Color(0xFFFFFFE0), const Color(0xFFFF6D00), ph)!
                  .withAlpha(((1 - ph) * .9 * 255).toInt()), 4));
    }
  }

  @override
  bool shouldRepaint(_FireP5 o) => o.t != t;
}

// ══════════════════════════════════════════════════════
// 水属性
// ══════════════════════════════════════════════════════

/// P1: 波紋リング＋泡
class _WaterP1 extends CustomPainter {
  final double t;
  _WaterP1(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .5;
    for (int i = 0; i < 3; i++) {
      final ph = (t + i / 3.0) % 1.0;
      final r = s.width * .25 + s.width * .32 * ph;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 1.3),
          _strokePaint(const Color(0xFF29B6F6).withAlpha(((1 - ph) * .55 * 255).toInt()),
              2.5 - 1.5 * ph, 3));
    }
    for (int i = 0; i < 14; i++) {
      final seed = i * 1.618;
      final ph = (t * .9 + i / 14.0) % 1.0;
      final x = cx + sin(seed * 3.1) * s.width * .22;
      final y = s.height * .85 - s.height * .65 * ph;
      canvas.drawCircle(Offset(x, y), 3.0 + 4.0 * sin(seed),
          Paint()
            ..color = const Color(0xFF81D4FA).withAlpha((sin(ph * pi) * .6 * 255).toInt())
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
    }
  }

  @override
  bool shouldRepaint(_WaterP1 o) => o.t != t;
}

/// P2: 上から雨粒が降る
class _WaterP2 extends CustomPainter {
  final double t;
  static const int _n = 20;
  _WaterP2(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    for (int i = 0; i < _n; i++) {
      final seed = i * 1.618;
      final ph = (t * 1.1 + i / _n) % 1.0;
      final x = cx + sin(seed * 4.1) * s.width * .45;
      final y = s.height * ph;
      final op = sin(ph * pi) * .7;
      canvas.drawLine(Offset(x, y), Offset(x + 2, y + 10.0 + 8.0 * sin(seed)),
          _strokePaint(const Color(0xFF4FC3F7).withAlpha((op * 255).toInt()), 1.5, 1));
      if (ph > .85) {
        final sp = (ph - .85) / .15;
        canvas.drawOval(
            Rect.fromCenter(center: Offset(x, s.height * .92),
                width: s.width * .06 * sp, height: s.height * .01 * sp),
            Paint()
              ..color = const Color(0xFF81D4FA).withAlpha(((1 - sp) * 100).toInt())
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0);
      }
    }
  }

  @override
  bool shouldRepaint(_WaterP2 o) => o.t != t;
}

/// P3: キャラを包む螺旋水流
class _WaterP3 extends CustomPainter {
  final double t;
  static const int _n = 40;
  _WaterP3(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    for (int i = 0; i < _n; i++) {
      final base = i / _n;
      final ph = (base + t * .5) % 1.0;
      final angle = base * pi * 4 + t * pi * 2;
      final r = s.width * .32 * (.6 + .4 * sin(ph * pi));
      final x = cx + r * cos(angle), y = s.height * (.9 - .8 * ph);
      canvas.drawCircle(Offset(x, y), 3.0 + 2.0 * sin(base * pi * 2),
          _blurPaint(
              Color.lerp(const Color(0xFF00BCD4), const Color(0xFFE1F5FE), ph)!
                  .withAlpha((sin(ph * pi) * .75 * 255).toInt()), 2));
    }
  }

  @override
  bool shouldRepaint(_WaterP3 o) => o.t != t;
}

/// P4: 氷晶が現れて溶ける
class _WaterP4 extends CustomPainter {
  final double t;
  static const int _n = 10;
  _WaterP4(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .45;
    for (int i = 0; i < _n; i++) {
      final seed = i * 2.399;
      final ph = (t * .6 + i / _n) % 1.0;
      final r = s.width * (.2 + .25 * sin(seed * 1.7));
      final angle = seed * pi * 2;
      final x = cx + r * cos(angle), y = cy + r * .8 * sin(angle);
      final op = sin(ph * pi) * .65;
      final sz = 6.0 + 5.0 * sin(seed * 2.3);
      // 六角形の氷晶
      final path = Path();
      for (int j = 0; j < 6; j++) {
        final a = j * pi / 3 + t * .5;
        final px = x + sz * cos(a), py = y + sz * sin(a);
        j == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
      }
      path.close();
      canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFB3E5FC).withAlpha((op * 255).toInt())
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      canvas.drawPath(path,
          Paint()..color = const Color(0xFFE1F5FE).withAlpha((op * .4 * 255).toInt()));
    }
  }

  @override
  bool shouldRepaint(_WaterP4 o) => o.t != t;
}

/// P5: 足元から波が広がる + 水しぶき
class _WaterP5 extends CustomPainter {
  final double t;
  _WaterP5(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, baseY = s.height * .88;
    // 水面波紋（水平）
    for (int i = 0; i < 4; i++) {
      final ph = (t * .7 + i / 4.0) % 1.0;
      final rw = s.width * (.1 + .45 * ph);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, baseY), width: rw * 2, height: rw * .3),
          _strokePaint(const Color(0xFF4FC3F7).withAlpha(((1 - ph) * .6 * 255).toInt()),
              2.0 - 1.5 * ph, 3));
    }
    // 水しぶき
    for (int i = 0; i < 12; i++) {
      final seed = i * 1.618;
      final ph = (t * 1.2 + i / 12.0) % 1.0;
      if (ph > .5) continue;
      final angle = seed * pi * 2 - pi / 2;
      final r = s.width * .25 * ph * 2;
      canvas.drawLine(
          Offset(cx, baseY),
          Offset(cx + r * cos(angle), baseY + r * sin(angle) * .4),
          _strokePaint(const Color(0xFF81D4FA).withAlpha(((1 - ph * 2) * .7 * 255).toInt()), 1.5, 2));
    }
  }

  @override
  bool shouldRepaint(_WaterP5 o) => o.t != t;
}

// ══════════════════════════════════════════════════════
// 風属性
// ══════════════════════════════════════════════════════

/// P1: 楕円軌道を旋回する粒子
class _WindP1 extends CustomPainter {
  final double t;
  static const int _n = 18;
  _WindP1(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .45;
    for (int i = 0; i < _n; i++) {
      final angle = (i / _n + t) * pi * 2;
      for (int j = 0; j < 5; j++) {
        final ta = angle - j * .18;
        final op = (1 - j / 5.0) * .7 * (.5 + .5 * sin(i / _n * 6 + t * 4));
        canvas.drawCircle(
            Offset(cx + s.width * .42 * cos(ta), cy + s.height * .35 * sin(ta)),
            (3.5 - j * .5).clamp(.5, 4.0),
            _blurPaint(const Color(0xFF81C784).withAlpha((op * 255).toInt()), 2));
      }
    }
  }

  @override
  bool shouldRepaint(_WindP1 o) => o.t != t;
}

/// P2: 横なぎの風ライン
class _WindP2 extends CustomPainter {
  final double t;
  static const int _n = 10;
  _WindP2(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    for (int i = 0; i < _n; i++) {
      final seed = i * 1.618;
      final ph = (t * (.6 + .4 * sin(seed)) + i / _n) % 1.0;
      final y = s.height * (.15 + .7 * (i / _n));
      final len = s.width * (.25 + .35 * sin(seed * 2));
      final x = -len + (s.width + len * 2) * ph;
      final op = sin(ph * pi) * .65;
      canvas.drawLine(Offset(x, y), Offset(x + len, y + sin(seed) * 8),
          _strokePaint(const Color(0xFFA5D6A7).withAlpha((op * 255).toInt()),
              1.5 + 2.0 * sin(seed * 1.3), 2));
    }
  }

  @override
  bool shouldRepaint(_WindP2 o) => o.t != t;
}

/// P3: 上昇する竜巻状の渦
class _WindP3 extends CustomPainter {
  final double t;
  static const int _n = 35;
  _WindP3(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    for (int i = 0; i < _n; i++) {
      final base = i / _n;
      final ph = (base + t * .7) % 1.0;
      final angle = base * pi * 5 - t * pi * 2.4;
      final r = s.width * .38 * (1 - ph * .7);
      canvas.drawCircle(
          Offset(cx + r * cos(angle), s.height * (.92 - .85 * ph)),
          2.5 + 2.0 * (1 - ph),
          _blurPaint(
              Color.lerp(const Color(0xFF69F0AE), const Color(0xFFF1F8E9), ph)!
                  .withAlpha((sin(ph * pi) * .7 * 255).toInt()), 2));
    }
  }

  @override
  bool shouldRepaint(_WindP3 o) => o.t != t;
}

/// P4: 花びらがキャラを中心にふわりと舞う
class _WindP4 extends CustomPainter {
  final double t;
  static const int _n = 14;
  _WindP4(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .45;
    for (int i = 0; i < _n; i++) {
      final seed = i * 2.399;
      final ph = (t * .5 + i / _n) % 1.0;
      final angle = seed * pi * 2 + t * pi * 1.5;
      final r = s.width * (.25 + .2 * sin(ph * pi));
      final x = cx + r * cos(angle), y = cy + r * .7 * sin(angle);
      final op = sin(ph * pi) * .7;
      final rot = angle + pi / 4;
      // 花びら（小判型）
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 10, height: 5),
          Paint()..color = const Color(0xFFA5D6A7).withAlpha((op * 255).toInt()));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_WindP4 o) => o.t != t;
}

/// P5: 衝撃波リング（素早く広がる水平輪）
class _WindP5 extends CustomPainter {
  final double t;
  _WindP5(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .55;
    for (int i = 0; i < 3; i++) {
      final ph = (t * 1.5 + i / 3.0) % 1.0;
      final rw = s.width * (.05 + .52 * ph);
      final op = (1 - ph) * .55;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: rw * 2, height: rw * .35),
          _strokePaint(const Color(0xFFC8E6C9).withAlpha((op * 255).toInt()),
              3.0 - 2.5 * ph, 4));
    }
  }

  @override
  bool shouldRepaint(_WindP5 o) => o.t != t;
}

// ══════════════════════════════════════════════════════
// 雷属性
// ══════════════════════════════════════════════════════

/// P1: 周囲に稲妻スパーク
class _ThunderP1 extends CustomPainter {
  final double t;
  _ThunderP1(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .45;
    final gp = sin(t * pi * 2 * 2.3).abs();
    if (gp > .3) {
      canvas.drawCircle(Offset(cx, cy), s.width * .48,
          _blurPaint(const Color(0xFFFFF176).withAlpha(((gp - .3) / .7 * .35 * 255).toInt()), 20));
    }
    for (int i = 0; i < 6; i++) {
      final seed = i * 1.23;
      final flash = sin(t * pi * 2 * (3.1 + seed) + seed * 7).abs();
      if (flash < .5) continue;
      final angle = seed * pi * 2 / 6 + t * pi;
      final sx = cx + s.width * .2 * cos(angle), sy = cy + s.width * .2 * sin(angle) * .7;
      final ex = cx + s.width * .42 * cos(angle), ey = cy + s.width * .42 * sin(angle) * .7;
      canvas.drawPath(
          Path()..moveTo(sx, sy)..lineTo((sx + ex) / 2 + sin(seed * 5 + t * 10) * 12, (sy + ey) / 2 + cos(seed * 4 + t * 8) * 10)..lineTo(ex, ey),
          _strokePaint(const Color(0xFFFFF176).withAlpha((flash * 230).toInt()), 1.5, 2));
    }
  }

  @override
  bool shouldRepaint(_ThunderP1 o) => o.t != t;
}

/// P2: 上から落ちる稲妻ボルト
class _ThunderP2 extends CustomPainter {
  final double t;
  _ThunderP2(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    for (int i = 0; i < 3; i++) {
      final seed = i * 2.1;
      final flash = sin(t * pi * 2 * (2.0 + seed * .7) + seed * 5).abs();
      if (flash < .4) continue;
      final op = (flash - .4) / .6;
      final startX = cx + sin(seed * 3.7) * s.width * .25;
      final path = Path()..moveTo(startX, 0);
      double x = startX;
      for (int seg = 0; seg < 8; seg++) {
        x += sin(seed * (seg + 1) * 4.1 + t * 20) * s.width * .07;
        path.lineTo(x, s.height * (seg + 1) / 8 * .9);
      }
      canvas.drawPath(path, Paint()..color = Colors.white.withAlpha((op * 230).toInt())..style = PaintingStyle.stroke..strokeWidth = 2.0..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawPath(path, Paint()..color = const Color(0xFFFFF176).withAlpha((op * 150).toInt())..style = PaintingStyle.stroke..strokeWidth = 5.0..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
  }

  @override
  bool shouldRepaint(_ThunderP2 o) => o.t != t;
}

/// P3: 中心から放射する電撃バースト
class _ThunderP3 extends CustomPainter {
  final double t;
  static const int _n = 12;
  _ThunderP3(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .45;
    final glow = .5 + .5 * sin(t * pi * 2 * 3);
    canvas.drawCircle(Offset(cx, cy), s.width * .08 * (.8 + .3 * glow),
        _blurPaint(Colors.white.withAlpha((180 * glow).toInt()), 10));
    for (int i = 0; i < _n; i++) {
      final seed = i * 2.399;
      final flash = sin(t * pi * 2 * (2.5 + seed * .3) + seed * 3).abs();
      if (flash < .3) continue;
      final op = (flash - .3) / .7;
      final angle = seed * pi * 2 / _n;
      final len = s.width * (.2 + .22 * flash);
      double x = cx, y = cy;
      final path = Path()..moveTo(x, y);
      for (int seg = 0; seg < 4; seg++) {
        x += cos(angle + sin(seed * (seg + 1) * 3.1) * .5) * len / 4;
        y += sin(angle + sin(seed * (seg + 1) * 2.7) * .5) * len / 4;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, _strokePaint(const Color(0xFFFFEE58).withAlpha((op * 220).toInt()), 1.8, 3));
    }
  }

  @override
  bool shouldRepaint(_ThunderP3 o) => o.t != t;
}

/// P4: テスラコイル — 固定点間を電弧が走る
class _ThunderP4 extends CustomPainter {
  final double t;
  _ThunderP4(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .45;
    // 5つの固定電極
    final poles = List.generate(5, (i) {
      final a = i / 5 * pi * 2;
      return Offset(cx + s.width * .4 * cos(a), cy + s.height * .32 * sin(a));
    });
    for (int i = 0; i < poles.length; i++) {
      final j = (i + 1) % poles.length;
      final flash = sin(t * pi * 2 * (3.7 + i * .5) + i * 2).abs();
      if (flash < .45) continue;
      final op = (flash - .45) / .55;
      final path = Path()..moveTo(poles[i].dx, poles[i].dy);
      for (int seg = 0; seg < 5; seg++) {
        final lp = (seg + 1) / 6;
        final mx = poles[i].dx + (poles[j].dx - poles[i].dx) * lp +
            sin(t * 20 + i * 3 + seg * 7) * 14;
        final my = poles[i].dy + (poles[j].dy - poles[i].dy) * lp +
            cos(t * 18 + i * 5 + seg * 6) * 10;
        path.lineTo(mx, my);
      }
      path.lineTo(poles[j].dx, poles[j].dy);
      canvas.drawPath(path, _strokePaint(const Color(0xFFE1F5FE).withAlpha((op * 200).toInt()), 1.5, 3));
      canvas.drawPath(path, _strokePaint(const Color(0xFFFFEE58).withAlpha((op * 100).toInt()), 4, 6));
    }
    // 電極の光点
    for (final p in poles) {
      canvas.drawCircle(p, 4, _blurPaint(const Color(0xFFFFF9C4).withAlpha(180), 5));
    }
  }

  @override
  bool shouldRepaint(_ThunderP4 o) => o.t != t;
}

/// P5: 常時ざわつく電場 — 全体に細かい放電
class _ThunderP5 extends CustomPainter {
  final double t;
  static const int _n = 20;
  _ThunderP5(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .45;
    // 全体オーラ
    final pulse = .5 + .5 * sin(t * pi * 4);
    canvas.drawCircle(Offset(cx, cy), s.width * .5,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFF176).withAlpha((40 * pulse).toInt()),
            const Color(0xFF1565C0).withAlpha(30),
            Colors.transparent
          ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: s.width * .5))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    for (int i = 0; i < _n; i++) {
      final seed = i * 1.618;
      final ph = (t * 2 + i / _n) % 1.0;
      final flash = sin(ph * pi).abs();
      if (flash < .4) continue;
      final r0 = s.width * .12, r1 = s.width * (.18 + .3 * sin(seed * 2.3));
      final angle = seed * pi * 2 + t * pi;
      canvas.drawLine(
          Offset(cx + r0 * cos(angle), cy + r0 * sin(angle) * .75),
          Offset(cx + r1 * cos(angle) + sin(seed * 8 + t * 15) * 8,
              cy + r1 * sin(angle) * .75 + cos(seed * 7 + t * 12) * 6),
          _strokePaint(const Color(0xFFFFF9C4).withAlpha((flash * .7 * 255).toInt()), 1.2, 2));
    }
  }

  @override
  bool shouldRepaint(_ThunderP5 o) => o.t != t;
}

// ══════════════════════════════════════════════════════
// 光属性
// ══════════════════════════════════════════════════════

/// P1: 回転する光線＋キラキラ
class _LightP1 extends CustomPainter {
  final double t;
  _LightP1(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .45;
    canvas.drawCircle(Offset(cx, cy), s.width * .35,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFF9C4).withAlpha(80), Colors.transparent
          ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: s.width * .35))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    for (int i = 0; i < 8; i++) {
      final angle = i / 8 * pi * 2 + t * pi * 2 * .3;
      final pulse = .5 + .5 * sin(t * pi * 2 + i);
      final len = s.width * (.25 + .08 * pulse);
      canvas.drawLine(
          Offset(cx + s.width * .12 * cos(angle), cy + s.width * .12 * sin(angle)),
          Offset(cx + len * cos(angle), cy + len * sin(angle)),
          _strokePaint(const Color(0xFFFFD54F).withAlpha(((.3 + .3 * pulse) * 255).toInt()), 2, 3));
    }
    for (int i = 0; i < 12; i++) {
      final seed = i * 2.399;
      final spt = (t * 1.5 + i / 12.0) % 1.0;
      final r = s.width * (.18 + .28 * sin(seed * 2.1));
      final angle = seed * pi * 2 + t * pi * .5;
      canvas.drawCircle(
          Offset(cx + r * cos(angle), cy + r * .8 * sin(angle)),
          2.5 * sin(spt * pi).abs(),
          _blurPaint(Colors.white.withAlpha((sin(spt * pi) * .9 * 255).toInt()), 2));
    }
  }

  @override
  bool shouldRepaint(_LightP1 o) => o.t != t;
}

/// P2: 同心円パルス放射
class _LightP2 extends CustomPainter {
  final double t;
  _LightP2(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .45;
    for (int i = 0; i < 3; i++) {
      final ph = (t + i / 3.0) % 1.0;
      canvas.drawCircle(Offset(cx, cy), s.width * .15 + s.width * .38 * ph,
          _strokePaint(const Color(0xFFFFF176).withAlpha(((1 - ph) * .6 * 255).toInt()),
              3.0 - 2.0 * ph, 6));
    }
    for (int i = 0; i < 16; i++) {
      final angle = i / 16 * pi * 2;
      final fl = .5 + .5 * sin(t * pi * 4 + i * .7);
      final len = s.width * (.08 + .1 * fl);
      canvas.drawLine(
          Offset(cx + s.width * .12 * cos(angle), cy + s.width * .12 * sin(angle)),
          Offset(cx + (s.width * .12 + len) * cos(angle), cy + (s.width * .12 + len) * sin(angle)),
          _strokePaint(Colors.white.withAlpha(((.3 + .5 * fl) * 255).toInt()), 1.5, 2));
    }
  }

  @override
  bool shouldRepaint(_LightP2 o) => o.t != t;
}

/// P3: 光粒子が降り注ぐ＋足元の輝き
class _LightP3 extends CustomPainter {
  final double t;
  static const int _n = 20;
  _LightP3(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final glow = .5 + .5 * sin(t * pi * 2);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, s.height * .88),
            width: s.width * .5 * (.9 + .1 * glow), height: s.height * .06),
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFF9C4).withAlpha((150 * glow).toInt()), Colors.transparent
          ]).createShader(Rect.fromCenter(center: Offset(cx, s.height * .88), width: s.width * .5, height: s.height * .06))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    for (int i = 0; i < _n; i++) {
      final seed = i * 2.399;
      final ph = (t * .8 + i / _n) % 1.0;
      canvas.drawCircle(
          Offset(cx + sin(seed * 3.7) * s.width * .4, s.height * ph),
          2.0 + 2.5 * sin(seed * 1.9),
          _blurPaint(
              Color.lerp(Colors.white, const Color(0xFFFFD54F), ph)!
                  .withAlpha((sin(ph * pi) * .85 * 255).toInt()), 2));
    }
  }

  @override
  bool shouldRepaint(_LightP3 o) => o.t != t;
}

/// P4: 十字の聖光ビーム
class _LightP4 extends CustomPainter {
  final double t;
  _LightP4(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .4;
    final pulse = .5 + .5 * sin(t * pi * 2);
    for (int i = 0; i < 4; i++) {
      final angle = i / 4 * pi * 2 + t * pi * .15;
      final len = s.width * (.38 + .06 * pulse);
      final op = .35 + .25 * pulse;
      canvas.drawLine(
          Offset(cx - cos(angle) * s.width * .04, cy - sin(angle) * s.width * .04),
          Offset(cx + cos(angle) * len, cy + sin(angle) * len),
          Paint()
            ..color = const Color(0xFFFFF9C4).withAlpha((op * 255).toInt())
            ..strokeWidth = 6.0 - i * .5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawLine(
          Offset(cx - cos(angle) * s.width * .04, cy - sin(angle) * s.width * .04),
          Offset(cx + cos(angle) * len * .6, cy + sin(angle) * len * .6),
          Paint()
            ..color = Colors.white.withAlpha(((op + .1) * 255).toInt())
            ..strokeWidth = 2.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
    canvas.drawCircle(Offset(cx, cy), s.width * .07 * (.8 + .2 * pulse),
        _blurPaint(Colors.white.withAlpha((200 * pulse).toInt()), 10));
  }

  @override
  bool shouldRepaint(_LightP4 o) => o.t != t;
}

/// P5: 太陽フレア — 片側から爆発する光
class _LightP5 extends CustomPainter {
  final double t;
  static const int _n = 20;
  _LightP5(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .35;
    // ゆっくり回転するフレア方向
    final flareAngle = t * pi * .4;
    final spread = pi * .6;
    for (int i = 0; i < _n; i++) {
      final seed = i * 2.399;
      final ph = (t * 1.1 + i / _n) % 1.0;
      final angle = flareAngle - spread / 2 + spread * (i / _n);
      final r = s.width * (.15 + .38 * ph);
      canvas.drawCircle(
          Offset(cx + r * cos(angle), cy + r * sin(angle)),
          (5.0 * (1 - ph)).clamp(.5, 6),
          _blurPaint(
              Color.lerp(Colors.white, const Color(0xFFFF8F00), ph)!
                  .withAlpha(((1 - ph) * .85 * 255).toInt()), 4));
    }
    canvas.drawCircle(Offset(cx, cy), s.width * .12,
        _blurPaint(const Color(0xFFFFF9C4).withAlpha(160), 15));
  }

  @override
  bool shouldRepaint(_LightP5 o) => o.t != t;
}

// ══════════════════════════════════════════════════════
// 闇属性
// ══════════════════════════════════════════════════════

/// P1: 外から内へ渦巻く粒子
class _DarkP1 extends CustomPainter {
  final double t;
  static const int _n = 20;
  _DarkP1(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .45;
    final pulse = .5 + .5 * sin(t * pi * 2 * .7);
    canvas.drawCircle(Offset(cx, cy), s.width * (.3 + .05 * pulse),
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFF6A1B9A).withAlpha(90), Colors.transparent
          ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: s.width * .35))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
    for (int i = 0; i < _n; i++) {
      final seed = i * 2.399;
      final ph = (t * .8 + i / _n) % 1.0;
      final angle = seed * pi * 2 - ph * pi * 4;
      final r = s.width * .48 * (1 - ph);
      canvas.drawCircle(
          Offset(cx + r * cos(angle), cy + r * .75 * sin(angle)),
          3.0 * (1 - ph) + 1.0,
          _blurPaint(
              Color.lerp(const Color(0xFFCE93D8), const Color(0xFF1A0030), ph)!
                  .withAlpha((sin(ph * pi) * .75 * 255).toInt()), 3));
    }
  }

  @override
  bool shouldRepaint(_DarkP1 o) => o.t != t;
}

/// P2: 地面から這い上がる闇の触手
class _DarkP2 extends CustomPainter {
  final double t;
  static const int _n = 5;
  _DarkP2(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    for (int i = 0; i < _n; i++) {
      final seed = i * 1.618;
      final ph = (t * .6 + i / _n) % 1.0;
      final baseX = cx + sin(seed * 5.1) * s.width * .3;
      final h = .3 + .5 * sin(ph * pi);
      final path = Path()..moveTo(baseX, s.height * .92);
      for (int seg = 1; seg <= 10; seg++) {
        final prog = seg / 10;
        path.lineTo(
            baseX + sin(seed * 3 + prog * 5 + t * 4) * s.width * .07 * prog,
            s.height * .92 - s.height * h * prog);
      }
      final op = sin(ph * pi) * .7;
      final w = 3.0 + 3.0 * sin(seed);
      for (int k = 0; k < 3; k++) {
        canvas.drawPath(path, Paint()
          ..color = Color.lerp(const Color(0xFF7B1FA2), Colors.black, k / 3)!
              .withAlpha(((op - k * .15).clamp(0, 1) * 255).toInt())
          ..style = PaintingStyle.stroke
          ..strokeWidth = w - k * .8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }
    }
  }

  @override
  bool shouldRepaint(_DarkP2 o) => o.t != t;
}

/// P3: 内向きに縮む闇リング（逆波紋）
class _DarkP3 extends CustomPainter {
  final double t;
  _DarkP3(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .45;
    for (int i = 0; i < 4; i++) {
      final ph = (t * .7 + i / 4.0) % 1.0;
      final r = s.width * .5 * (1 - ph);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 1.3),
          _strokePaint(const Color(0xFF9C27B0).withAlpha((ph * (1 - ph) * 4 * .6 * 255).toInt()), 2.5, 6));
    }
    final d = .5 + .5 * sin(t * pi * 2 * 1.3);
    canvas.drawCircle(Offset(cx, cy), s.width * .1 * d,
        _blurPaint(Colors.black.withAlpha((120 * d).toInt()), 12));
  }

  @override
  bool shouldRepaint(_DarkP3 o) => o.t != t;
}

/// P4: 暗い破片がキャラを旋回する
class _DarkP4 extends CustomPainter {
  final double t;
  static const int _n = 12;
  _DarkP4(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .45;
    for (int i = 0; i < _n; i++) {
      final seed = i * 2.399;
      final angle = seed * pi * 2 / _n - t * pi * 2;
      final r = s.width * (.3 + .1 * sin(seed * 1.7 + t * 3));
      final x = cx + r * cos(angle), y = cy + r * .75 * sin(angle);
      final sz = 4.0 + 3.0 * sin(seed * 2.1 + t * 4);
      final op = .5 + .3 * sin(seed + t * 3);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + t * 3);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: sz, height: sz * .6),
          Paint()
            ..color = Color.lerp(const Color(0xFF4A148C), Colors.black, .5)!
                .withAlpha((op * 255).toInt())
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DarkP4 o) => o.t != t;
}

/// P5: 深淵の眼 — 中心に引き込まれる暗黒渦
class _DarkP5 extends CustomPainter {
  final double t;
  static const int _n = 30;
  _DarkP5(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .45;
    // 深い紫の中心
    canvas.drawCircle(Offset(cx, cy), s.width * .2,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.black.withAlpha(200),
            const Color(0xFF4A148C).withAlpha(120),
            Colors.transparent,
          ], stops: const [0, .4, 1]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: s.width * .2))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    // 吸い込まれる渦粒子（外→内、反時計）
    for (int i = 0; i < _n; i++) {
      final seed = i * 2.399;
      final ph = (t * 1.1 + i / _n) % 1.0;
      final angle = seed * pi * 2 + ph * pi * 5; // 外から内へ回転
      final r = s.width * .5 * (1 - ph);
      final x = cx + r * cos(angle), y = cy + r * .75 * sin(angle);
      final op = sin(ph * pi) * .8;
      canvas.drawCircle(Offset(x, y), 2.5 * (1 - ph) + .5,
          _blurPaint(
              Color.lerp(const Color(0xFFBA68C8), Colors.black, ph)!
                  .withAlpha((op * 255).toInt()), 2));
    }
  }

  @override
  bool shouldRepaint(_DarkP5 o) => o.t != t;
}

// ══════════════════════════════════════════════════════
// 土属性 — ブラウン / アース
// ══════════════════════════════════════════════════════

/// P1: 土煙がゆっくり舞い上がる
class _EarthP1 extends CustomPainter {
  final double t;
  static const int _n = 18;
  _EarthP1(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, baseY = s.height * .88;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, baseY), width: s.width * .5, height: s.height * .06),
        _blurPaint(const Color(0xFF8D6E63).withAlpha(80), 12));
    for (int i = 0; i < _n; i++) {
      final seed = i * 2.399;
      final ph = (t * .55 + i / _n) % 1.0;
      final sway = sin(seed * 1.3 + t * pi * 2) * s.width * .04 * ph;
      final x = cx + sin(seed) * s.width * .22 + sway;
      final y = baseY - s.height * .38 * ph;
      final sz = (8.0 + 6.0 * sin(seed)) * (1 - ph * .7);
      final op = sin(ph * pi) * .55;
      canvas.drawCircle(Offset(x, y), sz,
          _blurPaint(Color.lerp(const Color(0xFF8D6E63), const Color(0xFFBCAAA4), ph)!
              .withAlpha((op * 255).toInt()), 6));
    }
  }
  @override bool shouldRepaint(_EarthP1 o) => o.t != t;
}

/// P2: 岩石の欠片がキャラを旋回する
class _EarthP2 extends CustomPainter {
  final double t;
  static const int _n = 10;
  _EarthP2(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .5;
    for (int i = 0; i < _n; i++) {
      final seed = i * 2.399;
      final angle = seed * pi * 2 / _n - t * pi * 1.5;
      final r = s.width * (.32 + .08 * sin(seed * 2.1 + t * 3));
      final x = cx + r * cos(angle), y = cy + r * .7 * sin(angle);
      final sz = 5.0 + 4.0 * sin(seed * 1.7);
      final op = .5 + .3 * sin(seed * 2 + t * 3);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle * 2 + t * 4);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: sz, height: sz * .7),
          Paint()..color = Color.lerp(const Color(0xFF6D4C41), const Color(0xFFBCAAA4), sin(seed) * .5 + .5)!
              .withAlpha((op * 255).toInt())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      canvas.restore();
    }
  }
  @override bool shouldRepaint(_EarthP2 o) => o.t != t;
}

/// P3: 地面から根/ツタが伸びる
class _EarthP3 extends CustomPainter {
  final double t;
  static const int _n = 6;
  _EarthP3(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    for (int i = 0; i < _n; i++) {
      final seed = i * 1.618;
      final ph = (t * .5 + i / _n) % 1.0;
      final baseX = cx + sin(seed * 4.1) * s.width * .3;
      final growH = s.height * .55 * sin(ph * pi);
      final path = Path()..moveTo(baseX, s.height * .9);
      for (int seg = 1; seg <= 8; seg++) {
        final prog = seg / 8;
        path.lineTo(
            baseX + sin(seed * 2 + prog * 4 + t * 3) * s.width * .06 * prog,
            s.height * .9 - growH * prog);
      }
      final op = sin(ph * pi) * .75;
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFF5D4037).withAlpha((op * 255).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 - i * .3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
  }
  @override bool shouldRepaint(_EarthP3 o) => o.t != t;
}

/// P4: 砂粒が渦巻く
class _EarthP4 extends CustomPainter {
  final double t;
  static const int _n = 35;
  _EarthP4(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .55;
    for (int i = 0; i < _n; i++) {
      final seed = i * 2.399;
      final ph = (t * .8 + i / _n) % 1.0;
      final angle = seed * pi * 2 + ph * pi * 3;
      final r = s.width * .45 * (ph < .5 ? ph * 2 : 2 - ph * 2);
      final x = cx + r * cos(angle), y = cy + r * .65 * sin(angle);
      final op = sin(ph * pi) * .65;
      canvas.drawCircle(Offset(x, y), 1.5 + 2.0 * sin(seed),
          _blurPaint(const Color(0xFFA1887F).withAlpha((op * 255).toInt()), 2));
    }
  }
  @override bool shouldRepaint(_EarthP4 o) => o.t != t;
}

/// P5: 地割れから大地のオーラが噴き出す
class _EarthP5 extends CustomPainter {
  final double t;
  static const int _n = 5;
  _EarthP5(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, baseY = s.height * .87;
    // 地割れライン
    final pulse = .5 + .5 * sin(t * pi * 2 * 1.2);
    for (int i = 0; i < _n; i++) {
      final seed = i * 1.618;
      final x = cx + sin(seed * 5.1) * s.width * .32;
      final len = s.width * (.06 + .06 * sin(seed));
      canvas.drawLine(Offset(x - len, baseY), Offset(x + len, baseY),
          _strokePaint(const Color(0xFF3E2723).withAlpha(180), 2.0, 2));
      // 割れ目からのオーラ
      canvas.drawLine(Offset(x, baseY), Offset(x + sin(seed * 3) * 10, baseY - s.height * .2 * pulse),
          Paint()
            ..shader = LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [const Color(0xFF8D6E63).withAlpha(160), Colors.transparent])
                .createShader(Rect.fromLTWH(x - 10, baseY - s.height * .2, 20, s.height * .2))
            ..strokeWidth = 4.0 + 3.0 * pulse
            ..style = PaintingStyle.stroke
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
    // 足元のグロー
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, baseY), width: s.width * .55, height: s.height * .05),
        _blurPaint(const Color(0xFF8D6E63).withAlpha((80 * pulse).toInt()), 10));
  }
  @override bool shouldRepaint(_EarthP5 o) => o.t != t;
}

// ══════════════════════════════════════════════════════
// 氷属性 — ライトブルー / 白
// ══════════════════════════════════════════════════════

/// P1: 六角氷晶がゆっくり降る
class _IceP1 extends CustomPainter {
  final double t;
  static const int _n = 14;
  _IceP1(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    for (int i = 0; i < _n; i++) {
      final seed = i * 2.399;
      final ph = (t * .6 + i / _n) % 1.0;
      final x = cx + sin(seed * 3.7) * s.width * .4;
      final y = s.height * ph;
      final sz = 5.0 + 5.0 * sin(seed * 1.9);
      final op = sin(ph * pi) * .7;
      final rot = seed + t * .5;
      final path = Path();
      for (int j = 0; j < 6; j++) {
        final a = j * pi / 3 + rot;
        j == 0 ? path.moveTo(x + sz * cos(a), y + sz * sin(a))
               : path.lineTo(x + sz * cos(a), y + sz * sin(a));
      }
      path.close();
      // 十字の線
      for (int j = 0; j < 3; j++) {
        final a = j * pi / 3 + rot;
        canvas.drawLine(Offset(x - sz * cos(a), y - sz * sin(a)),
            Offset(x + sz * cos(a), y + sz * sin(a)),
            _strokePaint(const Color(0xFFE1F5FE).withAlpha((op * .6 * 255).toInt()), 1.0, 1));
      }
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFFB3E5FC).withAlpha((op * .4 * 255).toInt()));
      canvas.drawPath(path, _strokePaint(const Color(0xFF4FC3F7).withAlpha((op * 255).toInt()), 1.2, 2));
    }
  }
  @override bool shouldRepaint(_IceP1 o) => o.t != t;
}

/// P2: 霜の結晶が広がって溶ける
class _IceP2 extends CustomPainter {
  final double t;
  static const int _n = 8;
  _IceP2(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .45;
    for (int i = 0; i < _n; i++) {
      final seed = i * 2.399;
      final ph = (t * .5 + i / _n) % 1.0;
      final baseAngle = seed * pi * 2 / _n;
      final r = s.width * (.15 + .28 * ph);
      final x = cx + r * cos(baseAngle), y = cy + r * .8 * sin(baseAngle);
      final op = sin(ph * pi) * .7;
      final branchLen = 8.0 + 6.0 * ph;
      // 枝状の霜
      for (int j = 0; j < 4; j++) {
        final a = baseAngle + j * pi / 2;
        canvas.drawLine(Offset(x, y), Offset(x + cos(a) * branchLen, y + sin(a) * branchLen),
            _strokePaint(const Color(0xFF81D4FA).withAlpha((op * 255).toInt()), 1.5, 2));
        // 小枝
        canvas.drawLine(
            Offset(x + cos(a) * branchLen * .5, y + sin(a) * branchLen * .5),
            Offset(x + cos(a + pi / 4) * branchLen * .4 + cos(a) * branchLen * .5,
                y + sin(a + pi / 4) * branchLen * .4 + sin(a) * branchLen * .5),
            _strokePaint(const Color(0xFFB3E5FC).withAlpha((op * .7 * 255).toInt()), 1.0, 1));
      }
      canvas.drawCircle(Offset(x, y), 2.5,
          _blurPaint(Colors.white.withAlpha((op * 220).toInt()), 3));
    }
  }
  @override bool shouldRepaint(_IceP2 o) => o.t != t;
}

/// P3: 冷気の波紋
class _IceP3 extends CustomPainter {
  final double t;
  _IceP3(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height * .5;
    // 冷気のオーラ（青白いグロー）
    final pulse = .5 + .5 * sin(t * pi * 2 * .8);
    canvas.drawCircle(Offset(cx, cy), s.width * (.38 + .04 * pulse),
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFE1F5FE).withAlpha((50 * pulse).toInt()),
            const Color(0xFF4FC3F7).withAlpha(30),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: s.width * .42))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    // 波紋
    for (int i = 0; i < 3; i++) {
      final ph = (t * .65 + i / 3.0) % 1.0;
      final r = s.width * (.2 + .32 * ph);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 1.2),
          _strokePaint(const Color(0xFF81D4FA).withAlpha(((1 - ph) * .5 * 255).toInt()),
              2.0 - 1.5 * ph, 4));
    }
  }
  @override bool shouldRepaint(_IceP3 o) => o.t != t;
}

/// P4: 吹雪 — 細かい雪片が横から流れる
class _IceP4 extends CustomPainter {
  final double t;
  static const int _n = 25;
  _IceP4(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    for (int i = 0; i < _n; i++) {
      final seed = i * 1.618;
      final speed = .7 + .5 * sin(seed * 1.3);
      final ph = (t * speed + i / _n) % 1.0;
      final y = s.height * (i / _n);
      final x = s.width * 1.1 * (1 - ph) - s.width * .05;
      final drift = sin(seed * 2.1 + t * pi * 3) * 12;
      final sz = 1.5 + 2.5 * sin(seed * 1.9);
      final op = sin(ph * pi) * .75;
      // 小さな十字雪片
      canvas.drawLine(Offset(x - sz, y + drift), Offset(x + sz, y + drift),
          _strokePaint(Colors.white.withAlpha((op * 255).toInt()), 1.2, 1));
      canvas.drawLine(Offset(x, y + drift - sz), Offset(x, y + drift + sz),
          _strokePaint(Colors.white.withAlpha((op * 255).toInt()), 1.2, 1));
    }
  }
  @override bool shouldRepaint(_IceP4 o) => o.t != t;
}

/// P5: 氷柱が地面から伸びる
class _IceP5 extends CustomPainter {
  final double t;
  static const int _n = 7;
  _IceP5(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, baseY = s.height * .88;
    for (int i = 0; i < _n; i++) {
      final seed = i * 1.618;
      final ph = (t * .6 + i / _n) % 1.0;
      final x = cx + sin(seed * 5.1) * s.width * .35;
      final h = s.height * (.15 + .25 * sin(seed * 2.3)) * sin(ph * pi);
      final w = 6.0 + 5.0 * sin(seed * 1.7);
      final op = sin(ph * pi) * .7;
      // 氷柱（先端が細い四角形）
      final path = Path()
        ..moveTo(x - w / 2, baseY)
        ..lineTo(x + w / 2, baseY)
        ..lineTo(x + w / 4, baseY - h)
        ..lineTo(x, baseY - h - 8)
        ..lineTo(x - w / 4, baseY - h)
        ..close();
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFFB3E5FC).withAlpha((op * .5 * 255).toInt()));
      canvas.drawPath(path, _strokePaint(const Color(0xFF4FC3F7).withAlpha((op * 255).toInt()), 1.0, 3));
    }
    // 足元の氷のグロー
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, baseY), width: s.width * .6, height: s.height * .04),
        _blurPaint(const Color(0xFF81D4FA).withAlpha(60), 8));
  }
  @override bool shouldRepaint(_IceP5 o) => o.t != t;
}

// ── 元素説明ダイアログ ─────────────────────────────────────────────────────

const Map<ElementType, String> _elementDescriptions = {
  ElementType.fire:    '喜怒哀楽がそのまま言葉や行動に出る情熱型。感情が外に溢れやすく、周囲を熱狂させるエネルギーがある。衝動的に動く場面もあるが、その分決断が速く行動力がある。',
  ElementType.water:   '相手の気持ちを敏感に察する共感型。感情を内側でじっくり受け止め、優しさと穏やかさで場を包む。溜め込みやすい一面もあるが、深いところで人と繋がれる。',
  ElementType.wind:    '枠にはまらない自由人型。好奇心旺盛でひらめきが得意。感情にも論理にも縛られず軽やかに動き、変化を楽しんで周囲を明るくする。',
  ElementType.earth:   '揺るがない芯を持つ安定型。じっくり考えてから動き、一度決めたことをやり遂げる粘り強さがある。内に深く根を張り、周囲に安心感を与える存在。',
  ElementType.ice:     '感情を表に出さず内側で研ぎ澄ます冷静型。直感で判断しながらも表情には出しにくい。独自の基準を持ち、近づくほど深みとこだわりが見えてくる。',
  ElementType.thunder: '直感と行動力が爆発する瞬発型。論理を直感的に使い、素早く放電するように動く。エネルギッシュで存在感があり、場の空気を一瞬で変えるカリスマ性がある。',
  ElementType.light:   '分析力と行動力を外に向けるリーダー型。計画的で明晰、情報を整理して周囲を導く。目標達成への道筋を照らす推進力と、頼られる安定感がある。',
  ElementType.dark:    '物事の本質を内側で追求する思索型。表面より深い意味を探り、独自の視点と分析力を持つ。内省的で外に出しにくいが、深く語り合うほど豊かな世界が見えてくる。',
  ElementType.none:    'どんな状況にも自然に溶け込む適応型。エネルギーが中間的で強い主張より観察と受容を大切にする。特定の色に染まらないからこそ、すべての元素と一定の相性がある。',
};

void showElementGuideDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final gradient = ref.watch(backgroundGradientProvider);
        final textColor = ref.watch(colorSettingsProvider).textColor;
        final dividerColor = textColor.withAlpha(40);

        return DraggableScrollableSheet(
          initialChildSize: 1.0,
          minChildSize: 0.5,
          maxChildSize: 1.0,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              minimum: const EdgeInsets.only(top: 24),
              child: Column(
                children: [
                  // ハンドル
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: textColor.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // ヘッダー
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '元素について',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '性格解析によって判定される9種類の元素です。',
                                style: TextStyle(fontSize: 12, color: textColor.withAlpha(140)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: textColor.withAlpha(160)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: dividerColor),
                  // 元素リスト
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 32),
                      itemCount: ElementType.values.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: dividerColor,
                      ),
                      itemBuilder: (_, i) {
                        final e = ElementType.values[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: e.color,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [BoxShadow(color: e.color.withAlpha(120), blurRadius: 4)],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: e.color,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _elementDescriptions[e] ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textColor,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
