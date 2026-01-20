import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/repeat_settings.dart';

/// 繰り返し設定画面
class RepeatSettingsScreen extends StatefulWidget {
  final RepeatSettings initialSettings;
  final DateTime baseDate;
  final Function(RepeatSettings) onSave;

  const RepeatSettingsScreen({
    super.key,
    required this.initialSettings,
    required this.baseDate,
    required this.onSave,
  });

  @override
  State<RepeatSettingsScreen> createState() => _RepeatSettingsScreenState();
}

class _RepeatSettingsScreenState extends State<RepeatSettingsScreen> {
  late RepeatType _selectedType;
  late RepeatEndType _selectedEndType;
  late DateTime _selectedEndDate;
  late int _selectedOccurrenceCount;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialSettings.type;
    _selectedEndType = widget.initialSettings.endType;
    _selectedEndDate = widget.initialSettings.endDate;
    _selectedOccurrenceCount = widget.initialSettings.occurrenceCount;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('繰り返し設定'),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('完了'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 繰り返しタイプ選択
          _SectionHeader(title: '繰り返しパターン'),
          ...RepeatType.values.map((type) => _RepeatTypeCard(
                type: type,
                isSelected: _selectedType == type,
                previewText: _getPreviewText(type),
                onTap: () {
                  setState(() => _selectedType = type);
                },
              )),

          // 終了条件（繰り返しありの場合のみ）
          if (_selectedType != RepeatType.none) ...[
            const SizedBox(height: 24),
            _SectionHeader(title: '終了条件'),
            _EndConditionSection(
              selectedEndType: _selectedEndType,
              selectedEndDate: _selectedEndDate,
              selectedOccurrenceCount: _selectedOccurrenceCount,
              onEndTypeChanged: (type) {
                setState(() => _selectedEndType = type);
              },
              onEndDateChanged: (date) {
                setState(() => _selectedEndDate = date);
              },
              onOccurrenceCountChanged: (count) {
                setState(() => _selectedOccurrenceCount = count);
              },
            ),

            // プレビュー
            const SizedBox(height: 24),
            _PreviewSection(
              dates: _generatePreviewDates(),
            ),
          ],
        ],
      ),
    );
  }

  String _getPreviewText(RepeatType type) {
    switch (type) {
      case RepeatType.none:
        return '';
      case RepeatType.daily:
        return '毎日同じ時間に実行';
      case RepeatType.weekly:
        final weekdayName = _getWeekdayName(widget.baseDate.weekday);
        return '毎週$weekdayNameに実行';
      case RepeatType.monthly:
        final day = widget.baseDate.day;
        return '毎月$day日に実行';
      case RepeatType.monthStart:
        return '毎月1日に実行';
      case RepeatType.monthEnd:
        return '毎月の最終日に実行';
    }
  }

  String _getWeekdayName(int weekday) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return '${weekdays[(weekday - 1) % 7]}曜日';
  }

  List<DateTime> _generatePreviewDates() {
    final settings = RepeatSettings(
      type: _selectedType,
      weekday: widget.baseDate.weekday,
      dayOfMonth: widget.baseDate.day,
      endType: _selectedEndType,
      endDate: _selectedEndDate,
      occurrenceCount: _selectedOccurrenceCount,
    );
    return settings.generateDates(widget.baseDate);
  }

  void _save() {
    final settings = RepeatSettings(
      type: _selectedType,
      weekday: widget.baseDate.weekday,
      dayOfMonth: widget.baseDate.day,
      endType: _selectedEndType,
      endDate: _selectedEndDate,
      occurrenceCount: _selectedOccurrenceCount,
    );
    widget.onSave(settings);
    context.pop();
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _RepeatTypeCard extends StatelessWidget {
  final RepeatType type;
  final bool isSelected;
  final String previewText;
  final VoidCallback onTap;

  const _RepeatTypeCard({
    required this.type,
    required this.isSelected,
    required this.previewText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.displayName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    if (previewText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        previewText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EndConditionSection extends StatelessWidget {
  final RepeatEndType selectedEndType;
  final DateTime selectedEndDate;
  final int selectedOccurrenceCount;
  final Function(RepeatEndType) onEndTypeChanged;
  final Function(DateTime) onEndDateChanged;
  final Function(int) onOccurrenceCountChanged;

  const _EndConditionSection({
    required this.selectedEndType,
    required this.selectedEndDate,
    required this.selectedOccurrenceCount,
    required this.onEndTypeChanged,
    required this.onEndDateChanged,
    required this.onOccurrenceCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 終了タイプ選択
        ...RepeatEndType.values.map((type) => RadioListTile<RepeatEndType>(
              title: Text(type.displayName),
              value: type,
              groupValue: selectedEndType,
              onChanged: (value) {
                if (value != null) onEndTypeChanged(value);
              },
              contentPadding: EdgeInsets.zero,
            )),

        // 日付選択（日付で終了の場合）
        if (selectedEndType == RepeatEndType.onDate) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('終了日'),
              subtitle: Text(
                '${selectedEndDate.year}/${selectedEndDate.month}/${selectedEndDate.day}',
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedEndDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (date != null) {
                  onEndDateChanged(date);
                }
              },
            ),
          ),
        ],

        // 回数選択（回数で終了の場合）
        if (selectedEndType == RepeatEndType.afterOccurrences) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.repeat),
                  const SizedBox(width: 16),
                  const Text('繰り返し回数'),
                  const Spacer(),
                  DropdownButton<int>(
                    value: selectedOccurrenceCount,
                    items: List.generate(50, (i) => i + 1)
                        .map((count) => DropdownMenuItem(
                              value: count,
                              child: Text('$count回'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onOccurrenceCountChanged(value);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PreviewSection extends StatelessWidget {
  final List<DateTime> dates;

  const _PreviewSection({required this.dates});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'プレビュー',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...dates.take(5).map((date) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _formatDate(date),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )),
              if (dates.length > 5)
                Text(
                  '...他${dates.length - 5}回',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final weekday = weekdays[(date.weekday - 1) % 7];
    return '${date.month}/${date.day}（$weekday）';
  }
}
