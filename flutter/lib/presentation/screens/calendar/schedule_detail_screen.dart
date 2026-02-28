import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/schedule_model.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/ad_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';

/// スケジュール詳細・編集画面（iOS版と同じデザイン）
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

  late DateTime _startDate;
  late DateTime _endDate;
  bool _isAllDay = false;
  String _repeatOption = '';
  String _tag = '';
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

    if (widget.schedule != null) {
      final schedule = widget.schedule!;
      _startDate = schedule.startDate;
      _endDate = schedule.endDate;
      _isAllDay = schedule.isAllDay;
      _repeatOption = schedule.repeatOption;
      _tag = schedule.tag;
      _remindValue = schedule.remindValue;
      _remindUnit = schedule.remindUnit;
    } else {
      // 新規作成時の初期値（iOS版と同じロジック）
      final initialDate = widget.initialDate ?? DateTime.now();
      final now = DateTime.now();
      final nextHour = now.hour + 1;

      _startDate = DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
        nextHour,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final colorSettings = ref.watch(colorSettingsProvider);
    final accentColor = colorSettings.accentColor;
    final textColor = colorSettings.textColor;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // iOS版と同じカスタムヘッダー
              _buildHeader(accentColor, textColor),

              // スクロール可能なコンテンツ
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 上部バナー広告
                      if (shouldShowBannerAd) ...[
                        const BannerAdContainer(),
                        const SizedBox(height: 20),
                      ],

                      // タイトルセクション
                      _buildGlassSection(
                        title: 'タイトル',
                        textColor: textColor,
                        child: TextField(
                          controller: _titleController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText: '予定のタイトル',
                            hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 日付セクション
                      _buildGlassSection(
                        title: '日付',
                        textColor: textColor,
                        child: Column(
                          children: [
                            // 終日
                            _buildDateRow(
                              label: '終日',
                              textColor: textColor,
                              child: Switch(
                                value: _isAllDay,
                                activeColor: accentColor,
                                onChanged: (value) {
                                  setState(() {
                                    _isAllDay = value;
                                    if (value) {
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
                            ),
                            const SizedBox(height: 16),

                            // 開始
                            _buildDateRow(
                              label: '開始',
                              textColor: textColor,
                              child: _buildDateTimePicker(
                                dateTime: _startDate,
                                textColor: textColor,
                                onChanged: (dateTime) {
                                  setState(() {
                                    _startDate = dateTime;
                                    if (_endDate.isBefore(_startDate)) {
                                      _endDate = _startDate.add(const Duration(hours: 1));
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 終了
                            _buildDateRow(
                              label: '終了',
                              textColor: textColor,
                              child: _buildDateTimePicker(
                                dateTime: _endDate,
                                textColor: textColor,
                                onChanged: (dateTime) {
                                  setState(() {
                                    _endDate = dateTime;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 繰り返しセクション
                      _buildGlassSection(
                        title: '繰り返し',
                        textColor: textColor,
                        child: _buildNavigationRow(
                          icon: Icons.repeat,
                          label: _getRepeatLabel(_repeatOption),
                          textColor: textColor,
                          onTap: () => _showRepeatPicker(accentColor, textColor),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 通知セクション
                      _buildGlassSection(
                        title: '通知',
                        textColor: textColor,
                        child: _buildNavigationRow(
                          icon: Icons.notifications_outlined,
                          label: _getNotificationLabel(),
                          textColor: textColor,
                          onTap: () => _showNotificationPicker(accentColor, textColor),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 詳細セクション
                      _buildGlassSection(
                        title: '詳細',
                        textColor: textColor,
                        child: Column(
                          children: [
                            // 場所
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  color: textColor.withOpacity(0.7),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _locationController,
                                    style: TextStyle(color: textColor),
                                    decoration: InputDecoration(
                                      hintText: '場所',
                                      hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // タグ
                            _buildNavigationRow(
                              icon: Icons.label_outline,
                              label: _tag.isEmpty ? 'タグを選択' : _tag,
                              textColor: textColor,
                              onTap: () => _showTagPicker(accentColor, textColor),
                            ),
                            const SizedBox(height: 16),

                            // メモ
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Icon(
                                    Icons.notes,
                                    color: textColor.withOpacity(0.7),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _memoController,
                                    maxLines: 4,
                                    style: TextStyle(color: textColor),
                                    decoration: InputDecoration(
                                      hintText: 'メモ',
                                      hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 下部バナー広告
                      if (shouldShowBannerAd) ...[
                        const SizedBox(height: 20),
                        const BannerAdContainer(),
                      ],

                      // 削除ボタン（編集時のみ）
                      if (!_isNewSchedule) ...[
                        const SizedBox(height: 24),
                        _buildDeleteButton(accentColor),
                      ],

                      const SizedBox(height: 40),
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

  /// iOS版と同じカスタムヘッダー
  Widget _buildHeader(Color accentColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 閉じるボタン
          GestureDetector(
            onTap: () => context.pop(),
            child: Icon(
              Icons.close,
              color: accentColor,
              size: 28,
            ),
          ),

          // 保存ボタン
          GestureDetector(
            onTap: _titleController.text.isEmpty || _isSaving ? null : _saveSchedule,
            child: _isSaving
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accentColor,
                    ),
                  )
                : Text(
                    '保存',
                    style: TextStyle(
                      color: _titleController.text.isEmpty
                          ? accentColor.withOpacity(0.5)
                          : accentColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// iOS版と同じガラス風セクション
  Widget _buildGlassSection({
    required String title,
    required Color textColor,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: textColor.withOpacity(0.8),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ],
    );
  }

  /// 日付行
  Widget _buildDateRow({
    required String label,
    required Color textColor,
    required Widget child,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(color: textColor),
          ),
        ),
        const Spacer(),
        child,
      ],
    );
  }

  /// 日時ピッカー
  Widget _buildDateTimePicker({
    required DateTime dateTime,
    required Color textColor,
    required ValueChanged<DateTime> onChanged,
  }) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: dateTime,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        );

        if (date != null && mounted) {
          if (_isAllDay) {
            onChanged(date);
          } else {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(dateTime),
            );

            if (time != null && mounted) {
              onChanged(DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              ));
            }
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _isAllDay
              ? DateFormat('yyyy/MM/dd (E)', 'ja').format(dateTime)
              : DateFormat('yyyy/MM/dd (E) HH:mm', 'ja').format(dateTime),
          style: TextStyle(color: textColor),
        ),
      ),
    );
  }

  /// ナビゲーション行（繰り返し、通知、タグ用）
  Widget _buildNavigationRow({
    required IconData icon,
    required String label,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(
            icon,
            color: textColor.withOpacity(0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: textColor),
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: textColor.withOpacity(0.7),
            size: 20,
          ),
        ],
      ),
    );
  }

  /// 削除ボタン
  Widget _buildDeleteButton(Color accentColor) {
    return GestureDetector(
      onTap: _showDeleteConfirmation,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text(
              '予定を削除',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  String _getRepeatLabel(String value) {
    final option = _repeatOptions.firstWhere(
      (o) => o['value'] == value,
      orElse: () => _repeatOptions.first,
    );
    return option['label']!;
  }

  String _getNotificationLabel() {
    if (_remindValue <= 0 || _remindUnit.isEmpty) {
      return 'なし';
    }
    final unitLabel = _remindUnits.firstWhere(
      (u) => u['value'] == _remindUnit,
      orElse: () => _remindUnits.first,
    )['label']!;
    return '$_remindValue$unitLabel';
  }

  void _showRepeatPicker(Color accentColor, Color textColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PickerBottomSheet(
        title: '繰り返し',
        options: _repeatOptions.map((o) => o['label']!).toList(),
        selectedIndex: _repeatOptions.indexWhere((o) => o['value'] == _repeatOption),
        accentColor: accentColor,
        textColor: textColor,
        onSelected: (index) {
          setState(() {
            _repeatOption = _repeatOptions[index]['value']!;
          });
        },
      ),
    );
  }

  void _showNotificationPicker(Color accentColor, Color textColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _NotificationPickerSheet(
        remindValue: _remindValue,
        remindUnit: _remindUnit,
        accentColor: accentColor,
        textColor: textColor,
        onSave: (value, unit) {
          setState(() {
            _remindValue = value;
            _remindUnit = unit;
          });
        },
      ),
    );
  }

  void _showTagPicker(Color accentColor, Color textColor) {
    final tags = ['仕事', 'プライベート', '家族', '健康', '趣味', 'その他'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PickerBottomSheet(
        title: 'タグを選択',
        options: ['なし', ...tags],
        selectedIndex: _tag.isEmpty ? 0 : tags.indexOf(_tag) + 1,
        accentColor: accentColor,
        textColor: textColor,
        onSelected: (index) {
          setState(() {
            _tag = index == 0 ? '' : tags[index - 1];
          });
        },
      ),
    );
  }

  Future<void> _saveSchedule() async {
    if (_titleController.text.isEmpty) return;

    // 日付検証
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('終了日は開始日の後に設定してください')),
      );
      return;
    }

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
          tag: _tag,
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
          tag: _tag,
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

/// 選択ピッカーのボトムシート
class _PickerBottomSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final int selectedIndex;
  final Color accentColor;
  final Color textColor;
  final ValueChanged<int> onSelected;

  const _PickerBottomSheet({
    required this.title,
    required this.options,
    required this.selectedIndex,
    required this.accentColor,
    required this.textColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ハンドル
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // タイトル
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // オプション
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = index == selectedIndex;

            return ListTile(
              title: Text(
                option,
                style: TextStyle(
                  color: isSelected ? accentColor : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check, color: accentColor)
                  : null,
              onTap: () {
                onSelected(index);
                Navigator.pop(context);
              },
            );
          }),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// 通知設定ピッカー
class _NotificationPickerSheet extends StatefulWidget {
  final int remindValue;
  final String remindUnit;
  final Color accentColor;
  final Color textColor;
  final void Function(int value, String unit) onSave;

  const _NotificationPickerSheet({
    required this.remindValue,
    required this.remindUnit,
    required this.accentColor,
    required this.textColor,
    required this.onSave,
  });

  @override
  State<_NotificationPickerSheet> createState() => _NotificationPickerSheetState();
}

class _NotificationPickerSheetState extends State<_NotificationPickerSheet> {
  late int _value;
  late String _unit;

  static const List<Map<String, String>> _units = [
    {'value': '', 'label': 'なし'},
    {'value': 'minutes', 'label': '分前'},
    {'value': 'hours', 'label': '時間前'},
    {'value': 'days', 'label': '日前'},
  ];

  @override
  void initState() {
    super.initState();
    _value = widget.remindValue;
    _unit = widget.remindUnit;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ハンドル
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ヘッダー
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                const Text(
                  '通知',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    widget.onSave(_value, _unit);
                    Navigator.pop(context);
                  },
                  child: Text(
                    '保存',
                    style: TextStyle(color: widget.accentColor),
                  ),
                ),
              ],
            ),
          ),

          // 値と単位の選択
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                // 数値入力
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    controller: TextEditingController(
                      text: _value > 0 ? _value.toString() : '',
                    ),
                    onChanged: (text) {
                      _value = int.tryParse(text) ?? 0;
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // 単位選択
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _unit,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: _units.map((u) {
                      return DropdownMenuItem(
                        value: u['value'],
                        child: Text(u['label']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _unit = value ?? '';
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
