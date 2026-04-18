import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/datasources/remote/image_extraction_datasource.dart';
import '../../../data/models/schedule_model.dart';
import '../../providers/calendar_provider.dart';

class BulkScheduleConfirmationScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> rawSchedules;

  const BulkScheduleConfirmationScreen({
    required this.rawSchedules,
    super.key,
  });

  @override
  ConsumerState<BulkScheduleConfirmationScreen> createState() =>
      _BulkScheduleConfirmationScreenState();
}

class _BulkScheduleConfirmationScreenState
    extends ConsumerState<BulkScheduleConfirmationScreen> {
  late List<bool> _selected;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selected = List.filled(widget.rawSchedules.length, true);
  }

  Future<void> _save() async {
    final selectedSchedules = <Map<String, dynamic>>[];
    for (var i = 0; i < widget.rawSchedules.length; i++) {
      if (_selected[i]) selectedSchedules.add(widget.rawSchedules[i]);
    }
    if (selectedSchedules.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);
    try {
      const uuid = Uuid();
      final notifier = ref.read(calendarControllerProvider.notifier);

      for (final raw in selectedSchedules) {
        final startDate = ImageExtractionDatasource.parseTimestamp(raw['startDate']) ??
            DateTime.now();
        final endDate = ImageExtractionDatasource.parseTimestamp(raw['endDate']) ??
            startDate.add(const Duration(hours: 1));

        final schedule = ScheduleModel(
          id: uuid.v4(),
          title: (raw['title'] as String? ?? '').trim().isEmpty
              ? '(タイトルなし)'
              : raw['title'] as String,
          startDate: startDate,
          endDate: endDate,
          isAllDay: raw['isAllDay'] as bool? ?? false,
          location: raw['location'] as String? ?? '',
          memo: raw['memo'] as String? ?? '',
        );
        await notifier.addSchedule(schedule);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${selectedSchedules.length}件の予定を追加しました')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('予定の保存に失敗しました。もう一度お試しください')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDateTime(dynamic raw) {
    final dt = ImageExtractionDatasource.parseTimestamp(raw);
    if (dt == null) return '不明';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = _selected.where((v) => v).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('予定の確認'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('追加 ($selectedCount件)'),
          ),
        ],
      ),
      body: widget.rawSchedules.isEmpty
          ? const Center(child: Text('予定が見つかりませんでした'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        '${widget.rawSchedules.length}件の予定が検出されました',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(
                          () => _selected =
                              List.filled(widget.rawSchedules.length, true),
                        ),
                        child: const Text('全選択'),
                      ),
                      TextButton(
                        onPressed: () => setState(
                          () => _selected =
                              List.filled(widget.rawSchedules.length, false),
                        ),
                        child: const Text('全解除'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.rawSchedules.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final raw = widget.rawSchedules[index];
                      final isAllDay = raw['isAllDay'] as bool? ?? false;
                      final startStr = _formatDateTime(raw['startDate']);
                      final endStr = _formatDateTime(raw['endDate']);
                      final location = raw['location'] as String? ?? '';
                      final memo = raw['memo'] as String? ?? '';

                      return Card(
                        child: CheckboxListTile(
                          value: _selected[index],
                          onChanged: (v) => setState(
                            () => _selected[index] = v ?? false,
                          ),
                          title: Text(
                            (raw['title'] as String? ?? '').trim().isEmpty
                                ? '(タイトルなし)'
                                : raw['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                isAllDay
                                    ? '終日'
                                    : '$startStr 〜 $endStr',
                                style: const TextStyle(fontSize: 13),
                              ),
                              if (location.isNotEmpty)
                                Text(
                                  location,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              if (memo.isNotEmpty)
                                Text(
                                  memo,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          isThreeLine: location.isNotEmpty || memo.isNotEmpty,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
