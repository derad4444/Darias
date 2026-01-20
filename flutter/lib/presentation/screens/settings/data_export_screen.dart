import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/todo_provider.dart';
import '../../providers/memo_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/diary_provider.dart';

/// データエクスポート画面
class DataExportScreen extends ConsumerStatefulWidget {
  const DataExportScreen({super.key});

  @override
  ConsumerState<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends ConsumerState<DataExportScreen> {
  bool _exportTodos = true;
  bool _exportMemos = true;
  bool _exportSchedules = true;
  bool _exportDiaries = true;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('データエクスポート'),
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
                        'データエクスポートについて',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'アプリ内のデータをJSON形式でエクスポートできます。'
                    'エクスポートしたデータはバックアップとして保存したり、他のアプリで利用することができます。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // エクスポート対象の選択
          Text(
            'エクスポートするデータ',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),

          _ExportOption(
            icon: Icons.check_circle,
            title: 'TODO',
            subtitle: 'タスクとその完了状態',
            value: _exportTodos,
            onChanged: (value) => setState(() => _exportTodos = value),
          ),
          _ExportOption(
            icon: Icons.note,
            title: 'メモ',
            subtitle: 'すべてのメモとタグ',
            value: _exportMemos,
            onChanged: (value) => setState(() => _exportMemos = value),
          ),
          _ExportOption(
            icon: Icons.event,
            title: 'スケジュール',
            subtitle: 'すべての予定',
            value: _exportSchedules,
            onChanged: (value) => setState(() => _exportSchedules = value),
          ),
          _ExportOption(
            icon: Icons.book,
            title: '日記',
            subtitle: 'すべての日記とコメント',
            value: _exportDiaries,
            onChanged: (value) => setState(() => _exportDiaries = value),
          ),

          const SizedBox(height: 24),

          // エクスポートボタン
          FilledButton.icon(
            onPressed: _isExporting ||
                    (!_exportTodos &&
                        !_exportMemos &&
                        !_exportSchedules &&
                        !_exportDiaries)
                ? null
                : _exportData,
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            label: const Text('エクスポート'),
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
                    'エクスポートしたデータには個人情報が含まれる可能性があります。'
                    '安全な場所に保管してください。',
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

  Future<void> _exportData() async {
    setState(() => _isExporting = true);

    try {
      final exportData = <String, dynamic>{
        'exportDate': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0',
      };

      // TODO
      if (_exportTodos) {
        final todosAsync = ref.read(todosProvider);
        todosAsync.whenData((todos) {
          exportData['todos'] = todos.map((t) => {
                'id': t.id,
                'title': t.title,
                'description': t.description,
                'isCompleted': t.isCompleted,
                'priority': t.priority.name,
                'dueDate': t.dueDate?.toIso8601String(),
                'tag': t.tag,
                'createdAt': t.createdAt.toIso8601String(),
                'updatedAt': t.updatedAt.toIso8601String(),
              }).toList();
        });
      }

      // メモ
      if (_exportMemos) {
        final memosAsync = ref.read(memosProvider);
        memosAsync.whenData((memos) {
          exportData['memos'] = memos.map((m) => {
                'id': m.id,
                'title': m.title,
                'content': m.content,
                'tag': m.tag,
                'isPinned': m.isPinned,
                'createdAt': m.createdAt.toIso8601String(),
                'updatedAt': m.updatedAt.toIso8601String(),
              }).toList();
        });
      }

      // スケジュール
      if (_exportSchedules) {
        final schedulesAsync = ref.read(allSchedulesProvider);
        schedulesAsync.whenData((schedules) {
          exportData['schedules'] = schedules.map((s) => {
                'id': s.id,
                'title': s.title,
                'startDate': s.startDate.toIso8601String(),
                'endDate': s.endDate.toIso8601String(),
                'isAllDay': s.isAllDay,
                'location': s.location,
                'memo': s.memo,
                'tag': s.tag,
                'repeatOption': s.repeatOption,
              }).toList();
        });
      }

      // 日記
      if (_exportDiaries) {
        final user = ref.read(userDocProvider).valueOrNull;
        final characterId = user?.characterId;
        if (characterId != null) {
          final diariesAsync = ref.read(diariesProvider(characterId));
          diariesAsync.whenData((diaries) {
            exportData['diaries'] = diaries.map((d) => {
                  'id': d.id,
                  'content': d.content,
                  'date': d.date.toIso8601String(),
                  'userComment': d.userComment,
                }).toList();
          });
        }
      }

      // JSON文字列に変換
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // シェア
      await Share.share(
        jsonString,
        subject: 'DARIAS_export_${DateTime.now().millisecondsSinceEpoch}.json',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('データをエクスポートしました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エクスポートに失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ExportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        secondary: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: (v) => onChanged(v),
      ),
    );
  }
}
