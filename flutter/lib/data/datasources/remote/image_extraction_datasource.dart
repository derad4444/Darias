import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class ImageExtractionDatasource {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  /// 画像をAIで解析し、指定タイプのデータを返す
  /// [imageBase64] JPEG base64文字列
  /// [targetType] 'schedule' | 'memo' | 'todo'
  Future<Map<String, dynamic>> extractFromImage({
    required String imageBase64,
    required String targetType,
  }) async {
    final callable = _functions.httpsCallable('extractFromImage');
    final result = await callable.call({
      'imageBase64': imageBase64,
      'targetType': targetType,
    });

    final data = Map<String, dynamic>.from(result.data as Map);
    if (data.containsKey('error')) {
      throw Exception(data['error']);
    }
    return Map<String, dynamic>.from(data['result'] as Map);
  }

  /// Firestore Timestampをすれ表したMapをDateTimeに変換
  static DateTime? parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      final seconds = (value['_seconds'] as num?)?.toInt();
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
            .toLocal();
      }
    }
    debugPrint('parseTimestamp: unexpected format: $value');
    return null;
  }
}
