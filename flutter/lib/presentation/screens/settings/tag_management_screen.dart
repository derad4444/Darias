import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// タグプロバイダー
final tagsProvider = StateNotifierProvider<TagsNotifier, List<TagItem>>((ref) {
  return TagsNotifier();
});

class TagItem {
  final String id;
  final String name;
  final Color color;
  final TagCategory category;

  const TagItem({
    required this.id,
    required this.name,
    required this.color,
    required this.category,
  });

  TagItem copyWith({
    String? id,
    String? name,
    Color? color,
    TagCategory? category,
  }) {
    return TagItem(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color.value,
        'category': category.name,
      };

  factory TagItem.fromJson(Map<String, dynamic> json) => TagItem(
        id: json['id'] as String,
        name: json['name'] as String,
        color: Color(json['color'] as int),
        category: TagCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => TagCategory.general,
        ),
      );
}

enum TagCategory {
  general('全般', Icons.label),
  todo('TODO', Icons.check_circle),
  memo('メモ', Icons.note),
  schedule('スケジュール', Icons.event);

  final String label;
  final IconData icon;

  const TagCategory(this.label, this.icon);
}

class TagsNotifier extends StateNotifier<List<TagItem>> {
  TagsNotifier() : super([]) {
    _loadTags();
  }

  Future<void> _loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    final tagsJson = prefs.getStringList('tags') ?? [];

    if (tagsJson.isEmpty) {
      // デフォルトタグを追加
      state = _defaultTags;
      await _saveTags();
    } else {
      state = tagsJson.map((json) {
        final parts = json.split('|');
        if (parts.length >= 4) {
          return TagItem(
            id: parts[0],
            name: parts[1],
            color: Color(int.parse(parts[2])),
            category: TagCategory.values.firstWhere(
              (e) => e.name == parts[3],
              orElse: () => TagCategory.general,
            ),
          );
        }
        return null;
      }).whereType<TagItem>().toList();
    }
  }

  Future<void> _saveTags() async {
    final prefs = await SharedPreferences.getInstance();
    final tagsJson = state.map((t) => '${t.id}|${t.name}|${t.color.value}|${t.category.name}').toList();
    await prefs.setStringList('tags', tagsJson);
  }

  static final _defaultTags = [
    TagItem(id: '1', name: '仕事', color: Colors.blue, category: TagCategory.general),
    TagItem(id: '2', name: 'プライベート', color: Colors.green, category: TagCategory.general),
    TagItem(id: '3', name: '重要', color: Colors.red, category: TagCategory.general),
    TagItem(id: '4', name: '買い物', color: Colors.orange, category: TagCategory.todo),
    TagItem(id: '5', name: 'アイデア', color: Colors.purple, category: TagCategory.memo),
  ];

  Future<void> addTag(TagItem tag) async {
    state = [...state, tag];
    await _saveTags();
  }

  Future<void> updateTag(TagItem tag) async {
    state = state.map((t) => t.id == tag.id ? tag : t).toList();
    await _saveTags();
  }

  Future<void> deleteTag(String id) async {
    state = state.where((t) => t.id != id).toList();
    await _saveTags();
  }

  Future<void> reorderTags(int oldIndex, int newIndex) async {
    final tags = List<TagItem>.from(state);
    final tag = tags.removeAt(oldIndex);
    tags.insert(newIndex < oldIndex ? newIndex : newIndex - 1, tag);
    state = tags;
    await _saveTags();
  }
}

/// タグ管理画面
class TagManagementScreen extends ConsumerWidget {
  const TagManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('タグ管理'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: tags.isEmpty
          ? _EmptyTagView(
              onAdd: () => _showAddTagDialog(context, ref),
            )
          : _TagList(tags: tags),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTagDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTagDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _TagEditDialog(
        onSave: (tag) {
          ref.read(tagsProvider.notifier).addTag(tag);
        },
      ),
    );
  }
}

class _EmptyTagView extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyTagView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.label_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'タグがありません',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'タグを作成してデータを整理しましょう',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('タグを作成'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagList extends ConsumerWidget {
  final List<TagItem> tags;

  const _TagList({required this.tags});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // カテゴリ別にグループ化
    final groupedTags = <TagCategory, List<TagItem>>{};
    for (final tag in tags) {
      groupedTags.putIfAbsent(tag.category, () => []).add(tag);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: TagCategory.values.map((category) {
        final categoryTags = groupedTags[category] ?? [];
        if (categoryTags.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // カテゴリヘッダー
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    category.icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ),
            // タグカード
            ...categoryTags.map((tag) => _TagCard(
                  tag: tag,
                  onEdit: () => _showEditTagDialog(context, ref, tag),
                  onDelete: () => _confirmDelete(context, ref, tag),
                )),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  void _showEditTagDialog(BuildContext context, WidgetRef ref, TagItem tag) {
    showDialog(
      context: context,
      builder: (context) => _TagEditDialog(
        tag: tag,
        onSave: (updatedTag) {
          ref.read(tagsProvider.notifier).updateTag(updatedTag);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, TagItem tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('タグを削除'),
        content: Text('「${tag.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              ref.read(tagsProvider.notifier).deleteTag(tag.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}

class _TagCard extends StatelessWidget {
  final TagItem tag;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TagCard({
    required this.tag,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tag.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.label,
            color: tag.color,
          ),
        ),
        title: Text(tag.name),
        subtitle: Text(tag.category.label),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('編集'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('削除', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              onEdit();
            } else if (value == 'delete') {
              onDelete();
            }
          },
        ),
      ),
    );
  }
}

class _TagEditDialog extends StatefulWidget {
  final TagItem? tag;
  final Function(TagItem) onSave;

  const _TagEditDialog({
    this.tag,
    required this.onSave,
  });

  @override
  State<_TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<_TagEditDialog> {
  late TextEditingController _nameController;
  late Color _selectedColor;
  late TagCategory _selectedCategory;

  static const _colors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tag?.name ?? '');
    _selectedColor = widget.tag?.color ?? Colors.blue;
    _selectedCategory = widget.tag?.category ?? TagCategory.general;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tag == null ? 'タグを追加' : 'タグを編集'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タグ名
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'タグ名',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),

            // カテゴリ
            Text(
              'カテゴリ',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TagCategory.values.map((category) {
                final isSelected = _selectedCategory == category;
                return FilterChip(
                  label: Text(category.label),
                  avatar: Icon(category.icon, size: 18),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = category);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 色選択
            Text(
              '色',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colors.map((color) {
                final isSelected = _selectedColor.value == color.value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            if (_nameController.text.isEmpty) return;

            final tag = TagItem(
              id: widget.tag?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
              name: _nameController.text,
              color: _selectedColor,
              category: _selectedCategory,
            );
            widget.onSave(tag);
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
