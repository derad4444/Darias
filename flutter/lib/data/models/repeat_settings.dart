/// 繰り返しタイプ
enum RepeatType {
  none('繰り返さない'),
  daily('毎日'),
  weekly('毎週'),
  monthly('毎月'),
  monthStart('月初'),
  monthEnd('月末');

  final String displayName;
  const RepeatType(this.displayName);
}

/// 終了条件タイプ
enum RepeatEndType {
  never('終了しない'),
  onDate('日付で終了'),
  afterOccurrences('回数で終了');

  final String displayName;
  const RepeatEndType(this.displayName);
}

/// 繰り返し設定
class RepeatSettings {
  final RepeatType type;
  final int weekday; // 1=日曜日, 2=月曜日...
  final int dayOfMonth; // 月の何日か
  final RepeatEndType endType;
  final DateTime endDate;
  final int occurrenceCount;

  RepeatSettings({
    this.type = RepeatType.none,
    this.weekday = 1,
    this.dayOfMonth = 1,
    this.endType = RepeatEndType.never,
    DateTime? endDate,
    this.occurrenceCount = 10,
  }) : endDate = endDate ??
            DateTime.now().add(const Duration(days: 365));

  RepeatSettings copyWith({
    RepeatType? type,
    int? weekday,
    int? dayOfMonth,
    RepeatEndType? endType,
    DateTime? endDate,
    int? occurrenceCount,
  }) {
    return RepeatSettings(
      type: type ?? this.type,
      weekday: weekday ?? this.weekday,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      endType: endType ?? this.endType,
      endDate: endDate ?? this.endDate,
      occurrenceCount: occurrenceCount ?? this.occurrenceCount,
    );
  }

  /// 説明文を取得
  String getDescription(DateTime baseDate) {
    String baseDescription;
    switch (type) {
      case RepeatType.none:
        return '繰り返さない';
      case RepeatType.daily:
        baseDescription = '毎日';
      case RepeatType.weekly:
        final weekdayName = _getWeekdayName(baseDate.weekday);
        baseDescription = '毎週$weekdayName';
      case RepeatType.monthly:
        final day = baseDate.day;
        baseDescription = '毎月$day日';
      case RepeatType.monthStart:
        baseDescription = '毎月月初（1日）';
      case RepeatType.monthEnd:
        baseDescription = '毎月月末';
    }

    switch (endType) {
      case RepeatEndType.never:
        return baseDescription;
      case RepeatEndType.onDate:
        final formatted = '${endDate.year}/${endDate.month}/${endDate.day}';
        return '$baseDescription（${formatted}まで）';
      case RepeatEndType.afterOccurrences:
        return '$baseDescription（$occurrenceCount回）';
    }
  }

  String _getWeekdayName(int weekday) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return '${weekdays[(weekday - 1) % 7]}曜日';
  }

  /// 繰り返し日付を生成
  List<DateTime> generateDates(DateTime startDate) {
    if (type == RepeatType.none) return [startDate];

    final dates = <DateTime>[];
    var currentDate = startDate;
    var count = 0;

    while (_shouldContinue(currentDate, count)) {
      dates.add(currentDate);
      count++;

      final nextDate = _getNextDate(currentDate);
      if (nextDate == null) break;
      currentDate = nextDate;
    }

    return dates;
  }

  bool _shouldContinue(DateTime currentDate, int count) {
    switch (endType) {
      case RepeatEndType.never:
        return count < 100; // 安全上限
      case RepeatEndType.onDate:
        return currentDate.isBefore(endDate) ||
            currentDate.isAtSameMomentAs(endDate);
      case RepeatEndType.afterOccurrences:
        return count < occurrenceCount;
    }
  }

  DateTime? _getNextDate(DateTime date) {
    switch (type) {
      case RepeatType.none:
        return null;
      case RepeatType.daily:
        return date.add(const Duration(days: 1));
      case RepeatType.weekly:
        return date.add(const Duration(days: 7));
      case RepeatType.monthly:
        final nextMonth = DateTime(date.year, date.month + 1, 1);
        final maxDayInMonth = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
        final targetDay = dayOfMonth > maxDayInMonth ? maxDayInMonth : dayOfMonth;
        return DateTime(nextMonth.year, nextMonth.month, targetDay,
            date.hour, date.minute);
      case RepeatType.monthStart:
        final nextMonth = DateTime(date.year, date.month + 1, 1,
            date.hour, date.minute);
        return nextMonth;
      case RepeatType.monthEnd:
        final nextMonthEnd = DateTime(date.year, date.month + 2, 0,
            date.hour, date.minute);
        return nextMonthEnd;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'weekday': weekday,
      'dayOfMonth': dayOfMonth,
      'endType': endType.name,
      'endDate': endDate.toIso8601String(),
      'occurrenceCount': occurrenceCount,
    };
  }

  factory RepeatSettings.fromMap(Map<String, dynamic> map) {
    return RepeatSettings(
      type: RepeatType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => RepeatType.none,
      ),
      weekday: map['weekday'] as int? ?? 1,
      dayOfMonth: map['dayOfMonth'] as int? ?? 1,
      endType: RepeatEndType.values.firstWhere(
        (e) => e.name == map['endType'],
        orElse: () => RepeatEndType.never,
      ),
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : null,
      occurrenceCount: map['occurrenceCount'] as int? ?? 10,
    );
  }
}
