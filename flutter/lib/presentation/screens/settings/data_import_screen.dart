import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/todo_model.dart';
import '../../../data/models/memo_model.dart';
import '../../../data/models/schedule_model.dart';
import '../../providers/todo_provider.dart';
import '../../providers/memo_provider.dart';
import '../../providers/calendar_provider.dart';

/// データインポート画面
class DataImportScreen extends ConsumerStatefulWidget {
  const DataImportScreen({super.key});

  @override
  ConsumerState<DataImportScreen> createState() => _DataImportScreenState();
}

class _DataImportScreenState extends ConsumerState<DataImportScreen> {
  final TextEditingController _jsonController = TextEditingController();
  bool _isImporting = false;
  Map<String, dynamic>? _parsedData;
  String? _parseError;

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  void _parseJson() {
    setState(() {
      _parseError = null;
      _parsedData = null;
    });

    final text = _jsonController.text.trim();
    if (text.isEmpty) {
      return;
    }

    try {
      final data = jsonDecode(text) as Map<String, dynamic>;
      setState(() {
        _parsedData = data;
      });
    } catch (e) {
      setState(() {
        _parseError = 'JSONの形式が正しくありません: $e';
      });
    }
  }

  Future<void> _importData() async {
    if (_parsedData == null) return;

    setState(() => _isImporting = true);

    try {
      int importedTodos = 0;
      int importedMemos = 0;
      int importedSchedules = 0;

      // TODOのインポート
      if (_parsedData!.containsKey('todos')) {
        final todos = _parsedData!['todos'] as List<dynamic>;
        for (final todoData in todos) {
          try {
            final todo = TodoModel(
              id: '',
              title: todoData['title'] as String? ?? '',
              description: todoData['description'] as String? ?? '',
              isCompleted: todoData['isCompleted'] as bool? ?? false,
              priority: _parsePriority(todoData['priority'] as String?),
              dueDate: todoData['dueDate'] != null
                  ? DateTime.tryParse(todoData['dueDate'] as String)
                  : null,
              tag: todoData['tag'] as String? ?? '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await ref.read(todoControllerProvider.notifier).addTodo(todo);
            importedTodos++;
          } catch (e) {
            debugPrint('TODO import error: $e');
          }
        }
      }

      // メモのインポート
      if (_parsedData!.containsKey('memos')) {
        final memos = _parsedData!['memos'] as List<dynamic>;
        for (final memoData in memos) {
          try {
            final memo = MemoModel(
              id: '',
              title: memoData['title'] as String? ?? '',
              content: memoData['content'] as String? ?? '',
              tag: memoData['tag'] as String? ?? '',
              isPinned: memoData['isPinned'] as bool? ?? false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await ref.read(memoControllerProvider.notifier).addMemo(memo);
            importedMemos++;
          } catch (e) {
            debugPrint('Memo import error: $e');
          }
        }
      }

      // スケジュールのインポート
      if (_parsedData!.containsKey('schedules')) {
        final schedules = _parsedData!['schedules'] as List<dynamic>;
        for (final scheduleData in schedules) {
          try {
            final schedule = ScheduleModel(
              id: '',
              title: scheduleData['title'] as String? ?? '',
              startDate: DateTime.tryParse(scheduleData['startDate'] as String? ?? '') ?? DateTime.now(),
              endDate: DateTime.tryParse(scheduleData['endDate'] as String? ?? '') ?? DateTime.now(),
              isAllDay: scheduleData['isAllDay'] as bool? ?? false,
              location: scheduleData['location'] as String? ?? '',
              memo: scheduleData['memo'] as String? ?? '',
              tag: scheduleData['tag'] as String? ?? '',
              repeatOption: scheduleData['repeatOption'] as String? ?? 'none',
            );
            await ref.read(calendarControllerProvider.notifier).addSchedule(schedule);
            importedSchedules++;
          } catch (e) {
            debugPrint('Schedule import error: $e');
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'インポート完了: TODO $importedTodos件, メモ $importedMemos件, スケジュール $importedSchedules件',
            ),
          ),
        );
        _jsonController.clear();
        setState(() {
          _parsedData = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('インポートに失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  TodoPriority _parsePriority(String? priority) {
    switch (priority) {
      case 'high':
        return TodoPriority.high;
      case 'medium':
        return TodoPriority.medium;
      case 'low':
        return TodoPriority.low;
      default:
        return TodoPriority.medium;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('データインポート'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 説明
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'データインポートについて',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'エクスポートしたJSONデータを貼り付けて、データをインポートできます。'
                    'インポートされたデータは既存のデータに追加されます。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // JSONテキストエリア
          Text(
            'JSONデータを貼り付け',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _jsonController,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: '{"todos": [...], "memos": [...], ...}',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    _jsonController.text = data!.text!;
                    _parseJson();
                  }
                },
              ),
            ),
            onChanged: (_) => _parseJson(),
          ),

          if (_parseError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _parseError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.red.shade900,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // プレビュー
          if (_parsedData != null) ...[
            const SizedBox(height: 24),
            Text(
              'インポート内容のプレビュー',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _PreviewRow(
                      icon: Icons.check_circle,
                      label: 'TODO',
                      count: (_parsedData!['todos'] as List<dynamic>?)?.length ?? 0,
                    ),
                    const Divider(),
                    _PreviewRow(
                      icon: Icons.note,
                      label: 'メモ',
                      count: (_parsedData!['memos'] as List<dynamic>?)?.length ?? 0,
                    ),
                    const Divider(),
                    _PreviewRow(
                      icon: Icons.event,
                      label: 'スケジュール',
                      count: (_parsedData!['schedules'] as List<dynamic>?)?.length ?? 0,
                    ),
                    if (_parsedData!.containsKey('diaries')) ...[
                      const Divider(),
                      _PreviewRow(
                        icon: Icons.book,
                        label: '日記',
                        count: (_parsedData!['diaries'] as List<dynamic>?)?.length ?? 0,
                        note: '(日記はインポート対象外)',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // インポートボタン
          FilledButton.icon(
            onPressed: _isImporting || _parsedData == null ? null : _importData,
            icon: _isImporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.upload),
            label: const Text('インポート'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

          const SizedBox(height: 16),

          // 注意事項
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'インポートされたデータは既存のデータに追加されます。'
                    '重複するデータがあってもそのまま追加されますのでご注意ください。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.amber.shade900,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final String? note;

  const _PreviewRow({
    required this.icon,
    required this.label,
    required this.count,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label),
          ),
          Text(
            '$count件',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: count > 0
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
          ),
          if (note != null) ...[
            const SizedBox(width: 8),
            Text(
              note!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
