import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/schedule_model.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/ad_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';

/// スケジュール詳細・編集画面
class ScheduleDetailScreen extends ConsumerStatefulWidget {
  /// 編集対象のスケジュール（nullの場合は新規作成）
  final ScheduleModel? schedule;

  /// 新規作成時の初期日付
  final DateTime? initialDate;

  const ScheduleDetailScreen({
    super.key,
    this.schedule,
    this.initialDate,
  });

  @override
  ConsumerState<ScheduleDetailScreen> createState() =>
      _ScheduleDetailScreenState();
}

class _ScheduleDetailScreenState extends ConsumerState<ScheduleDetailScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _memoController;
  late final TextEditingController _tagController;

  late DateTime _startDate;
  late DateTime _endDate;
  bool _isAllDay = false;
  String _repeatOption = '';
  int _remindValue = 0;
  String _remindUnit = '';
  bool _isSaving = false;

  bool get _isNewSchedule => widget.schedule == null;

  // リピートオプション
  static const List<Map<String, String>> _repeatOptions = [
    {'value': '', 'label': 'なし'},
    {'value': 'daily', 'label': '毎日'},
    {'value': 'weekly', 'label': '毎週'},
    {'value': 'monthly', 'label': '毎月'},
    {'value': 'yearly', 'label': '毎年'},
  ];

  // リマインド単位
  static const List<Map<String, String>> _remindUnits = [
    {'value': '', 'label': 'なし'},
    {'value': 'minutes', 'label': '分前'},
    {'value': 'hours', 'label': '時間前'},
    {'value': 'days', 'label': '日前'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.schedule?.title ?? '');
    _locationController =
        TextEditingController(text: widget.schedule?.location ?? '');
    _memoController = TextEditingController(text: widget.schedule?.memo ?? '');
    _tagController = TextEditingController(text: widget.schedule?.tag ?? '');

    if (widget.schedule != null) {
      final schedule = widget.schedule!;
      _startDate = schedule.startDate;
      _endDate = schedule.endDate;
      _isAllDay = schedule.isAllDay;
      _repeatOption = schedule.repeatOption;
      _remindValue = schedule.remindValue;
      _remindUnit = schedule.remindUnit;
    } else {
      // 新規作成時の初期値
      final initialDate = widget.initialDate ?? DateTime.now();
      _startDate = DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
        9,
        0,
      );
      _endDate = _startDate.add(const Duration(hours: 1));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _memoController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(_isNewSchedule ? '新規予定' : '予定編集'),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed:
                _titleController.text.isEmpty || _isSaving ? null : _saveSchedule,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 上部バナー広告
            if (shouldShowBannerAd) ...[
              const BannerAdContainer(),
              const SizedBox(height: 16),
            ],

            // タイトル
            _buildSectionTitle('タイトル'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'タイトルを入力',
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // 終日スイッチ
            _buildAllDaySection(colorScheme),
            const SizedBox(height: 16),

            // 開始日時
            _buildDateTimeSection(
              colorScheme: colorScheme,
              label: '開始',
              dateTime: _startDate,
              onDateTimeChanged: (dateTime) {
                setState(() {
                  _startDate = dateTime;
                  // 終了日時が開始日時より前にならないように調整
                  if (_endDate.isBefore(_startDate)) {
                    _endDate = _startDate.add(const Duration(hours: 1));
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // 終了日時
            _buildDateTimeSection(
              colorScheme: colorScheme,
              label: '終了',
              dateTime: _endDate,
              onDateTimeChanged: (dateTime) {
                setState(() {
                  _endDate = dateTime;
                });
              },
            ),
            const SizedBox(height: 16),

            // 場所
            _buildSectionTitle('場所'),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: '場所を入力（任意）',
                prefixIcon: const Icon(Icons.location_on_outlined),
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 繰り返し
            _buildRepeatSection(colorScheme),
            const SizedBox(height: 16),

            // リマインド
            _buildRemindSection(colorScheme),
            const SizedBox(height: 16),

            // タグ
            _buildSectionTitle('タグ'),
            const SizedBox(height: 8),
            TextField(
              controller: _tagController,
              decoration: InputDecoration(
                hintText: 'タグを入力（任意）',
                prefixIcon: const Icon(Icons.label_outline),
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // メモ
            _buildSectionTitle('メモ'),
            const SizedBox(height: 8),
            TextField(
              controller: _memoController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'メモを入力（任意）',
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 削除ボタン（編集時のみ）
            if (!_isNewSchedule) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _showDeleteConfirmation,
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text(
                  '予定を削除',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],

            // 下部バナー広告
            if (shouldShowBannerAd) ...[
              const SizedBox(height: 24),
              const BannerAdContainer(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
    );
  }

  Widget _buildAllDaySection(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: _isAllDay ? colorScheme.primary : Colors.grey,
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('終日')),
          Switch(
            value: _isAllDay,
            onChanged: (value) {
              setState(() {
                _isAllDay = value;
                if (value) {
                  // 終日の場合は時刻を00:00にリセット
                  _startDate = DateTime(
                    _startDate.year,
                    _startDate.month,
                    _startDate.day,
                  );
                  _endDate = DateTime(
                    _endDate.year,
                    _endDate.month,
                    _endDate.day,
                    23,
                    59,
                  );
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeSection({
    required ColorScheme colorScheme,
    required String label,
    required DateTime dateTime,
    required ValueChanged<DateTime> onDateTimeChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // 日付選択
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(dateTime, onDateTimeChanged),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('yyyy/MM/dd (E)', 'ja').format(dateTime),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 時刻選択（終日でない場合のみ）
              if (!_isAllDay) ...[
                const SizedBox(width: 16),
                InkWell(
                  onTap: () => _selectTime(dateTime, onDateTimeChanged),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 20),
                        const SizedBox(width: 8),
                        Text(DateFormat('HH:mm').format(dateTime)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRepeatSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('繰り返し'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _repeatOption,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: _repeatOptions.map((option) {
                return DropdownMenuItem<String>(
                  value: option['value'],
                  child: Row(
                    children: [
                      const Icon(Icons.repeat, size: 20),
                      const SizedBox(width: 12),
                      Text(option['label']!),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _repeatOption = value ?? '';
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemindSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('通知'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_outlined),
              const SizedBox(width: 12),
              // 数値入力
              SizedBox(
                width: 60,
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(
                    text: _remindValue > 0 ? _remindValue.toString() : '',
                  ),
                  onChanged: (value) {
                    _remindValue = int.tryParse(value) ?? 0;
                  },
                ),
              ),
              const SizedBox(width: 8),
              // 単位選択
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _remindUnit,
                    isExpanded: true,
                    items: _remindUnits.map((unit) {
                      return DropdownMenuItem<String>(
                        value: unit['value'],
                        child: Text(unit['label']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _remindUnit = value ?? '';
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(
    DateTime current,
    ValueChanged<DateTime> onChanged,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (date != null && mounted) {
      onChanged(DateTime(
        date.year,
        date.month,
        date.day,
        current.hour,
        current.minute,
      ));
    }
  }

  Future<void> _selectTime(
    DateTime current,
    ValueChanged<DateTime> onChanged,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );

    if (time != null && mounted) {
      onChanged(DateTime(
        current.year,
        current.month,
        current.day,
        time.hour,
        time.minute,
      ));
    }
  }

  Future<void> _saveSchedule() async {
    if (_titleController.text.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      if (_isNewSchedule) {
        // 新規作成
        final newSchedule = ScheduleModel(
          id: const Uuid().v4(),
          title: _titleController.text,
          startDate: _startDate,
          endDate: _endDate,
          isAllDay: _isAllDay,
          location: _locationController.text,
          memo: _memoController.text,
          tag: _tagController.text,
          repeatOption: _repeatOption,
          remindValue: _remindValue,
          remindUnit: _remindUnit,
        );
        await ref.read(calendarControllerProvider.notifier).addSchedule(newSchedule);
      } else {
        // 更新
        final updatedSchedule = widget.schedule!.copyWith(
          title: _titleController.text,
          startDate: _startDate,
          endDate: _endDate,
          isAllDay: _isAllDay,
          location: _locationController.text,
          memo: _memoController.text,
          tag: _tagController.text,
          repeatOption: _repeatOption,
          remindValue: _remindValue,
          remindUnit: _remindUnit,
        );
        await ref
            .read(calendarControllerProvider.notifier)
            .updateSchedule(updatedSchedule);
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('予定を削除'),
        content: const Text('この予定を削除してもよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSchedule();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSchedule() async {
    if (widget.schedule == null) return;

    try {
      await ref
          .read(calendarControllerProvider.notifier)
          .deleteSchedule(widget.schedule!.id);
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }
}
