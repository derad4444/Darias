// features/roguelike/widgets/adventure_door_transition.dart
//
// 「冒険」タブを開いたときに、ダンジョンの扉が両開きで開くような演出を重ねるラッパー。
// タブが冒険タブに切り替わった瞬間だけ、閉じた扉→左右に swing open して中身を見せる。
// タブ切替の検知には main_shell の [selectedTabProvider] を購読する。

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/sound_effect_player.dart';
import '../../../presentation/screens/main/main_shell_screen.dart' show selectedTabProvider;
import '../../../presentation/screens/settings/volume_settings_screen.dart' show volumeSettingsProvider;

/// 扉が開くときの効果音アセット。
const _kGateOpenSfx = 'assets/audio/gate_open.mp3';

/// [child]（冒険タブの中身）の上に、扉が開く演出を重ねる。
class AdventureDoorTransition extends ConsumerStatefulWidget {
  /// メインタブ内の「冒険」タブのインデックス。
  final int adventureTabIndex;
  final Widget child;

  const AdventureDoorTransition({
    super.key,
    required this.adventureTabIndex,
    required this.child,
  });

  @override
  ConsumerState<AdventureDoorTransition> createState() => _AdventureDoorTransitionState();
}

class _AdventureDoorTransitionState extends ConsumerState<AdventureDoorTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// true = 扉は開ききっている（＝オーバーレイ非表示）。既定は開いた状態。
  bool _opened = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _opened = true);
        }
      });
    // 初回タップの再生遅延を防ぐため効果音を先読みしておく。
    SoundEffectPlayer.shared.preload(_kGateOpenSfx);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _playOpen() {
    setState(() => _opened = false);
    _controller.forward(from: 0);
    // BGMミュート時（または音量0）は効果音も鳴らさない。BGM音量に合わせて再生。
    final volume = ref.read(volumeSettingsProvider);
    if (!volume.bgmMuted) {
      SoundEffectPlayer.shared.play(_kGateOpenSfx, volume: volume.bgmVolume);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 冒険タブに「入った」瞬間だけ演出を再生する。
    ref.listen<int>(selectedTabProvider, (prev, next) {
      if (next == widget.adventureTabIndex && prev != widget.adventureTabIndex) {
        _playOpen();
      }
    });

    return Stack(
      children: [
        widget.child,
        if (!_opened)
          Positioned.fill(
            child: IgnorePointer(
              child: _DoorsOverlay(animation: _controller),
            ),
          ),
      ],
    );
  }
}

/// 左右2枚の扉が swing open するオーバーレイ本体。
class _DoorsOverlay extends StatelessWidget {
  final Animation<double> animation;
  const _DoorsOverlay({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final raw = animation.value; // 0..1
        // タイムライン:
        //   0.00–0.08 溜め（扉は閉じたまま）
        //   0.08–0.55 扉が開く（奥は光。開くほど光が溢れる）
        //   0.55–0.68 一拍（扉は開ききり、光が満ちる）
        //   0.68–1.00 光がフェードしてゲーム画面が現れる
        const holdEnd = 0.08;
        const doorEnd = 0.55;
        const beatEnd = 0.68;

        final doorRaw = ((raw - holdEnd) / (doorEnd - holdEnd)).clamp(0.0, 1.0);
        final open = Curves.easeInOutCubic.transform(doorRaw);

        // 外側の蝶番を軸に、奥へ向かって開く。
        final swing = open * (math.pi * 0.62);
        // 開ききる手前で扉自体をフェードアウトさせ、光との境目を自然にする。
        final doorOpacity = (1.0 - ((open - 0.72) / 0.28)).clamp(0.0, 1.0);

        // 奥の光：扉が開く間〜一拍までは満ち（不透明）、その後フェードしてゲーム画面を見せる。
        final lightOpacity = raw <= beatEnd
            ? 1.0
            : (1.0 - Curves.easeOut.transform((raw - beatEnd) / (1 - beatEnd)))
                .clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            // 扉の奥にある光の層（扉が開くとここが覗く）
            Positioned.fill(
              child: Opacity(
                opacity: lightOpacity,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.95,
                      colors: [
                        Color(0xFFFFFEF9), // 中心：まばゆい白
                        Color(0xFFFFF3CF), // 温かい金の光
                        Color(0xFFF7D7E6), // 端：本編の薄ピンクへ
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // 左扉（左端を蝶番に開く）
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: Transform(
                  alignment: Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0013)
                    ..rotateY(swing),
                  child: Opacity(
                    opacity: doorOpacity,
                    child: const _DoorPanel(isLeft: true),
                  ),
                ),
              ),
            ),
            // 右扉（右端を蝶番に開く）
            Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: Transform(
                  alignment: Alignment.centerRight,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0013)
                    ..rotateY(-swing),
                  child: Opacity(
                    opacity: doorOpacity,
                    child: const _DoorPanel(isLeft: false),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 1枚分の扉。石造りのダンジョン門をイメージ（[isLeft] で内側＝合わせ目の向きを変える）。
class _DoorPanel extends StatelessWidget {
  final bool isLeft;
  const _DoorPanel({required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
            end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
            colors: const [
              Color(0xFF3B3060), // 外側：やや明るい紫
              Color(0xFF2B2347), // 中央寄り：夜の紫（背景と馴染む）
              Color(0xFF221B3A),
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
          border: Border(
            top: const BorderSide(color: Color(0xFF574A7E), width: 3),
            bottom: const BorderSide(color: Color(0xFF191330), width: 3),
            left: BorderSide(
              color: isLeft ? const Color(0xFF574A7E) : const Color(0xFF120D24),
              width: isLeft ? 3 : 1.5,
            ),
            right: BorderSide(
              color: isLeft ? const Color(0xFF120D24) : const Color(0xFF574A7E),
              width: isLeft ? 1.5 : 3,
            ),
          ),
        ),
        child: Stack(
          children: [
            // 縦の羽目板（木目/石目の筋）
            Positioned.fill(
              child: CustomPaint(painter: _PlankPainter(isLeft: isLeft)),
            ),
            // 四隅の鋲（合わせ目側は上下だけ）
            const Positioned(top: 18, left: 14, child: _Stud()),
            const Positioned(bottom: 18, left: 14, child: _Stud()),
            const Positioned(top: 18, right: 14, child: _Stud()),
            const Positioned(bottom: 18, right: 14, child: _Stud()),
            // 合わせ目に半分だけ覗くエンブレム（左右で合わさると1つの円になる）
            Align(
              alignment: isLeft ? Alignment.centerRight : Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(isLeft ? 44 : -44, 0),
                child: const _EmblemHalf(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 縦筋（羽目板）を描く。
class _PlankPainter extends CustomPainter {
  final bool isLeft;
  const _PlankPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1.5;
    final hi = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;
    // 3本の縦筋で板を分割。
    for (var i = 1; i <= 3; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 8), Offset(x, size.height - 8), line);
      canvas.drawLine(Offset(x + 1.5, 8), Offset(x + 1.5, size.height - 8), hi);
    }
  }

  @override
  bool shouldRepaint(covariant _PlankPainter oldDelegate) => false;
}

/// 装飾の鋲（リベット）。
class _Stud extends StatelessWidget {
  const _Stud();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0xFFB9A8E0), Color(0xFF4A3E70)],
          center: Alignment(-0.3, -0.3),
        ),
        boxShadow: [
          BoxShadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
    );
  }
}

/// 合わせ目のエンブレム（円形メダル）を左右どちらか半分だけ描く。
/// 各扉が半円を持ち、閉じているときは中央でひとつの円章に見える。
class _EmblemHalf extends StatelessWidget {
  const _EmblemHalf();

  @override
  Widget build(BuildContext context) {
    const size = 88.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFF3D08A), Color(0xFFB98A3E)],
          center: Alignment(-0.2, -0.3),
        ),
        border: Border.all(color: const Color(0xFF7A5A22), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      // コンパス＝冒険タブと同じモチーフ。円の中心に配置され左右に割れる。
      child: const Icon(Icons.explore, color: Color(0xFF3B2A0A), size: 46),
    );
  }
}
