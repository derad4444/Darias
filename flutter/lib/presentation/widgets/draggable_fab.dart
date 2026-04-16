import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/fab_provider.dart';

/// ドラッグ可能なFABをボディにオーバーレイするウィジェット。
/// Scaffold の body として使い、位置は fabPositionProvider で全画面共有。
class DraggableFabStack extends ConsumerWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color accentColor;
  final bool visible;

  const DraggableFabStack({
    super.key,
    required this.child,
    required this.onTap,
    required this.accentColor,
    this.visible = true,
  });

  static const double _fabSize = 56;
  static const double _fabPadding = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(fabPositionProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final defaultX = constraints.maxWidth - _fabSize - _fabPadding;
        final defaultY = constraints.maxHeight - _fabSize - _fabPadding;

        return Stack(
          children: [
            child,
            if (visible)
              Positioned(
                left: position?.dx ?? defaultX,
                top: position?.dy ?? defaultY,
                child: GestureDetector(
                  onTap: onTap,
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
                        colors: [accentColor, accentColor.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.3),
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
