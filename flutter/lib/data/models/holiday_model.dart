import 'package:cloud_firestore/cloud_firestore.dart';

/// iOS版Holiday.swiftと同じ構造の祝日モデル
class HolidayModel {
  final String id;
  final String name;
  final String dateString; // "YYYY-MM-DD"形式
  final DateTime date;

  HolidayModel({
    required this.id,
    required this.name,
    required this.dateString,
    required this.date,
  });

  factory HolidayModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final dateString = data['dateString'] as String? ?? doc.id;

    // "YYYY-MM-DD"形式をパース
    DateTime parsedDate;
    try {
      final parts = dateString.split('-');
      if (parts.length == 3) {
        parsedDate = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      } else {
        parsedDate = DateTime.now();
      }
    } catch (e) {
      parsedDate = DateTime.now();
    }

    return HolidayModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      dateString: dateString,
      date: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dateString': dateString,
    };
  }

  /// 指定した日付が祝日かどうかをチェック
  bool isOnDate(DateTime targetDate) {
    return date.year == targetDate.year &&
        date.month == targetDate.month &&
        date.day == targetDate.day;
  }
}
