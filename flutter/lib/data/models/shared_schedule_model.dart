import 'package:flutter/material.dart';
import 'schedule_model.dart';

/// フレンドの共有スケジュールモデル（表示専用）
class SharedScheduleModel {
  final ScheduleModel schedule;
  final String ownerId;
  final String ownerName;
  /// フレンド側のタグ色（Cloud Function から取得）
  final Color? tagColor;

  const SharedScheduleModel({
    required this.schedule,
    required this.ownerId,
    required this.ownerName,
    this.tagColor,
  });

  /// Cloud Function のレスポンスからパース
  factory SharedScheduleModel.fromFunctionData(
    Map<String, dynamic> map, {
    required String ownerId,
    required String ownerName,
  }) {
    final startDate = _parseTimestamp(map['startDate']);
    final endDate = _parseTimestamp(map['endDate'] ?? map['startDate']);

    // タグ色を colorHex (#RRGGBB or #AARRGGBB) からパース
    final colorHex = map['tagColorHex'] as String?;
    Color? tagColor;
    if (colorHex != null && colorHex.isNotEmpty) {
      try {
        final hex = colorHex.replaceFirst('#', '');
        final value = int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
        tagColor = Color(value);
      } catch (_) {}
    }

    final schedule = ScheduleModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      startDate: startDate,
      endDate: endDate,
      isAllDay: map['isAllDay'] as bool? ?? false,
      tag: map['tag'] as String? ?? '',
      location: map['location'] as String? ?? '',
      memo: map['memo'] as String? ?? '',
      repeatOption: '',
      remindValue: 0,
      remindUnit: '',
      recurringGroupId: map['recurringGroupId'] as String?,
      isPublic: map['isPublic'] as bool? ?? true,
    );

    return SharedScheduleModel(
      schedule: schedule,
      ownerId: ownerId,
      ownerName: ownerName,
      tagColor: tagColor,
    );
  }

  /// Cloud Function が返す Timestamp（ISO文字列 or _seconds マップ）をパース
  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) {
      try {
        return DateTime.parse(value).toLocal();
      } catch (_) {
        return DateTime.now();
      }
    }
    if (value is Map) {
      final seconds = (value['_seconds'] as num?)?.toInt() ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    return DateTime.now();
  }
}
