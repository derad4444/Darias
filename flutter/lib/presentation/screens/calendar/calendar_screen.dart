import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/schedule_model.dart';
import '../../../data/models/holiday_model.dart';
import '../../../data/models/diary_model.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/character_provider.dart';
import '../../providers/diary_provider.dart';
import '../../widgets/draggable_fab.dart';
import '../../widgets/ads/banner_ad_widget.dart';
import '../../providers/ad_provider.dart';
import '../../../data/services/ad_service.dart';
import '../diary/diary_detail_screen.dart';

/// iOS版CalendarViewと同じデザインのカレンダー画面
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// iOS版と同様のボトムシートを表示
  void _showScheduleBottomSheet(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    Color accentColor,
    Color textColor,
  ) {
    final backgroundGradient = ref.read(backgroundGradientProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ScheduleBottomSheet(
        day: day,
        accentColor: accentColor,
        textColor: textColor,
        backgroundGradient: backgroundGradient,
        onNavigateToDetail: (schedule, initialDate) {
          Navigator.of(sheetContext).pop();
          context.push('/calendar/detail', extra: {
            'schedule': schedule,
            'initialDate': initialDate,
          });
        },
        onNavigateToDiary: (date, diary) {
          Navigator.of(sheetContext).pop();
          if (diary != null) {
            // 日記がある場合は日記詳細シートを表示
            final characterId = ref.read(currentCharacterIdProvider) ?? '';
            showDiaryDetailSheet(
              context: context,
              diary: diary,
              characterId: characterId,
              accentColor: accentColor,
            );
          } else {
            // 日記がない場合は日記リスト画面へ
            context.push('/diary');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final colorSettings = ref.watch(colorSettingsProvider);
    final accentColor = colorSettings.accentColor;
    final textColor = colorSettings.textColor;
    final selectedMonth = ref.watch(selectedMonthProvider);
    final selectedDay = ref.watch(selectedDayProvider);
    final schedulesAsync = ref.watch(allSchedulesProvider);
    final isSearchMode = ref.watch(calendarSearchModeProvider);
    final searchText = ref.watch(calendarSearchTextProvider);
    final filteredSchedules = ref.watch(filteredSchedulesProvider);
    final monthlyCommentAsync = ref.watch(monthlyCommentProvider(selectedMonth));
    final holidaysAsync = ref.watch(holidaysProvider);

    return Scaffold(
      body: DraggableFabStack(
        visible: !isSearchMode,
        onTap: () => context.push('/calendar/detail', extra: {
          'schedule': null,
          'initialDate': selectedDay,
        }),
        accentColor: accentColor,
        child: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // ヘッダー（検索モードと通常モードで切り替え）
                  if (isSearchMode)
                    _SearchHeader(
                      controller: _searchController,
                      accentColor: accentColor,
                      textColor: textColor,
                      onClose: () {
                        ref.read(calendarSearchModeProvider.notifier).state = false;
                        ref.read(calendarSearchTextProvider.notifier).state = '';
                        _searchController.clear();
                      },
                      onChanged: (value) {
                        ref.read(calendarSearchTextProvider.notifier).state = value;
                      },
                    )
                  else
                    _CalendarHeader(
                      month: selectedMonth,
                      accentColor: accentColor,
                      textColor: textColor,
                      backgroundGradient: backgroundGradient,
                      onPreviousMonth: () =>
                          ref.read(calendarControllerProvider.notifier).previousMonth(),
                      onNextMonth: () =>
                          ref.read(calendarControllerProvider.notifier).nextMonth(),
                      onTodayTap: () =>
                          ref.read(calendarControllerProvider.notifier).goToToday(),
                      onSearchTap: () {
                        ref.read(calendarSearchModeProvider.notifier).state = true;
                      },
                      onYearMonthSelected: (year, month) {
                        ref.read(calendarControllerProvider.notifier).goToMonth(year, month);
                      },
                    ),

                  // 検索モードの場合は検索結果を表示
                  if (isSearchMode)
                    Expanded(
                      child: _SearchResults(
                        schedules: filteredSchedules,
                        searchText: searchText,
                        accentColor: accentColor,
                        onScheduleTap: (schedule) {
                          ref.read(calendarSearchModeProvider.notifier).state = false;
                          ref.read(calendarSearchTextProvider.notifier).state = '';
                          _searchController.clear();
                          ref.read(selectedDayProvider.notifier).state = schedule.startDate;
                        },
                      ),
                    )
                  else ...[
                    // カレンダーグリッド（iOS版と同様に大きく表示）
                    Expanded(
                      child: schedulesAsync.when(
                        data: (schedules) => holidaysAsync.when(
                          data: (holidays) => _CalendarGrid(
                            month: selectedMonth,
                            selectedDay: selectedDay,
                            schedules: schedules,
                            holidays: holidays,
                            accentColor: accentColor,
                            textColor: textColor,
                            onDaySelected: (day) {
                              ref.read(calendarControllerProvider.notifier).selectDay(day);
                              // iOS版と同様にボトムシートを表示
                              _showScheduleBottomSheet(
                                context,
                                ref,
                                day,
                                accentColor,
                                textColor,
                              );
                            },
                          ),
                          loading: () => _CalendarGrid(
                            month: selectedMonth,
                            selectedDay: selectedDay,
                            schedules: schedules,
                            holidays: const [],
                            accentColor: accentColor,
                            textColor: textColor,
                            onDaySelected: (day) {
                              ref.read(calendarControllerProvider.notifier).selectDay(day);
                              _showScheduleBottomSheet(
                                context,
                                ref,
                                day,
                                accentColor,
                                textColor,
                              );
                            },
                          ),
                          error: (e, st) => _CalendarGrid(
                            month: selectedMonth,
                            selectedDay: selectedDay,
                            schedules: schedules,
                            holidays: const [],
                            accentColor: accentColor,
                            textColor: textColor,
                            onDaySelected: (day) {
                              ref.read(calendarControllerProvider.notifier).selectDay(day);
                              _showScheduleBottomSheet(
                                context,
                                ref,
                                day,
                                accentColor,
                                textColor,
                              );
                            },
                          ),
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, st) => Center(child: Text('エラー: $e', style: TextStyle(color: textColor))),
                      ),
                    ),
                  ],
                ],
              ),

              // キャラクターと月次コメント（iOS版と同様に下部に配置）
              if (!isSearchMode)
                Positioned(
                  left: -20,
                  bottom: 10,
                  child: _CharacterWithComment(
                    monthlyComment: monthlyCommentAsync.when(
                      data: (comment) => comment,
                      loading: () => '今月のひとことを読み込み中...',
                      error: (e, st) => '今月もあなたらしく過ごしてください',
                    ),
                    isLoading: monthlyCommentAsync.isLoading,
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// 検索ヘッダー
class _SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final Color accentColor;
  final Color textColor;
  final VoidCallback onClose;
  final ValueChanged<String> onChanged;

  const _SearchHeader({
    required this.controller,
    required this.accentColor,
    required this.textColor,
    required this.onClose,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 閉じるボタン
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.close,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 検索バー
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '予定を検索',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      onChanged: onChanged,
                    ),
                  ),
                  if (controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        controller.clear();
                        onChanged('');
                      },
                      child: Icon(
                        Icons.cancel,
                        color: Colors.grey.withValues(alpha: 0.6),
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 検索結果
class _SearchResults extends StatelessWidget {
  final List<ScheduleModel> schedules;
  final String searchText;
  final Color accentColor;
  final Function(ScheduleModel) onScheduleTap;

  const _SearchResults({
    required this.schedules,
    required this.searchText,
    required this.accentColor,
    required this.onScheduleTap,
  });

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              searchText.isEmpty ? Icons.calendar_today : Icons.search,
              size: 50,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              searchText.isEmpty ? '予定を検索してください' : '検索結果がありません',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            if (searchText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '「$searchText」に一致する予定が見つかりませんでした',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        return _SearchResultCard(
          schedule: schedule,
          accentColor: accentColor,
          onTap: () => onScheduleTap(schedule),
        );
      },
    );
  }
}

/// 検索結果カード
class _SearchResultCard extends StatelessWidget {
  final ScheduleModel schedule;
  final Color accentColor;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.schedule,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 50,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(schedule.startDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      if (schedule.tag.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            schedule.tag,
                            style: TextStyle(
                              fontSize: 10,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.black38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}

/// カレンダーヘッダー
class _CalendarHeader extends StatelessWidget {
  final DateTime month;
  final Color accentColor;
  final Color textColor;
  final Gradient backgroundGradient;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onTodayTap;
  final VoidCallback onSearchTap;
  final Function(int year, int month) onYearMonthSelected;

  const _CalendarHeader({
    required this.month,
    required this.accentColor,
    required this.textColor,
    required this.backgroundGradient,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onTodayTap,
    required this.onSearchTap,
    required this.onYearMonthSelected,
  });

  void _showYearMonthPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      isDismissible: false,
      builder: (context) => _YearMonthPickerSheet(
        initialYear: month.year,
        initialMonth: month.month,
        accentColor: accentColor,
        textColor: textColor,
        backgroundGradient: backgroundGradient,
        onSelected: (year, month) {
          onYearMonthSelected(year, month);
          Navigator.pop(context);
        },
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 前月ボタン
          GestureDetector(
            onTap: onPreviousMonth,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.chevron_left,
                color: textColor,
              ),
            ),
          ),

          // 年月表示（タップでピッカー表示）
          GestureDetector(
            onTap: () => _showYearMonthPicker(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${month.year}年 ${month.month}月',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  color: textColor,
                  size: 24,
                ),
              ],
            ),
          ),

          // 今日・検索・次月ボタン
          Row(
            children: [
              // 今日ボタン
              GestureDetector(
                onTap: onTodayTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '今日',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 検索ボタン
              GestureDetector(
                onTap: onSearchTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.search,
                    color: accentColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 次月ボタン
              GestureDetector(
                onTap: onNextMonth,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 年月ピッカーシート（スクロールホイール + ダブルタップ自由入力）
class _YearMonthPickerSheet extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  final Color accentColor;
  final Color textColor;
  final Gradient backgroundGradient;
  final Function(int year, int month) onSelected;
  final VoidCallback onClose;

  const _YearMonthPickerSheet({
    required this.initialYear,
    required this.initialMonth,
    required this.accentColor,
    required this.textColor,
    required this.backgroundGradient,
    required this.onSelected,
    required this.onClose,
  });

  @override
  State<_YearMonthPickerSheet> createState() => _YearMonthPickerSheetState();
}

class _YearMonthPickerSheetState extends State<_YearMonthPickerSheet> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
    _selectedMonth = widget.initialMonth;
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: widget.onClose,
                  child: Text('キャンセル', style: TextStyle(color: widget.textColor.withOpacity(0.7))),
                ),
                Text(
                  '年月を選択',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.textColor,
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onSelected(_selectedYear, _selectedMonth),
                  child: Text('決定', style: TextStyle(color: widget.accentColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          // ホイールセレクター
          Expanded(
            child: _CalendarYearMonthSelector(
              year: _selectedYear,
              month: _selectedMonth,
              textColor: widget.textColor,
              accentColor: widget.accentColor,
              onChanged: (year, month) {
                setState(() {
                  _selectedYear = year;
                  _selectedMonth = month;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 年月セレクター（スクロールホイール + ダブルタップ自由入力）
class _CalendarYearMonthSelector extends StatefulWidget {
  final int year;
  final int month;
  final Color textColor;
  final Color accentColor;
  final void Function(int year, int month) onChanged;

  const _CalendarYearMonthSelector({
    required this.year,
    required this.month,
    required this.textColor,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  State<_CalendarYearMonthSelector> createState() => _CalendarYearMonthSelectorState();
}

class _CalendarYearMonthSelectorState extends State<_CalendarYearMonthSelector> {
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  bool _isEditingYear = false;
  bool _isEditingMonth = false;
  late TextEditingController _yearTextController;
  late TextEditingController _monthTextController;

  static final int _baseYear = DateTime.now().year - 5;
  static const int _yearCount = 20; // -5年 ~ +14年

  @override
  void initState() {
    super.initState();
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
  void didUpdateWidget(covariant _CalendarYearMonthSelector oldWidget) {
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
      final clamped = parsed.clamp(_baseYear, _baseYear + _yearCount - 1);
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

/// カレンダーグリッド（iOS版と同様のデザイン）
class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final DateTime? selectedDay;
  final List<ScheduleModel> schedules;
  final List<HolidayModel> holidays;
  final Color accentColor;
  final Color textColor;
  final Function(DateTime) onDaySelected;

  const _CalendarGrid({
    required this.month,
    required this.selectedDay,
    required this.schedules,
    required this.holidays,
    required this.accentColor,
    required this.textColor,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 曜日ヘッダー（固定）
        _buildWeekdayHeader(),
        const SizedBox(height: 4),
        // 日付グリッド
        Expanded(
          child: _buildDaysGrid(),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader() {
    const weekdays = ['日', '月', '火', '水', '木', '金', '土'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(7, (i) {
          return Expanded(
            child: Center(
              child: Text(
                weekdays[i],
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: i == 0
                      ? Colors.red.withValues(alpha: 0.8)
                      : i == 6
                          ? Colors.blue.withValues(alpha: 0.8)
                          : textColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDaysGrid() {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday % 7; // 0=日曜始まり
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth / 7;

          // グリッド上の実際の日付（月外も含む）
          DateTime gridDate(int week, int wd) =>
              firstDay.add(Duration(days: week * 7 + wd - firstWeekday));

          bool isInMonth(DateTime d) =>
              d.year == month.year && d.month == month.month;

          final List<Widget> rows = [];

          for (int week = 0; week < 6; week++) {
            final weekStart = gridDate(week, 0);
            final weekEnd = gridDate(week, 6);

            // この週と重なる複数日予定
            final multiDaySchedules = schedules.where((s) {
              final sd = DateTime(s.startDate.year, s.startDate.month, s.startDate.day);
              final ed = DateTime(s.endDate.year, s.endDate.month, s.endDate.day);
              return sd != ed && !ed.isBefore(weekStart) && !sd.isAfter(weekEnd);
            }).toList()
              ..sort((a, b) => a.startDate.compareTo(b.startDate));

            final multiDaySlotCount = multiDaySchedules.length;

            // 各セル（1日のみの予定）
            final List<Widget> cells = [];
            for (int wd = 0; wd < 7; wd++) {
              final date = gridDate(week, wd);
              if (!isInMonth(date)) {
                cells.add(Expanded(child: Container()));
              } else {
                final dateOnly = DateTime(date.year, date.month, date.day);
                final singleDaySchedules = schedules.where((s) {
                  final sd = DateTime(s.startDate.year, s.startDate.month, s.startDate.day);
                  final ed = DateTime(s.endDate.year, s.endDate.month, s.endDate.day);
                  return sd == ed && sd == dateOnly;
                }).toList()
                  ..sort((a, b) => a.startDate.compareTo(b.startDate));
                final holiday = holidays.where((h) => h.isOnDate(date)).firstOrNull;

                cells.add(Expanded(
                  child: _CalendarDayCell(
                    date: date,
                    isToday: date.year == today.year &&
                        date.month == today.month &&
                        date.day == today.day,
                    isSelected: selectedDay != null &&
                        date.year == selectedDay!.year &&
                        date.month == selectedDay!.month &&
                        date.day == selectedDay!.day,
                    schedules: singleDaySchedules,
                    holiday: holiday,
                    multiDaySlotCount: multiDaySlotCount,
                    accentColor: accentColor,
                    textColor: textColor,
                    onTap: () => onDaySelected(date),
                  ),
                ));
              }
            }

            // 複数日予定のオーバーレイバー
            const barH = 14.0;
            const barGap = 2.0;
            const dateAreaH = 32.0; // SizedBox(2) + Container(28) + 2

            final List<Widget> bars = [];
            for (int slot = 0; slot < multiDaySchedules.length; slot++) {
              final schedule = multiDaySchedules[slot];
              final sd = DateTime(schedule.startDate.year, schedule.startDate.month, schedule.startDate.day);
              final ed = DateTime(schedule.endDate.year, schedule.endDate.month, schedule.endDate.day);
              final isVisualStart = !sd.isBefore(weekStart);
              final isVisualEnd = !ed.isAfter(weekEnd);
              final startWd = isVisualStart ? sd.difference(weekStart).inDays : 0;
              final endWd = isVisualEnd ? ed.difference(weekStart).inDays : 6;
              final left = isVisualStart ? startWd * cellWidth + 1 : 0.0;
              final right = isVisualEnd ? (6 - endWd) * cellWidth + 1 : 0.0;
              final top = dateAreaH + slot * (barH + barGap);
              const r = Radius.circular(2);

              bars.add(Positioned(
                left: left,
                right: right,
                top: top,
                height: barH,
                child: GestureDetector(
                  onTap: () => onDaySelected(sd.isBefore(weekStart) ? weekStart : sd),
                  child: Container(
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.only(
                        topLeft: isVisualStart ? r : Radius.zero,
                        bottomLeft: isVisualStart ? r : Radius.zero,
                        topRight: isVisualEnd ? r : Radius.zero,
                        bottomRight: isVisualEnd ? r : Radius.zero,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    alignment: Alignment.centerLeft,
                    child: isVisualStart
                        ? Text(
                            schedule.title,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                  ),
                ),
              ));
            }

            rows.add(Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(children: cells),
                  ...bars,
                ],
              ),
            ));
          }

          return Column(children: rows);
        },
      ),
    );
  }
}

/// iOS版と同様の日付セル
class _CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final List<ScheduleModel> schedules; // 1日のみの予定
  final HolidayModel? holiday;
  final int multiDaySlotCount; // 複数日予定のプレースホルダー数
  final Color accentColor;
  final Color textColor;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.schedules,
    this.holiday,
    required this.multiDaySlotCount,
    required this.accentColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final weekday = date.weekday % 7;
    final isSunday = weekday == 0;
    final isSaturday = weekday == 6;
    final isHoliday = holiday != null;

    // 日付の色
    Color dateColor;
    if (isSelected) {
      dateColor = Colors.white;
    } else if (isSunday || isHoliday) {
      dateColor = Colors.red.withValues(alpha: 0.8);
    } else if (isSaturday) {
      dateColor = Colors.blue.withValues(alpha: 0.8);
    } else {
      dateColor = textColor;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(1),
        child: Column(
          children: [
            // 日付（iOS版と同様に円形）
            const SizedBox(height: 2),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? accentColor : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !isSelected
                    ? Border.all(color: accentColor, width: 1.5)
                    : null,
              ),
              child: Center(
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: dateColor,
                  ),
                ),
              ),
            ),

            // 予定・祝日表示エリア
            Expanded(
              child: _buildScheduleItems(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItems() {
    final List<Widget> items = [];

    // 複数日予定オーバーレイ用のプレースホルダー（高さを確保）
    for (int i = 0; i < multiDaySlotCount; i++) {
      items.add(const SizedBox(height: 16)); // barH(14) + barGap(2)
    }

    int displayedCount = 0;
    const maxDisplay = 2;

    // 祝日
    if (holiday != null && displayedCount < maxDisplay) {
      items.add(_ScheduleBar(title: holiday!.name, color: Colors.red, isHoliday: true));
      displayedCount++;
    }

    // 1日のみの予定
    for (final schedule in schedules) {
      if (displayedCount >= maxDisplay) break;
      items.add(_ScheduleBar(title: schedule.title, color: accentColor, isHoliday: false));
      displayedCount++;
    }

    // 残り件数
    final totalCount = (holiday != null ? 1 : 0) + schedules.length;
    if (totalCount > maxDisplay) {
      items.add(
        Container(
          margin: const EdgeInsets.only(top: 1),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '+${totalCount - maxDisplay}',
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }
}

/// 予定バー（1日のみ）
class _ScheduleBar extends StatelessWidget {
  final String title;
  final Color color;
  final bool isHoliday;

  const _ScheduleBar({
    required this.title,
    required this.color,
    required this.isHoliday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 1, left: 1, right: 1),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isHoliday ? 0.2 : 0.8),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 8,
          color: isHoliday ? color : Colors.white,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// キャラクターと月次コメント
class _CharacterWithComment extends ConsumerWidget {
  final String monthlyComment;
  final bool isLoading;

  const _CharacterWithComment({
    required this.monthlyComment,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characterImageAsync = ref.watch(characterImageProvider);
    final characterDetails = ref.watch(characterDetailsProvider).valueOrNull;

    // 性別に基づいたデフォルト画像を選択
    final defaultImage = characterDetails?.gender == '男性'
        ? 'assets/images/android_male.png'
        : 'assets/images/android_female.png';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // キャラクター画像
        characterImageAsync.when(
          data: (imageUrl) => imageUrl != null
              ? Image.network(
                  imageUrl,
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      Image.asset(
                        defaultImage,
                        width: 150,
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                )
              : Image.asset(
                  defaultImage,
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
          loading: () => Image.asset(
            defaultImage,
            width: 150,
            height: 150,
            fit: BoxFit.contain,
          ),
          error: (e, st) => Image.asset(
            defaultImage,
            width: 150,
            height: 150,
            fit: BoxFit.contain,
          ),
        ),

        // 吹き出し
        Container(
          constraints: BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '今月のひとこと',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              if (isLoading)
                Text(
                  '読み込み中...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                )
              else
                Text(
                  monthlyComment,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

}

/// スケジュールリスト
class _ScheduleList extends ConsumerWidget {
  final DateTime day;
  final Color accentColor;
  final Color textColor;

  const _ScheduleList({
    required this.day,
    required this.accentColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(daySchedulesProvider(day));
    final holiday = ref.watch(holidayForDateProvider(day));
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);

    return Column(
      children: [
        // 祝日表示
        if (holiday != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.celebration, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Text(
                  holiday.name,
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        // スケジュール一覧
        Expanded(
          child: schedules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_available,
                        size: 48,
                        color: textColor.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '予定がありません',
                        style: TextStyle(
                          fontSize: 15,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: schedules.length,
                  itemBuilder: (context, index) {
                    final schedule = schedules[index];
                    return _ScheduleItem(
                      schedule: schedule,
                      accentColor: accentColor,
                      textColor: textColor,
                    );
                  },
                ),
        ),

        // バナー広告（無料ユーザーのみ）
        if (shouldShowBannerAd) BannerAdContainer(adUnitId: AdConfig.calendarScreenBannerAdUnitId),
      ],
    );
  }
}

/// スケジュールアイテム
class _ScheduleItem extends ConsumerWidget {
  final ScheduleModel schedule;
  final Color accentColor;
  final Color textColor;

  const _ScheduleItem({
    required this.schedule,
    required this.accentColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showEditDialog(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // カラーバー
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),

                // 時間表示
                SizedBox(
                  width: 50,
                  child: Text(
                    schedule.isAllDay
                        ? '終日'
                        : '${schedule.startDate.hour.toString().padLeft(2, '0')}:${schedule.startDate.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      if (schedule.location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                schedule.location,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.black38,
                  ),
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ],
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

/// iOS版と同様のボトムシート（日付選択時に表示）
class _ScheduleBottomSheet extends ConsumerStatefulWidget {
  final DateTime day;
  final Color accentColor;
  final Color textColor;
  final Gradient backgroundGradient;
  final void Function(ScheduleModel? schedule, DateTime? initialDate) onNavigateToDetail;
  final void Function(DateTime date, DiaryModel? diary) onNavigateToDiary;

  const _ScheduleBottomSheet({
    required this.day,
    required this.accentColor,
    required this.textColor,
    required this.backgroundGradient,
    required this.onNavigateToDetail,
    required this.onNavigateToDiary,
  });

  @override
  ConsumerState<_ScheduleBottomSheet> createState() => _ScheduleBottomSheetState();
}

class _ScheduleBottomSheetState extends ConsumerState<_ScheduleBottomSheet> {
  late DateTime _currentDay;

  @override
  void initState() {
    super.initState();
    _currentDay = widget.day;
  }

  String _formatDate(DateTime date) {
    const weekdays = ['日', '月', '火', '水', '木', '金', '土'];
    final weekday = weekdays[date.weekday % 7];
    return '${date.month}月${date.day}日（$weekday）';
  }

  void _goToPreviousDay() {
    setState(() {
      _currentDay = _currentDay.subtract(const Duration(days: 1));
    });
  }

  void _goToNextDay() {
    setState(() {
      _currentDay = _currentDay.add(const Duration(days: 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final schedules = ref.watch(daySchedulesProvider(_currentDay));
    final holiday = ref.watch(holidayForDateProvider(_currentDay));
    final diary = ref.watch(diaryForDateProvider(_currentDay));
    final hasDiary = diary != null;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -100) {
            // 左スワイプ → 翌日
            _goToNextDay();
          } else if (details.primaryVelocity! > 100) {
            // 右スワイプ → 前日
            _goToPreviousDay();
          }
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: widget.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
          children: [
            // 日付ヘッダー
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // 閉じるボタン
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(_currentDay),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.textColor,
                    ),
                  ),
                  const Spacer(),
                  // 追加ボタン
                  GestureDetector(
                    onTap: () {
                      widget.onNavigateToDetail(null, _currentDay);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.add_circle,
                        color: widget.accentColor,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // コンテンツ（iOS版と同様に左に日記アイコン、右に予定リスト）
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左側：日記アイコン（タップで日記画面へ）
                    GestureDetector(
                      onTap: () => widget.onNavigateToDiary(_currentDay, diary),
                      child: Container(
                        width: 80,
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: hasDiary
                                    ? widget.accentColor.withValues(alpha: 0.3)
                                    : Colors.grey.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: hasDiary
                                    ? Border.all(color: widget.accentColor, width: 2)
                                    : null,
                              ),
                              child: Icon(
                                hasDiary ? Icons.auto_stories : Icons.book_outlined,
                                color: hasDiary
                                    ? widget.accentColor
                                    : Colors.grey.withValues(alpha: 0.5),
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasDiary ? '日記あり' : '日記なし',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: hasDiary ? FontWeight.w600 : FontWeight.normal,
                                color: hasDiary
                                    ? widget.accentColor
                                    : widget.textColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 右側：予定リスト
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 祝日表示
                          if (holiday != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.celebration, color: Colors.red, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    holiday.name,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // 予定リスト
                          Expanded(
                            child: schedules.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      '予定はありません',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: widget.textColor.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: schedules.length > 5 ? 5 : schedules.length,
                                    itemBuilder: (context, index) {
                                      final schedule = schedules[index];
                                      return _BottomSheetScheduleRow(
                                        schedule: schedule,
                                        accentColor: widget.accentColor,
                                        textColor: widget.textColor,
                                        onTap: () {
                                          widget.onNavigateToDetail(schedule, null);
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
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
}

/// ボトムシート内の予定行
class _BottomSheetScheduleRow extends StatelessWidget {
  final ScheduleModel schedule;
  final Color accentColor;
  final Color textColor;
  final VoidCallback onTap;

  const _BottomSheetScheduleRow({
    required this.schedule,
    required this.accentColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // カラーバー
            Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),

            // コンテンツ
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    schedule.isAllDay
                        ? '終日'
                        : '${schedule.startDate.hour.toString().padLeft(2, '0')}:${schedule.startDate.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            // 矢印
            Icon(
              Icons.chevron_right,
              color: textColor.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
