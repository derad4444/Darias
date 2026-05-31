import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:darias/presentation/widgets/character/element_effect_widget.dart';

/// Flame を使ったマス占領エフェクトオーバーレイ
class CaptureEffectOverlay extends StatefulWidget {
  final List<(int, int)> capturedCells;
  final ElementType captureElement;
  final double boardLeft;
  final double boardTop;
  final double cellSize;
  final VoidCallback onComplete;

  const CaptureEffectOverlay({
    super.key,
    required this.capturedCells,
    required this.captureElement,
    required this.boardLeft,
    required this.boardTop,
    required this.cellSize,
    required this.onComplete,
  });

  @override
  State<CaptureEffectOverlay> createState() => _CaptureEffectOverlayState();
}

class _CaptureEffectOverlayState extends State<CaptureEffectOverlay> {
  late final _ParticleGame _game;

  @override
  void initState() {
    super.initState();
    _game = _ParticleGame(
      onComplete: widget.onComplete,
      burstCount: widget.capturedCells.length,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final (row, col) in widget.capturedCells) {
        final x = widget.boardLeft + col * widget.cellSize + widget.cellSize / 2;
        final y = widget.boardTop + row * widget.cellSize + widget.cellSize / 2;
        _game.burst(Vector2(x, y), widget.captureElement.color);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: GameWidget(game: _game),
    );
  }
}

class _ParticleGame extends FlameGame {
  final VoidCallback onComplete;
  final int burstCount;
  int _completedCount = 0;

  _ParticleGame({required this.onComplete, required this.burstCount});

  @override
  Color backgroundColor() => Colors.transparent;

  void burst(Vector2 position, Color color) {
    final rng = Random();
    add(
      _NotifyingParticleSystem(
        position: position,
        onDone: _onBurstComplete,
        particle: Particle.generate(
          count: 24,
          lifespan: 0.7,
          generator: (i) {
            final angle = rng.nextDouble() * 2 * pi;
            final speed = 60 + rng.nextDouble() * 120;
            final radius = 3 + rng.nextDouble() * 5;
            return AcceleratedParticle(
              acceleration: Vector2(0, 180),
              speed: Vector2(cos(angle) * speed, sin(angle) * speed),
              child: CircleParticle(
                radius: radius,
                paint: Paint()
                  ..color = color.withAlpha(
                      ((0.75 + rng.nextDouble() * 0.25) * 255).round()),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onBurstComplete() {
    _completedCount++;
    if (_completedCount >= burstCount) {
      onComplete();
    }
  }
}

/// 完了コールバック付きのパーティクルシステムコンポーネント
class _NotifyingParticleSystem extends ParticleSystemComponent {
  final VoidCallback onDone;

  _NotifyingParticleSystem({
    required Vector2 super.position,
    required this.onDone,
    required super.particle,
  });

  @override
  void onRemove() {
    super.onRemove();
    onDone();
  }
}
