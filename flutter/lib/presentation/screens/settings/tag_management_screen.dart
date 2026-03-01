import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

/// タグプロバイダー（Firestoreで同期）
final tagsProvider = StateNotifierProvider<TagsNotifier, List<TagItem>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final firestore = ref.watch(firestoreProvider);
  return TagsNotifier(userId: userId, firestore: firestore);
});

class TagItem {
  final String id;
  final String name;
  final Color color;
  final String memo;

  const TagItem({
    required this.id,
    required this.name,
    required this.color,
    this.memo = '',
  });

  TagItem copyWith({
    String? id,
    String? name,
    Color? color,
    String? memo,
  }) {
    return TagItem(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      memo: memo ?? this.memo,
    );
  }

  factory TagItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TagItem(
      id: doc.id,
      name: data['name'] as String? ?? '',
      color: _hexToColor(data['colorHex'] as String? ?? '#2196f3'),
      memo: data['memo'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'colorHex': _colorToHex(color),
      'memo': memo,
    };
  }

  static String _colorToHex(Color color) {
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
  }

  static Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      return Color(int.parse('ff$hex', radix: 16));
    }
    return Colors.blue;
  }
}

class TagsNotifier extends StateNotifier<List<TagItem>> {
  final String? userId;
  final FirebaseFirestore firestore;
  StreamSubscription? _subscription;

  TagsNotifier({required this.userId, required this.firestore}) : super([]) {
    _listenToTags();
  }

  CollectionReference get _tagsCollection =>
      firestore.collection('users').doc(userId).collection('tags');

  void _listenToTags() {
    if (userId == null) {
      print('⚠️ TagsNotifier: userId is null, skipping');
      return;
    }
    print('🏷️ TagsNotifier: listening to tags for userId=$userId');
    _subscription = _tagsCollection
        .orderBy('name')
        .snapshots()
        .listen((snapshot) {
      print('🏷️ TagsNotifier: received ${snapshot.docs.length} tags');
      state = snapshot.docs.map((doc) => TagItem.fromFirestore(doc)).toList();
    }, onError: (error) {
      print('❌ TagsNotifier error: $error');
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> addTag(TagItem tag) async {
    if (userId == null) return;
    await _tagsCollection.add(tag.toMap());
  }

  Future<void> updateTag(TagItem tag) async {
    if (userId == null) return;
    await _tagsCollection.doc(tag.id).update(tag.toMap());
  }

  Future<void> deleteTag(String id) async {
    if (userId == null) return;
    await _tagsCollection.doc(id).delete();
  }
}

/// iOS版TagSettingsViewと同じデザインのタグ管理画面
class TagManagementScreen extends ConsumerWidget {
  const TagManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider);
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final colorSettings = ref.watch(colorSettingsProvider);
    final textColor = colorSettings.textColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text('タグ設定', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(
              '完了',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // 既存タグ一覧
              ...tags.map((tag) => _TagRow(
                    tag: tag,
                    textColor: textColor,
                    accentColor: accentColor,
                    onEdit: () => _showEditTagSheet(context, ref, tag, accentColor, textColor),
                    onDelete: () => ref.read(tagsProvider.notifier).deleteTag(tag.id),
                  )),

              const SizedBox(height: 16),

              // 新規追加ボタン
              GestureDetector(
                onTap: () => _showAddTagSheet(context, ref, accentColor, textColor),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        '新しいタグを追加',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTagSheet(BuildContext context, WidgetRef ref, Color accentColor, Color textColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TagEditSheet(
        accentColor: accentColor,
        textColor: textColor,
        onSave: (tag) {
          ref.read(tagsProvider.notifier).addTag(tag);
        },
      ),
    );
  }

  void _showEditTagSheet(BuildContext context, WidgetRef ref, TagItem tag, Color accentColor, Color textColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TagEditSheet(
        tag: tag,
        accentColor: accentColor,
        textColor: textColor,
        onSave: (updatedTag) {
          ref.read(tagsProvider.notifier).updateTag(updatedTag);
        },
      ),
    );
  }
}

/// タグ行
class _TagRow extends StatelessWidget {
  final TagItem tag;
  final Color textColor;
  final Color accentColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TagRow({
    required this.tag,
    required this.textColor,
    required this.accentColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tag.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: tag.color, width: 4)),
      ),
      child: Row(
        children: [
          // タグ名・メモ
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag.name,
                  style: TextStyle(
                    fontSize: 15,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (tag.memo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    tag.memo,
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // 編集ボタン
          IconButton(
            onPressed: onEdit,
            icon: Icon(Icons.edit, color: accentColor),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),

          // 削除ボタン
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete, color: Colors.red),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }
}

/// タグ編集シート
class _TagEditSheet extends ConsumerStatefulWidget {
  final TagItem? tag;
  final Color accentColor;
  final Color textColor;
  final Function(TagItem) onSave;

  const _TagEditSheet({
    this.tag,
    required this.accentColor,
    required this.textColor,
    required this.onSave,
  });

  @override
  ConsumerState<_TagEditSheet> createState() => _TagEditSheetState();
}

class _TagEditSheetState extends ConsumerState<_TagEditSheet> {
  late TextEditingController _nameController;
  late TextEditingController _memoController;
  late Color _selectedColor;

  bool get isEditing => widget.tag != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tag?.name ?? '');
    _memoController = TextEditingController(text: widget.tag?.memo ?? '');
    _selectedColor = widget.tag?.color ?? Colors.blue;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        gradient: backgroundGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ヘッダー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'キャンセル',
                    style: TextStyle(color: widget.accentColor),
                  ),
                ),
                Text(
                  isEditing ? 'タグ編集' : '新規タグ',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: widget.textColor,
                  ),
                ),
                TextButton(
                  onPressed: _nameController.text.trim().isEmpty ? null : _saveTag,
                  child: Text(
                    '保存',
                    style: TextStyle(
                      color: _nameController.text.trim().isEmpty
                          ? Colors.grey
                          : widget.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // タグ名入力
                _SectionCard(
                  title: 'タグ名',
                  textColor: widget.textColor,
                  child: TextField(
                    controller: _nameController,
                    style: TextStyle(color: widget.textColor),
                    decoration: InputDecoration(
                      hintText: 'タグ名を入力',
                      hintStyle: TextStyle(color: widget.textColor.withValues(alpha: 0.5)),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                const SizedBox(height: 16),

                // タグ色選択
                _SectionCard(
                  title: 'タグ色',
                  textColor: widget.textColor,
                  child: Row(
                    children: [
                      Text(
                        '色',
                        style: TextStyle(
                          fontSize: 15,
                          color: widget.textColor,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showColorPicker,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _selectedColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // メモ
                _SectionCard(
                  title: 'メモ',
                  textColor: widget.textColor,
                  child: TextField(
                    controller: _memoController,
                    style: TextStyle(color: widget.textColor),
                    maxLines: 5,
                    minLines: 3,
                    decoration: InputDecoration(
                      hintText: 'メモを入力（任意）',
                      hintStyle: TextStyle(color: widget.textColor.withValues(alpha: 0.5)),
                      border: InputBorder.none,
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

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ColorPickerSheet(
        initialColor: _selectedColor,
        onColorSelected: (color) {
          setState(() => _selectedColor = color);
        },
      ),
    );
  }

  void _saveTag() {
    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) return;

    final tag = TagItem(
      id: widget.tag?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: trimmedName,
      color: _selectedColor,
      memo: _memoController.text.trim(),
    );
    widget.onSave(tag);
    Navigator.pop(context);
  }
}

/// セクションカード
class _SectionCard extends StatelessWidget {
  final String title;
  final Color textColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.textColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// カラーピッカーシート
class _ColorPickerSheet extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  const _ColorPickerSheet({
    required this.initialColor,
    required this.onColorSelected,
  });

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late Color _selectedColor;

  static const List<Color> _presetColors = [
    // 赤系
    Color(0xFFEF9A9A), // red light
    Colors.red,
    Color(0xFFB71C1C), // red dark
    // ピンク系
    Color(0xFFF48FB1), // pink light
    Colors.pink,
    Color(0xFF880E4F), // pink dark
    // 紫系
    Color(0xFFCE93D8), // purple light
    Colors.purple,
    Colors.deepPurple,
    // 藍系
    Color(0xFF9FA8DA), // indigo light
    Colors.indigo,
    // 青系
    Color(0xFF90CAF9), // blue light
    Colors.blue,
    Colors.lightBlue,
    // シアン・ティール系
    Colors.cyan,
    Colors.teal,
    Color(0xFF004D40), // teal dark
    // 緑系
    Color(0xFFA5D6A7), // green light
    Colors.green,
    Color(0xFF1B5E20), // green dark
    Colors.lightGreen,
    // 黄・オレンジ系
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    // ブラウン・グレー系
    Color(0xFF795548), // brown
    Color(0xFF5D4037), // brown dark
    Color(0xFF607D8B), // blue grey
    Color(0xFF455A64), // blue grey dark
    Color(0xFF9E9E9E), // grey
    Color(0xFF424242), // grey dark
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'カラーを選択',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _presetColors.map((color) {
              final isSelected = _selectedColor.toARGB32() == color.toARGB32();
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedColor = color);
                  widget.onColorSelected(color);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
