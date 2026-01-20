import 'package:cloud_firestore/cloud_firestore.dart';

/// スケジュールモデル
class ScheduleModel {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final bool isAllDay;
  final String tag;
  final String location;
  final String memo;
  final String repeatOption;
  final int remindValue;
  final String remindUnit;
  final String? recurringGroupId;

  const ScheduleModel({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.isAllDay = false,
    this.tag = '',
    this.location = '',
    this.memo = '',
    this.repeatOption = '',
    this.remindValue = 0,
    this.remindUnit = '',
    this.recurringGroupId,
  });

  /// 期間が複数日にわたるかどうか
  bool get isMultiDay {
    return !_isSameDay(startDate, endDate);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 表示用の日付範囲文字列
  String get dateRangeString {
    if (isMultiDay) {
      return '${startDate.month}/${startDate.day} - ${endDate.month}/${endDate.day}';
    }
    return '${startDate.month}/${startDate.day}';
  }

  factory ScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }

    final startDate = (data['startDate'] as Timestamp?)?.toDate() ??
        (data['date'] as Timestamp?)?.toDate() ??
        DateTime.now();
    final endDate = (data['endDate'] as Timestamp?)?.toDate() ?? startDate;

    return ScheduleModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      startDate: startDate,
      endDate: endDate,
      isAllDay: data['isAllDay'] as bool? ?? false,
      tag: data['tag'] as String? ?? '',
      location: data['location'] as String? ?? '',
      memo: data['memo'] as String? ?? '',
      repeatOption: data['repeatOption'] as String? ?? '',
      remindValue: data['remindValue'] as int? ?? 0,
      remindUnit: data['remindUnit'] as String? ?? '',
      recurringGroupId: data['recurringGroupId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': Timestamp.fromDate(startDate),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isAllDay': isAllDay,
      'tag': tag,
      'location': location,
      'memo': memo,
      'repeatOption': repeatOption,
      'remindValue': remindValue,
      'remindUnit': remindUnit,
      'recurringGroupId': recurringGroupId,
    };
  }

  ScheduleModel copyWith({
    String? id,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    bool? isAllDay,
    String? tag,
    String? location,
    String? memo,
    String? repeatOption,
    int? remindValue,
    String? remindUnit,
    String? recurringGroupId,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isAllDay: isAllDay ?? this.isAllDay,
      tag: tag ?? this.tag,
      location: location ?? this.location,
      memo: memo ?? this.memo,
      repeatOption: repeatOption ?? this.repeatOption,
      remindValue: remindValue ?? this.remindValue,
      remindUnit: remindUnit ?? this.remindUnit,
      recurringGroupId: recurringGroupId ?? this.recurringGroupId,
    );
  }
}
