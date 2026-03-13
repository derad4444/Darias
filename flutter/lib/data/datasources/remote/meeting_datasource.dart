import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../models/meeting_model.dart';
import '../../models/meeting_history_model.dart';
import '../../models/six_person_meeting_model.dart';

/// 会議エラー
class MeetingError implements Exception {
  final String message;
  final MeetingErrorType type;

  MeetingError(this.message, this.type);

  @override
  String toString() => message;
}

enum MeetingErrorType {
  invalidResponse,
  networkError,
  firestoreError,
  meetingNotFound,
  invalidRating,
  premiumRequired,
  timeout,
}

class MeetingDatasource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final String _userId;

  MeetingDatasource({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required String userId,
  })  : _firestore = firestore,
        _functions = functions,
        _userId = userId;

  CollectionReference<Map<String, dynamic>> get _meetingsCollection =>
      _firestore.collection('users').doc(_userId).collection('meetings');

  /// 会議履歴コレクションを取得（iOS版と同じパス）
  CollectionReference<Map<String, dynamic>> _meetingHistoryCollection(String characterId) =>
      _firestore
          .collection('users')
          .doc(_userId)
          .collection('characters')
          .doc(characterId)
          .collection('meeting_history');

  /// shared_meetingsコレクション
  CollectionReference<Map<String, dynamic>> get _sharedMeetingsCollection =>
      _firestore.collection('shared_meetings');

  // ===========================================
  // iOS版と同じAPI: generateOrReuseMeeting
  // ===========================================

  /// 6人会議を生成または既存データを取得（iOS版と同じ）
  Future<GenerateMeetingResponse> generateOrReuseMeeting({
    required String characterId,
    required String concern,
    String? concernCategory,
  }) async {
    debugPrint('🗣️ generateOrReuseMeeting called');
    debugPrint('   userId: $_userId');
    debugPrint('   characterId: $characterId');
    debugPrint('   concern: $concern');

    try {
      final callable = _functions.httpsCallable('generateOrReuseMeeting');

      final params = <String, dynamic>{
        'userId': _userId,
        'characterId': characterId,
        'concern': concern,
      };

      if (concernCategory != null) {
        params['concernCategory'] = concernCategory;
      }

      final result = await callable.call<Map<String, dynamic>>(params);
      final data = result.data;

      debugPrint('✅ generateOrReuseMeeting success');
      debugPrint('   meetingId: ${data['meetingId']}');
      debugPrint('   cacheHit: ${data['cacheHit']}');
      debugPrint('   duration: ${data['duration']}ms');

      return GenerateMeetingResponse.fromMap(data);
    } catch (e) {
      debugPrint('❌ generateOrReuseMeeting error: $e');

      // 利用制限エラーをチェック
      final errorMessage = e.toString();
      if (errorMessage.contains('無料ユーザーは1回のみ') ||
          errorMessage.contains('プレミアムにアップグレード') ||
          errorMessage.contains('プレミアムに')) {
        throw MeetingError(
          '無料プランでは自分会議は1回のみ利用可能です。プレミアムにアップグレードしてください。',
          MeetingErrorType.premiumRequired,
        );
      }
      if (errorMessage.contains('今月の会議利用上限')) {
        throw MeetingError(
          '今月の会議利用上限（30回）に達しました。来月またご利用ください。',
          MeetingErrorType.premiumRequired,
        );
      }

      throw MeetingError(
        '会議の生成に失敗しました: $e',
        MeetingErrorType.networkError,
      );
    }
  }

  /// 特定の会議データを取得（shared_meetingsから）
  Future<SixPersonMeetingModel> fetchMeetingById(String meetingId) async {
    debugPrint('🔍 fetchMeetingById: $meetingId');

    try {
      final doc = await _sharedMeetingsCollection.doc(meetingId).get();

      if (!doc.exists) {
        debugPrint('❌ Meeting not found: $meetingId');
        throw MeetingError(
          '会議データが見つかりません',
          MeetingErrorType.meetingNotFound,
        );
      }

      debugPrint('✅ Meeting found: $meetingId');
      return SixPersonMeetingModel.fromFirestore(doc);
    } catch (e) {
      if (e is MeetingError) rethrow;
      debugPrint('❌ fetchMeetingById error: $e');
      throw MeetingError(
        'データベースエラー: $e',
        MeetingErrorType.firestoreError,
      );
    }
  }

  /// 会議履歴を取得（リアルタイム）- iOS版と同じパスを使用
  Stream<List<MeetingHistoryModel>> watchMeetingHistory({
    required String characterId,
    int? limit,
  }) {
    debugPrint('🗂️ watchMeetingHistory called - userId: $_userId, characterId: $characterId');

    var query = _meetingHistoryCollection(characterId)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      debugPrint('🗂️ Got ${snapshot.docs.length} meeting history from Firestore');
      return snapshot.docs
          .map((doc) => MeetingHistoryModel.fromFirestore(doc))
          .toList();
    });
  }

  /// 会議履歴を取得（一度だけ）
  Future<List<MeetingHistoryModel>> fetchMeetingHistory({
    required String characterId,
    int limit = 20,
  }) async {
    debugPrint('🗂️ fetchMeetingHistory called');
    debugPrint('   userId: $_userId');
    debugPrint('   characterId: $characterId');

    try {
      final snapshot = await _meetingHistoryCollection(characterId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      debugPrint('✅ Got ${snapshot.docs.length} meeting histories');

      return snapshot.docs
          .map((doc) => MeetingHistoryModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ fetchMeetingHistory error: $e');
      throw MeetingError(
        'データベースエラー: $e',
        MeetingErrorType.firestoreError,
      );
    }
  }

  /// 会議に評価をつける
  Future<void> rateMeeting(String meetingId, int rating) async {
    if (rating < 1 || rating > 5) {
      throw MeetingError(
        '評価は1〜5の範囲で指定してください',
        MeetingErrorType.invalidRating,
      );
    }

    debugPrint('⭐ rateMeeting: $meetingId, rating: $rating');

    try {
      await _firestore.runTransaction((transaction) async {
        final meetingRef = _sharedMeetingsCollection.doc(meetingId);
        final doc = await transaction.get(meetingRef);

        if (!doc.exists) {
          throw MeetingError(
            '会議データが見つかりません',
            MeetingErrorType.meetingNotFound,
          );
        }

        final data = doc.data()!;
        final ratings = data['ratings'] as Map<String, dynamic>? ?? {};

        final totalRatings = (ratings['totalRatings'] as int? ?? 0) + 1;
        final ratingSum = (ratings['ratingSum'] as int? ?? 0) + rating;
        final avgRating = ratingSum / totalRatings;

        transaction.update(meetingRef, {
          'ratings': {
            'totalRatings': totalRatings,
            'ratingSum': ratingSum,
            'avgRating': avgRating,
          },
        });
      });

      debugPrint('✅ Rating saved successfully');
    } catch (e) {
      if (e is MeetingError) rethrow;
      debugPrint('❌ rateMeeting error: $e');
      throw MeetingError(
        'データベースエラー: $e',
        MeetingErrorType.firestoreError,
      );
    }
  }

  /// ユーザーの会議利用回数を取得
  Future<int> getMeetingUsageCount(String characterId) async {
    try {
      final snapshot = await _meetingHistoryCollection(characterId).get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('❌ getMeetingUsageCount error: $e');
      return 0;
    }
  }

  // ===========================================
  // 以下は旧API（互換性のため残す）
  // ===========================================

  /// 会議一覧を取得（リアルタイム）- 旧パス（互換性のため残す）
  Stream<List<MeetingModel>> watchMeetings() {
    return _meetingsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MeetingModel.fromFirestore(doc)).toList());
  }

  /// 単一の会議を取得（リアルタイム）
  Stream<MeetingModel?> watchMeeting(String meetingId) {
    return _meetingsCollection.doc(meetingId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return MeetingModel.fromFirestore(doc);
    });
  }

  /// 会議を作成
  Future<String> createMeeting(MeetingModel meeting) async {
    final docRef = await _meetingsCollection.add(meeting.toMap());
    return docRef.id;
  }

  /// 会議を更新
  Future<void> updateMeeting(MeetingModel meeting) async {
    await _meetingsCollection.doc(meeting.id).update({
      ...meeting.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 会議を削除
  Future<void> deleteMeeting(String meetingId) async {
    await _meetingsCollection.doc(meetingId).delete();
  }

  /// 会議履歴を削除
  Future<void> deleteMeetingHistory({
    required String characterId,
    required String historyId,
  }) async {
    await _meetingHistoryCollection(characterId).doc(historyId).delete();
  }

  /// メッセージを追加
  Future<void> addMessage(String meetingId, MeetingMessage message) async {
    await _meetingsCollection.doc(meetingId).update({
      'messages': FieldValue.arrayUnion([message.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 会議をアーカイブ
  Future<void> archiveMeeting(String meetingId) async {
    await _meetingsCollection.doc(meetingId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
