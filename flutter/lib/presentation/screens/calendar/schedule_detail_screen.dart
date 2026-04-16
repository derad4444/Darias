import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/repeat_settings.dart';
import '../../../data/models/schedule_model.dart';
import '../../../data/services/notification_service.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/ad_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';
import '../../../data/services/ad_service.dart';
import '../settings/tag_management_screen.dart';
import 'repeat_settings_screen.dart';

/// 繰り返し予定の編集モード
enum RecurringEditMode { single, all }

/// スケジュール詳細・編集画面（iOS版と同じデザイン）
class ScheduleDetailScreen extends ConsumerStatefulWidget {
  /// 編集対象のスケジュール（nullの場合は新規作成）
  final ScheduleModel? schedule;

  /// 新規作成時の初期日付
  final DateTime? initialDate;

  /// 繰り返し予定の編集モード
  final RecurringEditMode recurringEditMode;

  const ScheduleDetailScreen({
    super.key,
    this.schedule,
    this.initialDate,
    this.recurringEditMode = RecurringEditMode.single,
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
  late RepeatSettings _repeatSettings;
  String _tag = '';
  int _remindValue = 0;
  String _remindUnit = '';
  bool _isPublic = true;
  bool _isSaving = false;
  bool _isCreatingRecurring = false;
  int _recurringProgress = 0;
  int _recurringTotal = 0;

  /// どのピッカーが展開中か（null=全て閉じ）
  String? _expandedPicker; // 'start' or 'end'
  /// 年月セレクターが展開中か
  bool _showYearMonthPicker = false;

  bool get _isNewSchedule => widget.schedule == null || widget.schedule!.id.isEmpty;

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
      _repeatSettings = RepeatSettings(
        type: _repeatOptionToType(schedule.repeatOption),
        weekday: schedule.startDate.weekday,
        dayOfMonth: schedule.startDate.day,
      );
      _tag = schedule.tag;
      _remindValue = schedule.remindValue;
      _remindUnit = schedule.remindUnit;
      _isPublic = schedule.isPublic;
    } else {
      // 新規作成時の初期値：iOS版と同じ「次の時間の0分」
      final now = DateTime.now();
      final initialDate = widget.initialDate ?? now;

      _startDate = DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
        now.hour + 1,
        0,
      );
      _endDate = _startDate.add(const Duration(hours: 1));
      _repeatSettings = RepeatSettings();
      // 最後に使用したタグを引き継ぐ
      _tag = ref.read(lastUsedScheduleTagProvider);
    }
  }

  /// repeatOption文字列をRepeatTypeに変換
  static RepeatType _repeatOptionToType(String option) {
    switch (option) {
      case 'daily':
        return RepeatType.daily;
      case 'weekly':
        return RepeatType.weekly;
      case 'monthly':
        return RepeatType.monthly;
      case 'monthStart':
        return RepeatType.monthStart;
      case 'monthEnd':
        return RepeatType.monthEnd;
      default:
        return RepeatType.none;
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
      body: Stack(
        children: [
          Container(
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
                        BannerAdContainer(
                          adUnitId: _isNewSchedule
                              ? AdConfig.scheduleAddTopBannerAdUnitId
                              : AdConfig.scheduleEditTopBannerAdUnitId,
                        ),
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
                            _buildInlineDateRow(
                              label: '開始',
                              dateTime: _startDate,
                              pickerKey: 'start',
                              textColor: textColor,
                              accentColor: accentColor,
                              onDateChanged: (date) {
                                setState(() {
                                  _startDate = DateTime(
                                    date.year, date.month, date.day,
                                    _startDate.hour, _startDate.minute,
                                  );
                                  if (_endDate.isBefore(_startDate)) {
                                    _endDate = _startDate.add(const Duration(hours: 1));
                                  }
                                });
                              },
                              onTimeChanged: (time) {
                                setState(() {
                                  _startDate = DateTime(
                                    _startDate.year, _startDate.month, _startDate.day,
                                    time.hour, time.minute,
                                  );
                                  if (_endDate.isBefore(_startDate)) {
                                    _endDate = _startDate.add(const Duration(hours: 1));
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // 終了
                            _buildInlineDateRow(
                              label: '終了',
                              dateTime: _endDate,
                              pickerKey: 'end',
                              textColor: textColor,
                              accentColor: accentColor,
                              onDateChanged: (date) {
                                setState(() {
                                  _endDate = DateTime(
                                    date.year, date.month, date.day,
                                    _endDate.hour, _endDate.minute,
                                  );
                                });
                              },
                              onTimeChanged: (time) {
                                setState(() {
                                  _endDate = DateTime(
                                    _endDate.year, _endDate.month, _endDate.day,
                                    time.hour, time.minute,
                                  );
                                });
                              },
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
                          label: _repeatSettings.getDescription(_startDate),
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

                      // 公開設定セクション
                      _buildGlassSection(
                        title: '公開設定',
                        textColor: textColor,
                        child: Row(
                          children: [
                            Icon(
                              _isPublic ? Icons.visibility_outlined : Icons.lock_outline,
                              color: textColor.withOpacity(0.7),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('公開する', style: TextStyle(color: textColor, fontSize: 15)),
                                  Text(
                                    _isPublic
                                        ? 'フレンドの共有設定に従って表示されます'
                                        : 'OFFにすると「完全公開」フレンドのみ閲覧可',
                                    style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6)),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isPublic,
                              activeColor: accentColor,
                              onChanged: (value) => setState(() => _isPublic = value),
                            ),
                          ],
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
                            _buildTagRow(textColor, accentColor),
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
                        BannerAdContainer(
                          adUnitId: _isNewSchedule
                              ? AdConfig.scheduleAddBottomBannerAdUnitId
                              : AdConfig.scheduleEditBottomBannerAdUnitId,
                        ),
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
          // 繰り返し予定作成中のオーバーレイ（iOS版と同じ）
          if (_isCreatingRecurring)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '繰り返し予定を作成中...',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_recurringProgress / $_recurringTotal',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          value: _recurringTotal > 0 ? _recurringProgress / _recurringTotal : 0,
                          color: Colors.white,
                          backgroundColor: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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

  /// インライン展開式の日付行（iOS compact DatePicker風）
  Widget _buildInlineDateRow({
    required String label,
    required DateTime dateTime,
    required String pickerKey,
    required Color textColor,
    required Color accentColor,
    required ValueChanged<DateTime> onDateChanged,
    required ValueChanged<TimeOfDay> onTimeChanged,
  }) {
    final isExpanded = _expandedPicker == pickerKey;

    return Column(
      children: [
        // ラベル + 日付表示行
        GestureDetector(
          onTap: () {
            setState(() {
              _expandedPicker = isExpanded ? null : pickerKey;
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(label, style: TextStyle(color: textColor)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isExpanded
                      ? accentColor.withOpacity(0.15)
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: isExpanded
                      ? Border.all(color: accentColor.withOpacity(0.5))
                      : null,
                ),
                child: Text(
                  _isAllDay
                      ? DateFormat('yyyy/MM/dd (E)', 'ja').format(dateTime)
                      : DateFormat('yyyy/MM/dd (E) HH:mm', 'ja').format(dateTime),
                  style: TextStyle(
                    color: isExpanded ? accentColor : textColor,
                    fontWeight: isExpanded ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),

        // インラインカレンダー（展開時）
        if (isExpanded) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // 年月ラベル（タップで年月セレクター展開）
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                            final newMonth = dateTime.month - 1;
                            if (newMonth < 1) {
                              onDateChanged(DateTime(dateTime.year - 1, 12, dateTime.day));
                            } else {
                              final maxDay = DateTime(dateTime.year, newMonth + 1, 0).day;
                              onDateChanged(DateTime(dateTime.year, newMonth, dateTime.day > maxDay ? maxDay : dateTime.day));
                            }
                          },
                          child: Icon(Icons.chevron_left, color: textColor.withOpacity(0.6), size: 24),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showYearMonthPicker = !_showYearMonthPicker;
                            });
                          },
                          child: Row(
                            children: [
                              Text(
                                DateFormat('yyyy年 M月', 'ja').format(dateTime),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _showYearMonthPicker ? accentColor : textColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _showYearMonthPicker
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: _showYearMonthPicker ? accentColor : textColor.withOpacity(0.5),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            final newMonth = dateTime.month + 1;
                            if (newMonth > 12) {
                              onDateChanged(DateTime(dateTime.year + 1, 1, dateTime.day));
                            } else {
                              final maxDay = DateTime(dateTime.year, newMonth + 1, 0).day;
                              onDateChanged(DateTime(dateTime.year, newMonth, dateTime.day > maxDay ? maxDay : dateTime.day));
                            }
                          },
                          child: Icon(Icons.chevron_right, color: textColor.withOpacity(0.6), size: 24),
                        ),
                      ],
                    ),
                  ),
                // 年・月スクロールセレクター（展開時のみ）
                if (_showYearMonthPicker)
                  _YearMonthSelector(
                    year: dateTime.year,
                    month: dateTime.month,
                    textColor: textColor,
                    accentColor: accentColor,
                    onChanged: (year, month) {
                      final maxDay = DateTime(year, month + 1, 0).day;
                      final day = dateTime.day > maxDay ? maxDay : dateTime.day;
                      onDateChanged(DateTime(year, month, day));
                    },
                  ),
                // カレンダー（ヘッダー非表示）
                ClipRect(
                  child: SizedBox(
                    height: 300,
                    child: Stack(
                      children: [
                        Positioned(
                          top: -48,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: Theme.of(context).colorScheme.copyWith(
                                primary: accentColor,
                                onSurface: textColor,
                              ),
                            ),
                            child: CalendarDatePicker(
                              key: ValueKey('${dateTime.year}-${dateTime.month}'),
                              initialDate: dateTime,
                              firstDate: DateTime(DateTime.now().year - 1),
                              lastDate: DateTime(DateTime.now().year + 5, 12, 31),
                              onDateChanged: onDateChanged,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 時間ピッカー（終日でない場合）
                if (!_isAllDay) ...[
                  Divider(color: textColor.withOpacity(0.2), height: 1),
                  _buildInlineTimePicker(
                    time: TimeOfDay.fromDateTime(dateTime),
                    textColor: textColor,
                    accentColor: accentColor,
                    onChanged: onTimeChanged,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// インライン時間ピッカー（スクロールホイール + タップで自由入力）
  Widget _buildInlineTimePicker({
    required TimeOfDay time,
    required Color textColor,
    required Color accentColor,
    required ValueChanged<TimeOfDay> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        height: 120,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, color: textColor.withOpacity(0.7), size: 20),
            const SizedBox(width: 16),
            // 時スクロール
            _TimeWheelPicker(
              value: time.hour,
              maxValue: 23,
              textColor: textColor,
              accentColor: accentColor,
              onChanged: (h) => onChanged(TimeOfDay(hour: h, minute: time.minute)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(':', style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            // 分スクロール
            _TimeWheelPicker(
              value: time.minute,
              maxValue: 59,
              textColor: textColor,
              accentColor: accentColor,
              onChanged: (m) => onChanged(TimeOfDay(hour: time.hour, minute: m)),
            ),
          ],
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

  String _getNotificationLabel() {
    if (_remindValue <= 0 || _remindUnit.isEmpty) {
      return 'なし';
    }
    switch (_remindUnit) {
      case 'minutes':
        return '$_remindValue分前';
      case 'hours':
        return '$_remindValue時間前';
      case 'days':
        return '$_remindValue日前';
      default:
        return 'なし';
    }
  }

  void _showRepeatPicker(Color accentColor, Color textColor) {
    final gradient = ref.read(backgroundGradientProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _RepeatPickerSheet(
        initialSettings: _repeatSettings,
        baseDate: _startDate,
        accentColor: accentColor,
        textColor: textColor,
        backgroundGradient: gradient,
        onSave: (settings) {
          setState(() {
            _repeatSettings = settings;
          });
        },
      ),
    );
  }

  void _showNotificationPicker(Color accentColor, Color textColor) {
    final gradient = ref.read(backgroundGradientProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _NotificationPickerSheet(
        remindValue: _remindValue,
        remindUnit: _remindUnit,
        accentColor: accentColor,
        textColor: textColor,
        backgroundGradient: gradient,
        onSave: (value, unit) {
          setState(() {
            _remindValue = value;
            _remindUnit = unit;
          });
        },
      ),
    );
  }

  /// タグ表示行（カラーサークル付き）
  Widget _buildTagRow(Color textColor, Color accentColor) {
    final tags = ref.watch(tagsProvider);
    final matchingTag = _tag.isEmpty
        ? null
        : tags.where((t) => t.name == _tag).firstOrNull;

    return GestureDetector(
      onTap: () => _showTagPicker(accentColor, textColor),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(
            Icons.label_outline,
            color: textColor.withOpacity(0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          if (matchingTag != null) ...[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: matchingTag.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              _tag.isEmpty ? 'タグを選択' : _tag,
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

  void _showTagPicker(Color accentColor, Color textColor) {
    final tags = ref.read(tagsProvider);
    final gradient = ref.read(backgroundGradientProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: gradient,
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
                'タグを選択',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            // タグなし
            ListTile(
              leading: Icon(Icons.label_off_outlined, color: textColor.withOpacity(0.5)),
              title: Text(
                'なし',
                style: TextStyle(
                  color: _tag.isEmpty ? accentColor : textColor,
                  fontWeight: _tag.isEmpty ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: _tag.isEmpty
                  ? Icon(Icons.check, color: accentColor)
                  : null,
              onTap: () {
                setState(() => _tag = '');
                Navigator.pop(context);
              },
            ),
            // Firestoreタグ一覧
            ...tags.map((tag) {
              final isSelected = _tag == tag.name;
              return ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: tag.color,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  tag.name,
                  style: TextStyle(
                    color: isSelected ? accentColor : textColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check, color: accentColor)
                    : null,
                onTap: () {
                  setState(() => _tag = tag.name);
                  Navigator.pop(context);
                },
              );
            }),
            const Divider(height: 1),
            // タグ管理へのリンク
            ListTile(
              leading: Icon(Icons.settings_outlined, color: accentColor),
              title: Text(
                'タグを管理する',
                style: TextStyle(color: accentColor, fontWeight: FontWeight.w500),
              ),
              trailing: Icon(Icons.chevron_right, color: accentColor.withOpacity(0.7)),
              onTap: () {
                Navigator.pop(context);
                context.push('/tag-management');
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
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
        if (_repeatSettings.type != RepeatType.none) {
          // 繰り返し予定：iOSと同様に複数ドキュメントを生成して保存
          await _saveRecurringSchedules();
          return;
        }
        // 単発予定の新規作成
        final newSchedule = ScheduleModel(
          id: const Uuid().v4(),
          title: _titleController.text,
          startDate: _startDate,
          endDate: _endDate,
          isAllDay: _isAllDay,
          location: _locationController.text,
          memo: _memoController.text,
          tag: _tag,
          repeatOption: '',
          remindValue: _remindValue,
          remindUnit: _remindUnit,
          isPublic: _isPublic,
        );
        await ref.read(calendarControllerProvider.notifier).addSchedule(newSchedule);
        // 最後に使用したタグを記録
        ref.read(lastUsedScheduleTagProvider.notifier).state = _tag;
        // 通知スケジュール（予定通知が有効な場合）
        if (ref.read(notificationSettingsProvider).scheduleNotifications) {
          await NotificationService().scheduleForSchedule(newSchedule);
        }
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
          repeatOption: _repeatSettings.type.name == 'none' ? '' : _repeatSettings.type.name,
          remindValue: _remindValue,
          remindUnit: _remindUnit,
          isPublic: _isPublic,
        );

        if (widget.recurringEditMode == RecurringEditMode.all &&
            widget.schedule!.recurringGroupId != null) {
          // 繰り返し全件更新
          await ref
              .read(calendarControllerProvider.notifier)
              .updateAllRecurringSchedules(
                recurringGroupId: widget.schedule!.recurringGroupId!,
                template: updatedSchedule,
              );
        } else {
          // この予定のみ更新
          await ref
              .read(calendarControllerProvider.notifier)
              .updateSchedule(updatedSchedule);
          // 通知を更新
          await NotificationService().cancelScheduleNotification(updatedSchedule.id);
          if (ref.read(notificationSettingsProvider).scheduleNotifications) {
            await NotificationService().scheduleForSchedule(updatedSchedule);
          }
        }
      }

      if (mounted) {
        context.pop(true);
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

  /// 繰り返し予定を複数ドキュメントとして保存（iOS版の createRecurringSchedules と同等）
  Future<void> _saveRecurringSchedules() async {
    final duration = _endDate.difference(_startDate);
    final recurringDates = _repeatSettings.generateDates(_startDate);
    final groupId = const Uuid().v4();
    final repeatOptionName = _repeatSettings.type.name;

    setState(() {
      _isCreatingRecurring = true;
      _recurringTotal = recurringDates.length;
      _recurringProgress = 0;
    });

    try {
      for (final date in recurringDates) {
        final schedule = ScheduleModel(
          id: const Uuid().v4(),
          title: _titleController.text,
          startDate: date,
          endDate: date.add(duration),
          isAllDay: _isAllDay,
          location: _locationController.text,
          memo: _memoController.text,
          tag: _tag,
          repeatOption: repeatOptionName,
          remindValue: _remindValue,
          remindUnit: _remindUnit,
          recurringGroupId: groupId,
          isPublic: _isPublic,
        );

        await ref.read(calendarControllerProvider.notifier).addSchedule(schedule);

        if (ref.read(notificationSettingsProvider).scheduleNotifications) {
          await NotificationService().scheduleForSchedule(schedule);
        }

        if (mounted) {
          setState(() => _recurringProgress++);
        }
      }

      // 最後に使用したタグを記録
      ref.read(lastUsedScheduleTagProvider.notifier).state = _tag;
      if (mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingRecurring = false;
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _showDeleteConfirmation() async {
    if (widget.schedule == null) return;

    final recurringGroupId = widget.schedule!.recurringGroupId;

    // 繰り返し予定は「すべて / この予定のみ / キャンセル」を選択して即削除
    // 通常予定は確認なしで即削除
    bool deleteAll = false;
    if (recurringGroupId != null) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => SimpleDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('繰り返し予定の削除'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('すべての繰り返し予定', style: TextStyle(color: Colors.red)),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('この予定のみ', style: TextStyle(color: Colors.red)),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      deleteAll = choice;
    }

    await _deleteSchedule(deleteAll: deleteAll);
  }

  Future<void> _deleteSchedule({bool deleteAll = false}) async {
    if (widget.schedule == null) return;

    try {
      await NotificationService().cancelScheduleNotification(widget.schedule!.id);
      if (deleteAll && widget.schedule!.recurringGroupId != null) {
        await ref
            .read(calendarControllerProvider.notifier)
            .deleteAllRecurringSchedules(widget.schedule!.recurringGroupId!);
      } else {
        await ref
            .read(calendarControllerProvider.notifier)
            .deleteSchedule(widget.schedule!.id);
      }
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

/// 通知設定ピッカー（iOS版同様の+/-ボタン+ピルボタンUI）
class _NotificationPickerSheet extends StatefulWidget {
  final int remindValue;
  final String remindUnit;
  final Color accentColor;
  final Color textColor;
  final Gradient backgroundGradient;
  final void Function(int value, String unit) onSave;

  const _NotificationPickerSheet({
    required this.remindValue,
    required this.remindUnit,
    required this.accentColor,
    required this.textColor,
    required this.backgroundGradient,
    required this.onSave,
  });

  @override
  State<_NotificationPickerSheet> createState() =>
      _NotificationPickerSheetState();
}

class _NotificationPickerSheetState extends State<_NotificationPickerSheet> {
  late int _value;
  late String _unit;
  late bool _isEnabled;
  late TextEditingController _valueController;

  static const int _maxValue = 999;

  @override
  void initState() {
    super.initState();
    _value = widget.remindValue > 0 ? widget.remindValue : 10;
    _unit = widget.remindUnit.isNotEmpty ? widget.remindUnit : 'minutes';
    _isEnabled = widget.remindValue > 0 && widget.remindUnit.isNotEmpty;
    _valueController = TextEditingController(text: '$_value');
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
        gradient: widget.backgroundGradient,
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
              color: widget.textColor.withOpacity(0.3),
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
                  child: Text('キャンセル', style: TextStyle(color: widget.textColor)),
                ),
                Text(
                  '通知',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: widget.textColor,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (_isEnabled) {
                      widget.onSave(_value, _unit);
                    } else {
                      widget.onSave(0, '');
                    }
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

          // ON/OFFトグル
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '通知',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: widget.textColor),
                ),
                Switch(
                  value: _isEnabled,
                  activeColor: widget.accentColor,
                  onChanged: (value) {
                    setState(() => _isEnabled = value);
                  },
                ),
              ],
            ),
          ),

          if (_isEnabled) ...[
          const SizedBox(height: 16),

          // -/値/+ コントロール
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // マイナスボタン
                _buildStepperButton(
                  icon: Icons.remove,
                  onTap: _value > 1
                      ? () => setState(() {
                          _value--;
                          _valueController.text = '$_value';
                        })
                      : null,
                  accentColor: widget.accentColor,
                ),
                // 値入力（自由入力 + +/-ボタン）
                Container(
                  width: 80,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _valueController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: widget.textColor,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      counterText: '',
                    ),
                    maxLength: 3,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (text) {
                      final parsed = int.tryParse(text);
                      if (parsed != null && parsed >= 1 && parsed <= _maxValue) {
                        setState(() => _value = parsed);
                      } else if (text.isEmpty) {
                        // 空の場合はそのまま（フォーカスアウト時に補正）
                      } else if (parsed != null && parsed > _maxValue) {
                        setState(() {
                          _value = _maxValue;
                          _valueController.text = '$_maxValue';
                          _valueController.selection = TextSelection.collapsed(offset: '$_maxValue'.length);
                        });
                      }
                    },
                    onSubmitted: (_) {
                      if (_valueController.text.isEmpty || int.tryParse(_valueController.text) == null) {
                        setState(() {
                          _valueController.text = '$_value';
                        });
                      }
                    },
                    onTapOutside: (_) {
                      if (_valueController.text.isEmpty || int.tryParse(_valueController.text) == null) {
                        setState(() {
                          _valueController.text = '$_value';
                        });
                      }
                    },
                  ),
                ),
                // プラスボタン
                _buildStepperButton(
                  icon: Icons.add,
                  onTap: _value < _maxValue
                      ? () => setState(() {
                          _value++;
                          _valueController.text = '$_value';
                        })
                      : null,
                  accentColor: widget.accentColor,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 分・時間・日のピルボタン
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildUnitPill('minutes', '分前'),
                const SizedBox(width: 8),
                _buildUnitPill('hours', '時間前'),
                const SizedBox(width: 8),
                _buildUnitPill('days', '日前'),
              ],
            ),
          ),

          const SizedBox(height: 30),
          ], // if (_isEnabled)
        ],
      ),
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback? onTap,
    required Color accentColor,
  }) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDisabled ? Colors.white.withOpacity(0.2) : accentColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isDisabled ? Colors.grey[400] : accentColor,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildUnitPill(String unitValue, String label) {
    final isSelected = _unit == unitValue;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _unit = unitValue;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? widget.accentColor : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : widget.textColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// スクロールホイール式の時間ピッカー（タップで自由入力対応）
class _TimeWheelPicker extends StatefulWidget {
  final int value;
  final int maxValue;
  final Color textColor;
  final Color accentColor;
  final ValueChanged<int> onChanged;

  const _TimeWheelPicker({
    required this.value,
    required this.maxValue,
    required this.textColor,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  State<_TimeWheelPicker> createState() => _TimeWheelPickerState();
}

class _TimeWheelPickerState extends State<_TimeWheelPicker> {
  late FixedExtentScrollController _scrollController;
  bool _isEditing = false;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _scrollController = FixedExtentScrollController(initialItem: widget.value);
    _textController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant _TimeWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_isEditing) {
      _scrollController.jumpToItem(widget.value);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _textController.text = widget.value.toString().padLeft(2, '0');
    });
    // テキストを全選択状態にする
    Future.microtask(() {
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textController.text.length,
      );
    });
  }

  void _finishEditing() {
    final parsed = int.tryParse(_textController.text);
    if (parsed != null && parsed >= 0 && parsed <= widget.maxValue) {
      widget.onChanged(parsed);
    }
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return SizedBox(
        width: 56,
        height: 44,
        child: TextField(
          controller: _textController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          maxLength: 2,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _MaxValueFormatter(widget.maxValue),
          ],
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: widget.textColor,
          ),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.accentColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.accentColor, width: 2),
            ),
          ),
          onSubmitted: (_) => _finishEditing(),
          onTapOutside: (_) => _finishEditing(),
        ),
      );
    }

    return GestureDetector(
      onTap: _startEditing,
      child: SizedBox(
        width: 56,
        height: 120,
        child: Stack(
          children: [
            // 選択中ハイライト
            Center(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            // ホイール
            ListWheelScrollView.useDelegate(
              controller: _scrollController,
              itemExtent: 36,
              physics: const FixedExtentScrollPhysics(),
              diameterRatio: 1.5,
              perspective: 0.003,
              onSelectedItemChanged: (index) {
                widget.onChanged(index);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: widget.maxValue + 1,
                builder: (context, index) {
                  final isSelected = index == widget.value;
                  return Center(
                    child: Text(
                      index.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: isSelected ? 22 : 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? widget.textColor
                            : widget.textColor.withOpacity(0.4),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 最大値を超える入力を制限するフォーマッター
class _MaxValueFormatter extends TextInputFormatter {
  final int maxValue;
  _MaxValueFormatter(this.maxValue);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final parsed = int.tryParse(newValue.text);
    if (parsed == null) return oldValue;
    if (parsed > maxValue) return oldValue;
    return newValue;
  }
}

/// 繰り返し設定ボトムシート
class _RepeatPickerSheet extends StatefulWidget {
  final RepeatSettings initialSettings;
  final DateTime baseDate;
  final Color accentColor;
  final Color textColor;
  final Gradient backgroundGradient;
  final Function(RepeatSettings) onSave;

  const _RepeatPickerSheet({
    required this.initialSettings,
    required this.baseDate,
    required this.accentColor,
    required this.textColor,
    required this.backgroundGradient,
    required this.onSave,
  });

  @override
  State<_RepeatPickerSheet> createState() => _RepeatPickerSheetState();
}

class _RepeatPickerSheetState extends State<_RepeatPickerSheet> {
  late RepeatType _selectedType;
  late RepeatEndType _selectedEndType;
  late DateTime _selectedEndDate;
  late int _selectedOccurrenceCount;
  bool _showEndDateCalendar = false;
  bool _showEndDateYearMonth = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialSettings.type;
    _selectedEndType = widget.initialSettings.endType;
    _selectedEndDate = widget.initialSettings.endDate;
    _selectedOccurrenceCount = widget.initialSettings.occurrenceCount;
  }

  String _getPreviewText(RepeatType type) {
    switch (type) {
      case RepeatType.none:
        return '';
      case RepeatType.daily:
        return '毎日同じ時間に実行';
      case RepeatType.weekly:
        const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
        final name = '${weekdays[(widget.baseDate.weekday - 1) % 7]}曜日';
        return '毎週$nameに実行';
      case RepeatType.monthly:
        return '毎月${widget.baseDate.day}日に実行';
      case RepeatType.monthStart:
        return '毎月1日に実行';
      case RepeatType.monthEnd:
        return '毎月の最終日に実行';
    }
  }

  bool get _isEndDateInPast {
    if (_selectedType == RepeatType.none) return false;
    if (_selectedEndType != RepeatEndType.onDate) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _selectedEndDate.isBefore(today);
  }

  void _save() {
    if (_isEndDateInPast) return;
    final settings = RepeatSettings(
      type: _selectedType,
      weekday: widget.baseDate.weekday,
      dayOfMonth: widget.baseDate.day,
      endType: _selectedEndType,
      endDate: _selectedEndDate,
      occurrenceCount: _selectedOccurrenceCount,
    );
    widget.onSave(settings);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
        gradient: widget.backgroundGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ハンドル
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.textColor.withOpacity(0.3),
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
                  child: Text('キャンセル', style: TextStyle(color: widget.textColor)),
                ),
                Text(
                  '繰り返し設定',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: widget.textColor,
                  ),
                ),
                TextButton(
                  onPressed: _isEndDateInPast ? null : _save,
                  child: Text('完了', style: TextStyle(
                    color: _isEndDateInPast ? widget.textColor.withOpacity(0.3) : widget.accentColor,
                  )),
                ),
              ],
            ),
          ),
          // コンテンツ
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                // 繰り返しパターン
                ...RepeatType.values.map((type) {
                  final isSelected = _selectedType == type;
                  final preview = _getPreviewText(type);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = type),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(isSelected ? 0.5 : 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: widget.accentColor, width: 2)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type.displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: widget.textColor,
                                  ),
                                ),
                                if (preview.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    preview,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: widget.textColor.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle, color: widget.accentColor),
                        ],
                      ),
                    ),
                  );
                }),

                // 終了条件（繰り返しありの場合）
                if (_selectedType != RepeatType.none) ...[
                  const SizedBox(height: 16),
                  Text(
                    '終了条件',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: widget.accentColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: RepeatEndType.values.map((type) {
                        return RadioListTile<RepeatEndType>(
                          title: Text(type.displayName, style: TextStyle(color: widget.textColor)),
                          value: type,
                          groupValue: _selectedEndType,
                          activeColor: widget.accentColor,
                          onChanged: (value) {
                            if (value != null) setState(() => _selectedEndType = value);
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  // 日付選択
                  if (_selectedEndType == RepeatEndType.onDate) ...[
                    const SizedBox(height: 12),
                    // 終了日ラベル（タップで展開）
                    GestureDetector(
                      onTap: () {
                        setState(() => _showEndDateCalendar = !_showEndDateCalendar);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(_showEndDateCalendar ? 0.4 : 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: _showEndDateCalendar
                              ? Border.all(color: widget.accentColor.withOpacity(0.5))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: widget.accentColor, size: 20),
                            const SizedBox(width: 12),
                            Text('終了日', style: TextStyle(color: widget.textColor)),
                            const Spacer(),
                            Text(
                              DateFormat('yyyy/MM/dd (E)', 'ja').format(_selectedEndDate),
                              style: TextStyle(
                                color: _showEndDateCalendar ? widget.accentColor : widget.textColor.withOpacity(0.7),
                                fontWeight: _showEndDateCalendar ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 過去日付の警告
                    if (_isEndDateInPast)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '終了日は今日以降の日付を選択してください',
                              style: TextStyle(color: Colors.orange, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    // インラインカレンダー（展開時）
                    if (_showEndDateCalendar) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            // 年月ラベル（< 2026年2月 >）
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      final m = _selectedEndDate.month - 1;
                                      if (m < 1) {
                                        setState(() => _selectedEndDate = DateTime(_selectedEndDate.year - 1, 12, 1));
                                      } else {
                                        final maxDay = DateTime(_selectedEndDate.year, m + 1, 0).day;
                                        final day = _selectedEndDate.day > maxDay ? maxDay : _selectedEndDate.day;
                                        setState(() => _selectedEndDate = DateTime(_selectedEndDate.year, m, day));
                                      }
                                    },
                                    child: Icon(Icons.chevron_left, color: widget.textColor.withOpacity(0.6), size: 24),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _showEndDateYearMonth = !_showEndDateYearMonth);
                                    },
                                    child: Row(
                                      children: [
                                        Text(
                                          DateFormat('yyyy年 M月', 'ja').format(_selectedEndDate),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: _showEndDateYearMonth ? widget.accentColor : widget.textColor,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          _showEndDateYearMonth
                                              ? Icons.keyboard_arrow_up
                                              : Icons.keyboard_arrow_down,
                                          color: _showEndDateYearMonth ? widget.accentColor : widget.textColor.withOpacity(0.5),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      final m = _selectedEndDate.month + 1;
                                      if (m > 12) {
                                        setState(() => _selectedEndDate = DateTime(_selectedEndDate.year + 1, 1, 1));
                                      } else {
                                        final maxDay = DateTime(_selectedEndDate.year, m + 1, 0).day;
                                        final day = _selectedEndDate.day > maxDay ? maxDay : _selectedEndDate.day;
                                        setState(() => _selectedEndDate = DateTime(_selectedEndDate.year, m, day));
                                      }
                                    },
                                    child: Icon(Icons.chevron_right, color: widget.textColor.withOpacity(0.6), size: 24),
                                  ),
                                ],
                              ),
                            ),
                            // 年月セレクター
                            if (_showEndDateYearMonth)
                              _YearMonthSelector(
                                year: _selectedEndDate.year,
                                month: _selectedEndDate.month,
                                textColor: widget.textColor,
                                accentColor: widget.accentColor,
                                baseYear: DateTime.now().year,
                                yearCount: 20,
                                onChanged: (year, month) {
                                  final maxDay = DateTime(year, month + 1, 0).day;
                                  final day = _selectedEndDate.day > maxDay ? maxDay : _selectedEndDate.day;
                                  setState(() => _selectedEndDate = DateTime(year, month, day));
                                },
                              ),
                            // カレンダー（ヘッダー非表示）
                            ClipRect(
                              child: SizedBox(
                                height: 300,
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: -48,
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: Theme.of(context).colorScheme.copyWith(
                                            primary: widget.accentColor,
                                            onSurface: widget.textColor,
                                          ),
                                        ),
                                        child: CalendarDatePicker(
                                          key: ValueKey('end-${_selectedEndDate.year}-${_selectedEndDate.month}'),
                                          initialDate: _selectedEndDate,
                                          firstDate: DateTime(DateTime.now().year, 1, 1),
                                          lastDate: DateTime(DateTime.now().year + 20, 12, 31),
                                          onDateChanged: (date) {
                                            setState(() => _selectedEndDate = date);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  // 回数選択
                  if (_selectedEndType == RepeatEndType.afterOccurrences) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.repeat, color: widget.accentColor, size: 20),
                          const SizedBox(width: 12),
                          Text('繰り返し回数', style: TextStyle(color: widget.textColor)),
                          const Spacer(),
                          DropdownButton<int>(
                            value: _selectedOccurrenceCount,
                            dropdownColor: Colors.white,
                            items: List.generate(50, (i) => i + 1)
                                .map((count) => DropdownMenuItem(
                                      value: count,
                                      child: Text('$count回'),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) setState(() => _selectedOccurrenceCount = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 年・月スクロールセレクター
class _YearMonthSelector extends StatefulWidget {
  final int year;
  final int month;
  final Color textColor;
  final Color accentColor;
  final void Function(int year, int month) onChanged;
  final int? baseYear;
  final int? yearCount;

  const _YearMonthSelector({
    required this.year,
    required this.month,
    required this.textColor,
    required this.accentColor,
    required this.onChanged,
    this.baseYear,
    this.yearCount,
  });

  @override
  State<_YearMonthSelector> createState() => _YearMonthSelectorState();
}

class _YearMonthSelectorState extends State<_YearMonthSelector> {
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  bool _isEditingYear = false;
  bool _isEditingMonth = false;
  late TextEditingController _yearTextController;
  late TextEditingController _monthTextController;

  late final int _baseYear;
  late final int _yearCount;

  @override
  void initState() {
    super.initState();
    _baseYear = widget.baseYear ?? (DateTime.now().year - 1);
    _yearCount = widget.yearCount ?? 7;
    _yearController = FixedExtentScrollController(
      initialItem: widget.year - _baseYear,
    );
    _monthController = FixedExtentScrollController(
      initialItem: widget.month - 1,
    );
    _yearTextController = TextEditingController();
    _monthTextController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant _YearMonthSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year && !_isEditingYear) {
      final targetIndex = widget.year - _baseYear;
      if (targetIndex >= 0 && targetIndex < _yearCount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _yearController.hasClients) {
            _yearController.jumpToItem(targetIndex);
          }
        });
      }
    }
    if (oldWidget.month != widget.month && !_isEditingMonth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _monthController.hasClients) {
          _monthController.jumpToItem(widget.month - 1);
        }
      });
    }
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _yearTextController.dispose();
    _monthTextController.dispose();
    super.dispose();
  }

  void _startEditingYear() {
    setState(() {
      _isEditingYear = true;
      _yearTextController.text = widget.year.toString();
    });
    Future.microtask(() {
      _yearTextController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _yearTextController.text.length,
      );
    });
  }

  void _finishEditingYear() {
    final parsed = int.tryParse(_yearTextController.text);
    if (parsed != null) {
      final minYear = _baseYear;
      final maxYear = _baseYear + _yearCount - 1;
      final clamped = parsed.clamp(minYear, maxYear);
      widget.onChanged(clamped, widget.month);
    }
    setState(() => _isEditingYear = false);
  }

  void _startEditingMonth() {
    setState(() {
      _isEditingMonth = true;
      _monthTextController.text = widget.month.toString();
    });
    Future.microtask(() {
      _monthTextController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _monthTextController.text.length,
      );
    });
  }

  void _finishEditingMonth() {
    final parsed = int.tryParse(_monthTextController.text);
    if (parsed != null && parsed >= 1 && parsed <= 12) {
      widget.onChanged(widget.year, parsed);
    }
    setState(() => _isEditingMonth = false);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          const SizedBox(width: 16),
          // 年
          Expanded(
            flex: 3,
            child: _isEditingYear
                ? _buildTextField(
                    controller: _yearTextController,
                    maxLength: 4,
                    onFinish: _finishEditingYear,
                    suffix: '年',
                    hintText: '$_baseYear〜${_baseYear + _yearCount - 1}',
                  )
                : GestureDetector(
                    onDoubleTap: _startEditingYear,
                    child: _buildWheel(
                      controller: _yearController,
                      itemCount: _yearCount,
                      labelBuilder: (index) => '${_baseYear + index}年',
                      selectedIndex: widget.year - _baseYear,
                      onChanged: (index) {
                        widget.onChanged(_baseYear + index, widget.month);
                      },
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          // 月
          Expanded(
            flex: 2,
            child: _isEditingMonth
                ? _buildTextField(
                    controller: _monthTextController,
                    maxLength: 2,
                    maxValue: 12,
                    onFinish: _finishEditingMonth,
                    suffix: '月',
                  )
                : GestureDetector(
                    onDoubleTap: _startEditingMonth,
                    child: _buildWheel(
                      controller: _monthController,
                      itemCount: 12,
                      labelBuilder: (index) => '${index + 1}月',
                      selectedIndex: widget.month - 1,
                      onChanged: (index) {
                        widget.onChanged(widget.year, index + 1);
                      },
                    ),
                  ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required int maxLength,
    required VoidCallback onFinish,
    required String suffix,
    int? maxValue,
    String? hintText,
  }) {
    return Center(
      child: SizedBox(
        width: hintText != null ? 120 : 80,
        height: 44,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          maxLength: maxLength,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            if (maxValue != null) _MaxValueFormatter(maxValue),
          ],
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: widget.textColor,
          ),
          decoration: InputDecoration(
            counterText: '',
            suffixText: suffix,
            suffixStyle: TextStyle(
              fontSize: 14,
              color: widget.textColor.withOpacity(0.6),
            ),
            hintText: hintText,
            hintStyle: TextStyle(
              fontSize: 11,
              color: widget.textColor.withOpacity(0.3),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.accentColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.accentColor, width: 2),
            ),
          ),
          onSubmitted: (_) => onFinish(),
          onTapOutside: (_) => onFinish(),
        ),
      ),
    );
  }

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int) labelBuilder,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return Stack(
      children: [
        // 選択中ハイライト
        Center(
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: widget.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 36,
          physics: const FixedExtentScrollPhysics(),
          diameterRatio: 1.5,
          perspective: 0.003,
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: itemCount,
            builder: (context, index) {
              final isSelected = index == selectedIndex;
              return Center(
                child: Text(
                  labelBuilder(index),
                  style: TextStyle(
                    fontSize: isSelected ? 18 : 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? widget.textColor
                        : widget.textColor.withOpacity(0.4),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
