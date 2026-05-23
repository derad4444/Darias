import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/character/element_effect_widget.dart';

class CharacterAnimationTestScreen extends StatefulWidget {
  const CharacterAnimationTestScreen({super.key});

  @override
  State<CharacterAnimationTestScreen> createState() =>
      _CharacterAnimationTestScreenState();
}

enum _Part {
  body,
  hairBack,
  headBase,
  eyes,
  eyebrow,
  mouth,
  hairFront,
}

extension _PartLabel on _Part {
  String get label {
    switch (this) {
      case _Part.body:      return 'ボディ';
      case _Part.hairBack:  return '後ろ髪';
      case _Part.headBase:  return '頭ベース';
      case _Part.eyes:      return '目';
      case _Part.eyebrow:   return '眉毛';
      case _Part.mouth:     return '口';
      case _Part.hairFront: return '前髪';
    }
  }
}

class _PartTransform {
  double dx;
  double dy;
  double scale;
  _PartTransform({this.dx = 0, this.dy = 0, this.scale = 1.0});
}

class _CharacterAnimationTestScreenState
    extends State<CharacterAnimationTestScreen>
    with SingleTickerProviderStateMixin {
  bool _eyesOpen = true;
  bool _mouthOpen = false;
  Timer? _blinkTimer;
  Timer? _mouthTimer;
  final Random _random = Random();

  ElementType _element = ElementType.none;
  int _pattern = 1;
  _Part _selectedPart = _Part.body;
  final Map<_Part, _PartTransform> _transforms = {
    for (final p in _Part.values) p: _PartTransform(),
  };

  static const String _assetBase =
      'assets/images/characters/no_element_baby/';

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
    _scheduleMouth();
  }

  void _scheduleBlink() {
    final delay = 2500 + _random.nextInt(3000);
    _blinkTimer = Timer(Duration(milliseconds: delay), () async {
      if (!mounted) return;
      setState(() => _eyesOpen = false);
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() => _eyesOpen = true);
      _scheduleBlink();
    });
  }

  void _scheduleMouth() {
    final delay = 3000 + _random.nextInt(4000);
    _mouthTimer = Timer(Duration(milliseconds: delay), () async {
      if (!mounted) return;
      setState(() => _mouthOpen = true);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _mouthOpen = false);
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() => _mouthOpen = true);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _mouthOpen = false);
      _scheduleMouth();
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _mouthTimer?.cancel();
    super.dispose();
  }

  Widget _buildPart(String assetName, _Part part, {Widget? child}) {
    final t = _transforms[part]!;
    Widget img = child ??
        Image.asset(
          '$_assetBase$assetName',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.fill,
        );
    return Transform.translate(
      offset: Offset(t.dx, t.dy),
      child: Transform.scale(scale: t.scale, child: img),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _transforms[_selectedPart]!;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('キャラクターアニメーション テスト'),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── 元素選択ボタン ──
          Container(
            color: const Color(0xFF16213E),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ElementType.values.map((e) {
                  final selected = e == _element;
                  return GestureDetector(
                    onTap: () => setState(() => _element = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? e.color
                            : e.color.withAlpha(40),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: e.color.withAlpha(selected ? 0 : 100),
                          width: 1,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: e.color.withAlpha(120),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : [],
                      ),
                      child: Text(
                        e.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: selected ? Colors.white : e.color,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── パターン選択ボタン ──
          Container(
            color: const Color(0xFF0D1B2A),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              children: [
                Text('パターン',
                    style: TextStyle(
                        fontSize: 12, color: Colors.white.withAlpha(160))),
                const SizedBox(width: 10),
                ...List.generate(kMaxPatterns, (i) {
                  final n = i + 1;
                  final selected = n == _pattern;
                  return GestureDetector(
                    onTap: () => setState(() => _pattern = n),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 6),
                      width: 36,
                      height: 28,
                      decoration: BoxDecoration(
                        color: selected
                            ? _element.color
                            : Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: selected
                            ? [BoxShadow(color: _element.color.withAlpha(100), blurRadius: 6)]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Text('$n',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : Colors.white.withAlpha(120),
                          )),
                    ),
                  );
                }),
              ],
            ),
          ),

          // ── キャラクター表示 ──
          Expanded(
            flex: 3,
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const double imgRatio = 1024 / 1536;
                  final double maxW = constraints.maxWidth * 0.7;
                  final double maxH = constraints.maxHeight * 0.95;
                  double w, h;
                  if (maxW / maxH > imgRatio) {
                    h = maxH;
                    w = h * imgRatio;
                  } else {
                    w = maxW;
                    h = w / imgRatio;
                  }

                  return SizedBox(
                    width: w,
                    height: h,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildPart('body.png', _Part.body),
                        _buildPart('hair_back.png', _Part.hairBack),
                        _buildPart('head_base.png', _Part.headBase),
                        _buildPart(
                          _eyesOpen ? 'eyes_open.png' : 'eyes_closed.png',
                          _Part.eyes,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 80),
                            child: Image.asset(
                              _eyesOpen
                                  ? '${_assetBase}eyes_open.png'
                                  : '${_assetBase}eyes_closed.png',
                              key: ValueKey(_eyesOpen),
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                        _buildPart('eyebrow_normal.png', _Part.eyebrow),
                        _buildPart(
                          _mouthOpen ? 'mouth_open.png' : 'mouth_normal.png',
                          _Part.mouth,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 80),
                            child: Image.asset(
                              _mouthOpen
                                  ? '${_assetBase}mouth_open.png'
                                  : '${_assetBase}mouth_normal.png',
                              key: ValueKey(_mouthOpen),
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                        _buildPart('hair_front.png', _Part.hairFront),
                        // エフェクト（最前面）
                        ElementEffectWidget(element: _element, pattern: _pattern),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // ── パーツ調整パネル ──
          Container(
            color: const Color(0xFF0F3460),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _Part.values.map((p) {
                      final selected = p == _selectedPart;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedPart = p),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF9B7FD4)
                                : Colors.white.withAlpha(20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            p.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withAlpha(160),
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                _sliderRow(
                  label: 'X',
                  value: t.dx,
                  min: -150,
                  max: 150,
                  onChanged: (v) => setState(() => t.dx = v),
                  onReset: () => setState(() => t.dx = 0),
                ),
                _sliderRow(
                  label: 'Y',
                  value: t.dy,
                  min: -200,
                  max: 200,
                  onChanged: (v) => setState(() => t.dy = v),
                  onReset: () => setState(() => t.dy = 0),
                ),
                _sliderRow(
                  label: 'スケール',
                  value: t.scale,
                  min: 0.5,
                  max: 2.0,
                  onChanged: (v) => setState(() => t.scale = v),
                  onReset: () => setState(() => t.scale = 1.0),
                ),
                Text(
                  '${_selectedPart.label}:  X=${t.dx.toStringAsFixed(1)}  Y=${t.dy.toStringAsFixed(1)}  scale=${t.scale.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.white.withAlpha(120)),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _showAllValues(context),
                      child: Text('数値確認',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withAlpha(180))),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        for (final p in _Part.values) {
                          _transforms[p] = _PartTransform();
                        }
                      }),
                      child: const Text('全リセット',
                          style:
                              TextStyle(fontSize: 12, color: Colors.redAccent)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAllValues(BuildContext context) {
    final lines = _Part.values.map((p) {
      final tr = _transforms[p]!;
      return '${p.label.padRight(6)}  X=${tr.dx.toStringAsFixed(1)}  Y=${tr.dy.toStringAsFixed(1)}  scale=${tr.scale.toStringAsFixed(2)}';
    }).join('\n');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('全パーツ 現在値'),
        content: Text(
          lines,
          style: const TextStyle(
              fontFamily: 'monospace', fontSize: 13, height: 1.8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required VoidCallback onReset,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withAlpha(180))),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: const Color(0xFF9B7FD4),
              inactiveTrackColor: Colors.white.withAlpha(40),
              thumbColor: const Color(0xFF9B7FD4),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        GestureDetector(
          onTap: onReset,
          child: Icon(Icons.refresh,
              size: 16, color: Colors.white.withAlpha(160)),
        ),
      ],
    );
  }
}
