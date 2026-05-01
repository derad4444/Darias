import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/fab_provider.dart';

/// ドラッグ可能なFABをボディにオーバーレイするウィジェット。
/// Scaffold の body として使い、位置は fabPositionProvider で全画面共有。
/// characterWidget を指定するとキャラクターも独立してドラッグ・ピンチズーム可能なオーバーレイになる。
class DraggableFabStack extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color accentColor;
  final bool visible;
  final Widget? characterWidget;

  const DraggableFabStack({
    super.key,
    required this.child,
    required this.onTap,
    required this.accentColor,
    this.visible = true,
    this.characterWidget,
  });

  @override
  ConsumerState<DraggableFabStack> createState() => _DraggableFabStackState();
}

class _DraggableFabStackState extends ConsumerState<DraggableFabStack> {
  static const double _fabSize = 56;
  static const double _fabPadding = 16;
  static const double _charWidth = 370;
  static const double _charHeight = 150;

  // ピンチ開始時のスケール値を保持
  double _scaleAtGestureStart = 1.0;

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(fabPositionProvider);
    final charPosition = widget.characterWidget != null
        ? ref.watch(characterOverlayPositionProvider)
        : null;
    final charScale = widget.characterWidget != null
        ? ref.watch(characterScaleProvider)
        : 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final defaultX = constraints.maxWidth - _fabSize - _fabPadding;
        final defaultY = constraints.maxHeight - _fabSize - _fabPadding;
        final defaultCharX = -20.0;
        final defaultCharY = constraints.maxHeight - _charHeight - _fabPadding;

        return Stack(
          children: [
            widget.child,
            // キャラクターオーバーレイ（指定時のみ）
            if (widget.characterWidget != null)
              Positioned(
                left: charPosition?.dx ?? defaultCharX,
                top: charPosition?.dy ?? defaultCharY,
                child: GestureDetector(
                  onScaleStart: (_) {
                    _scaleAtGestureStart = ref.read(characterScaleProvider);
                  },
                  onScaleUpdate: (details) {
                    // 1本指: パン、2本指: パン + ピンチズーム
                    final current = charPosition ?? Offset(defaultCharX, defaultCharY);
                    final newDx = (current.dx + details.focalPointDelta.dx).clamp(
                      -20.0,
                      constraints.maxWidth - _charWidth + 20,
                    );
                    final newDy = (current.dy + details.focalPointDelta.dy).clamp(
                      0.0,
                      constraints.maxHeight - _charHeight,
                    );
                    ref.read(characterOverlayPositionProvider.notifier).state =
                        Offset(newDx, newDy);

                    // スケール更新（0.5〜2.0 の範囲に制限）
                    final newScale = (_scaleAtGestureStart * details.scale).clamp(0.5, 2.0);
                    ref.read(characterScaleProvider.notifier).state = newScale;
                  },
                  child: Transform.scale(
                    scale: charScale,
                    alignment: Alignment.bottomLeft,
                    child: widget.characterWidget!,
                  ),
                ),
              ),
            if (widget.visible)
              Positioned(
                left: position?.dx ?? defaultX,
                top: position?.dy ?? defaultY,
                child: GestureDetector(
                  onTap: widget.onTap,
                  onPanUpdate: (details) {
                    final current = position ?? Offset(defaultX, defaultY);
                    final newDx = (current.dx + details.delta.dx).clamp(
                      _fabPadding,
                      constraints.maxWidth - _fabSize - _fabPadding,
                    );
                    final newDy = (current.dy + details.delta.dy).clamp(
                      _fabPadding,
                      constraints.maxHeight - _fabSize - _fabPadding,
                    );
                    ref.read(fabPositionProvider.notifier).state =
                        Offset(newDx, newDy);
                  },
                  child: Container(
                    width: _fabSize,
                    height: _fabSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [widget.accentColor, widget.accentColor.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.menu, color: Colors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
