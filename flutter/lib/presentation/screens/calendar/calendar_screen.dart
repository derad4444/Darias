import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/schedule_model.dart';
import '../../providers/calendar_provider.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final selectedDay = ref.watch(selectedDayProvider);
    final schedulesAsync = ref.watch(allSchedulesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('カレンダー'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // カレンダーヘッダー
          _CalendarHeader(
            month: selectedMonth,
            onPreviousMonth: () =>
                ref.read(calendarControllerProvider.notifier).previousMonth(),
            onNextMonth: () =>
                ref.read(calendarControllerProvider.notifier).nextMonth(),
          ),

          // カレンダーグリッド
          schedulesAsync.when(
            data: (schedules) => _CalendarGrid(
              month: selectedMonth,
              selectedDay: selectedDay,
              schedules: schedules,
              onDaySelected: (day) =>
                  ref.read(calendarControllerProvider.notifier).selectDay(day),
            ),
            loading: () => const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Expanded(
              child: Center(child: Text('エラー: $e')),
            ),
          ),

          // 選択した日のスケジュール
          if (selectedDay != null)
            Expanded(
              child: _ScheduleList(day: selectedDay),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/calendar/detail', extra: {
          'schedule': null,
          'initialDate': selectedDay,
        }),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// カレンダーヘッダー
class _CalendarHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _CalendarHeader({
    required this.month,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPreviousMonth,
          ),
          Text(
            '${month.year}年${month.month}月',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNextMonth,
          ),
        ],
      ),
    );
  }
}

/// カレンダーグリッド
class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final DateTime? selectedDay;
  final List<ScheduleModel> schedules;
  final Function(DateTime) onDaySelected;

  const _CalendarGrid({
    required this.month,
    required this.selectedDay,
    required this.schedules,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday % 7; // 日曜始まり

    final days = <Widget>[];

    // 曜日ヘッダー
    const weekdays = ['日', '月', '火', '水', '木', '金', '土'];
    for (var i = 0; i < 7; i++) {
      days.add(
        Center(
          child: Text(
            weekdays[i],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: i == 0
                  ? Colors.red
                  : i == 6
                      ? Colors.blue
                      : null,
            ),
          ),
        ),
      );
    }

    // 空のセル（前月分）
    for (var i = 0; i < firstWeekday; i++) {
      days.add(const SizedBox());
    }

    // 日のセル
    final today = DateTime.now();
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isSelected = selectedDay != null &&
          date.year == selectedDay!.year &&
          date.month == selectedDay!.month &&
          date.day == selectedDay!.day;

      // その日のスケジュール数を確認
      final daySchedules = schedules.where((s) {
        final startDay = DateTime(s.startDate.year, s.startDate.month, s.startDate.day);
        final endDay = DateTime(s.endDate.year, s.endDate.month, s.endDate.day);
        return !date.isBefore(startDay) && !date.isAfter(endDay);
      }).toList();

      final weekday = date.weekday % 7;
      final isSunday = weekday == 0;
      final isSaturday = weekday == 6;

      days.add(
        GestureDetector(
          onTap: () => onDaySelected(date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : isToday
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : isSunday
                            ? Colors.red
                            : isSaturday
                                ? Colors.blue
                                : null,
                    fontWeight: isToday ? FontWeight.bold : null,
                  ),
                ),
                if (daySchedules.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: daySchedules.take(3).map((s) {
                      return Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      padding: const EdgeInsets.all(8),
      children: days,
    );
  }
}

/// スケジュールリスト
class _ScheduleList extends ConsumerWidget {
  final DateTime day;

  const _ScheduleList({required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(daySchedulesProvider(day));

    if (schedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              '予定がありません',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        return _ScheduleItem(schedule: schedule);
      },
    );
  }
}

/// スケジュールアイテム
class _ScheduleItem extends ConsumerWidget {
  final ScheduleModel schedule;

  const _ScheduleItem({required this.schedule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showEditDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 時間表示
              SizedBox(
                width: 60,
                child: Text(
                  schedule.isAllDay
                      ? '終日'
                      : '${schedule.startDate.hour.toString().padLeft(2, '0')}:${schedule.startDate.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              // コンテンツ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (schedule.location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            schedule.location,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // 削除ボタン
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    context.push('/calendar/detail', extra: {
      'schedule': schedule,
      'initialDate': null,
    });
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('この予定を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(calendarControllerProvider.notifier).deleteSchedule(
          schedule.id,
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: $e')),
          );
        }
      }
    }
  }
}

/// スケジュール編集シート
class _ScheduleEditSheet extends ConsumerStatefulWidget {
  final ScheduleModel? schedule;
  final DateTime? initialDate;

  const _ScheduleEditSheet({
    this.schedule,
    this.initialDate,
  });

  @override
  ConsumerState<_ScheduleEditSheet> createState() => _ScheduleEditSheetState();
}

class _ScheduleEditSheetState extends ConsumerState<_ScheduleEditSheet> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _memoController;
  late DateTime _startDate;
  late DateTime _endDate;
  late bool _isAllDay;

  bool get isEditing => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.schedule?.title ?? '');
    _locationController = TextEditingController(text: widget.schedule?.location ?? '');
    _memoController = TextEditingController(text: widget.schedule?.memo ?? '');
    _startDate = widget.schedule?.startDate ?? widget.initialDate ?? DateTime.now();
    _endDate = widget.schedule?.endDate ?? _startDate;
    _isAllDay = widget.schedule?.isAllDay ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ヘッダー
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? '予定を編集' : '新しい予定',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _deleteSchedule,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // タイトル
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'タイトル',
                border: OutlineInputBorder(),
              ),
              autofocus: !isEditing,
            ),
            const SizedBox(height: 16),

            // 終日トグル
            SwitchListTile(
              title: const Text('終日'),
              value: _isAllDay,
              onChanged: (value) => setState(() => _isAllDay = value),
              contentPadding: EdgeInsets.zero,
            ),

            // 開始日時
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('開始'),
              trailing: TextButton(
                onPressed: () => _selectDateTime(isStart: true),
                child: Text(
                  _isAllDay
                      ? '${_startDate.year}/${_startDate.month}/${_startDate.day}'
                      : '${_startDate.year}/${_startDate.month}/${_startDate.day} ${_startDate.hour.toString().padLeft(2, '0')}:${_startDate.minute.toString().padLeft(2, '0')}',
                ),
              ),
            ),

            // 終了日時
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('終了'),
              trailing: TextButton(
                onPressed: () => _selectDateTime(isStart: false),
                child: Text(
                  _isAllDay
                      ? '${_endDate.year}/${_endDate.month}/${_endDate.day}'
                      : '${_endDate.year}/${_endDate.month}/${_endDate.day} ${_endDate.hour.toString().padLeft(2, '0')}:${_endDate.minute.toString().padLeft(2, '0')}',
                ),
              ),
            ),

            // 場所
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '場所（任意）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 24),

            // 保存ボタン
            FilledButton(
              onPressed: _saveSchedule,
              child: Text(isEditing ? '更新' : '追加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateTime({required bool isStart}) async {
    final currentDate = isStart ? _startDate : _endDate;

    final date = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (date != null) {
      if (_isAllDay) {
        setState(() {
          if (isStart) {
            _startDate = DateTime(date.year, date.month, date.day);
            if (_startDate.isAfter(_endDate)) {
              _endDate = _startDate;
            }
          } else {
            _endDate = DateTime(date.year, date.month, date.day);
            if (_endDate.isBefore(_startDate)) {
              _startDate = _endDate;
            }
          }
        });
      } else {
        if (!mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(currentDate),
        );

        if (time != null) {
          setState(() {
            final newDateTime = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );
            if (isStart) {
              _startDate = newDateTime;
              if (_startDate.isAfter(_endDate)) {
                _endDate = _startDate.add(const Duration(hours: 1));
              }
            } else {
              _endDate = newDateTime;
              if (_endDate.isBefore(_startDate)) {
                _startDate = _endDate.subtract(const Duration(hours: 1));
              }
            }
          });
        }
      }
    }
  }

  Future<void> _saveSchedule() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルを入力してください')),
      );
      return;
    }

    try {
      final schedule = ScheduleModel(
        id: widget.schedule?.id ?? '',
        title: title,
        startDate: _startDate,
        endDate: _endDate,
        isAllDay: _isAllDay,
        location: _locationController.text.trim(),
        memo: _memoController.text.trim(),
      );

      if (isEditing) {
        await ref.read(calendarControllerProvider.notifier).updateSchedule(
          schedule,
        );
      } else {
        await ref.read(calendarControllerProvider.notifier).addSchedule(
          schedule,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  Future<void> _deleteSchedule() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('この予定を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.schedule != null) {
      try {
        await ref.read(calendarControllerProvider.notifier).deleteSchedule(
          widget.schedule!.id,
        );
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: $e')),
          );
        }
      }
    }
  }
}
