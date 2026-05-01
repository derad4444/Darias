import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/draggable_fab.dart';
import '../calendar/calendar_screen.dart';
import '../note/note_screen.dart';

enum PlanSegment { schedule, todo, memo }

/// 予定・タスク・メモを統合したタブ画面
final planSegmentProvider = StateProvider<PlanSegment>((ref) => PlanSegment.schedule);

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = ref.watch(planSegmentProvider);
    final accentColor = ref.watch(accentColorProvider);
    final backgroundGradient = ref.watch(backgroundGradientProvider);

    void onFabTap() {
      switch (segment) {
        case PlanSegment.todo:
          final tag = ref.read(todoSelectedTagProvider);
          context.push('/todo/detail', extra: {'initialTag': tag != 'すべて' ? tag : ''});
        case PlanSegment.memo:
          final tag = ref.read(memoSelectedTagProvider);
          context.push('/memo/detail', extra: {'initialTag': tag != 'すべて' ? tag : ''});
        case PlanSegment.schedule:
          break;
      }
    }

    return Scaffold(
      body: DraggableFabStack(
        visible: segment != PlanSegment.schedule,
        onTap: onFabTap,
        accentColor: accentColor,
        child: Container(
          decoration: BoxDecoration(gradient: backgroundGradient),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _PlanSegmentControl(
                    selectedSegment: segment,
                    accentColor: accentColor,
                    onChanged: (s) => ref.read(planSegmentProvider.notifier).state = s,
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: segment.index,
                    children: [
                      // 予定: CalendarScreen をそのまま組み込む（上の SafeArea 分を除去）
                      MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        child: const CalendarScreen(),
                      ),
                      // タスク
                      const SafeArea(top: false, child: TodoContentView()),
                      // メモ
                      const SafeArea(top: false, child: MemoContentView()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanSegmentControl extends StatelessWidget {
  final PlanSegment selectedSegment;
  final Color accentColor;
  final ValueChanged<PlanSegment> onChanged;

  const _PlanSegmentControl({
    required this.selectedSegment,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: PlanSegment.values.map((segment) {
          final isSelected = selectedSegment == segment;
          final label = switch (segment) {
            PlanSegment.schedule => '予定',
            PlanSegment.todo => 'タスク',
            PlanSegment.memo => 'メモ',
          };
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(segment),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? accentColor : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
