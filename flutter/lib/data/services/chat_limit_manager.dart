import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// チャット制限マネージャー
/// 無料ユーザーのチャット回数を追跡し、広告表示タイミングを管理する
class ChatLimitManager {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// 動画広告を表示するチャット間隔
  static const int adFrequency = 5;

  /// 今日のチャット回数
  int _totalChatsToday = 0;

  ChatLimitManager({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// 現在のユーザーID
  String? get _userId => _auth.currentUser?.uid;

  /// 今日のチャット回数
  int get totalChatsToday => _totalChatsToday;

  /// 今日の日付文字列
  String get _todayString {
    final formatter = DateFormat('yyyy-MM-dd');
    return formatter.format(DateTime.now());
  }

  /// チャット回数を取得
  Future<void> fetchChatCount() async {
    final userId = _userId;
    if (userId == null) {
      _totalChatsToday = 0;
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists || doc.data() == null) {
        _totalChatsToday = 0;
        return;
      }

      final data = doc.data()!;
      final usageTracking = data['usage_tracking'] as Map<String, dynamic>?;

      if (usageTracking == null) {
        _totalChatsToday = 0;
        return;
      }

      final count = usageTracking['chat_count_today'] as int? ?? 0;
      final lastDate = usageTracking['last_chat_date'] as String? ?? '';

      // 日付が変わっていたらリセット
      if (lastDate != _todayString) {
        _totalChatsToday = 0;
      } else {
        _totalChatsToday = count;
      }

      print('📊 ChatLimitManager: Today\'s chat count = $_totalChatsToday');
    } catch (e) {
      print('❌ ChatLimitManager: Failed to fetch chat count - $e');
      _totalChatsToday = 0;
    }
  }

  /// チャットを消費（カウントを増やす）
  Future<void> consumeChat() async {
    _totalChatsToday++;
    await _updateFirestore();
  }

  /// Firestoreを更新
  Future<void> _updateFirestore() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'usage_tracking.chat_count_today': _totalChatsToday,
        'usage_tracking.last_chat_date': _todayString,
        'updated_at': Timestamp.now(),
      });
      print('✅ ChatLimitManager: Updated chat count to $_totalChatsToday');
    } catch (e) {
      print('❌ ChatLimitManager: Failed to update Firestore - $e');
    }
  }

  /// 動画広告を表示すべきか判定
  bool shouldShowVideoAd() {
    if (_totalChatsToday <= 0) return false;
    return _totalChatsToday % adFrequency == 0;
  }

  /// 次の広告までのチャット回数
  int get chatsUntilNextAd {
    if (_totalChatsToday <= 0) return adFrequency;
    final remainder = _totalChatsToday % adFrequency;
    return remainder == 0 ? 0 : adFrequency - remainder;
  }

  /// リセット（日付変更時などに呼び出し）
  void reset() {
    _totalChatsToday = 0;
  }
}
