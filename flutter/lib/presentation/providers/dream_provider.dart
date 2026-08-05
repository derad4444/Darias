import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'character_provider.dart';

/// 夢の最大文字数（Cloud Functions 側の DREAM_MAX_LENGTH と揃えること）
const int kDreamMaxLength = 40;

/// 改行・タブを含む制御文字（プロンプトの行構造を壊させないため除去する）
final RegExp _controlChars = RegExp('[\u0000-\u001F\u007F]+');

/// キャラクターの夢の状態
///
/// `users/{userId}/characters/{characterId}/dream/current` に保存される。
/// `details/current` は firestore.rules でフレンドからも単体取得できるため、
/// ユーザーが自由入力できる夢は本人限定のこのドキュメントに置いている。
class DreamState {
  /// 現在採用中の夢（未選択なら空文字）
  final String dream;

  /// AIが性格から生成した候補
  final List<String> dreamOptions;

  /// 夢の由来。'user' はユーザーが選択・入力したもの
  final String dreamSource;

  /// 性格が変わって新しい候補ができたことを示すフラグ
  final bool pendingProposal;

  const DreamState({
    this.dream = '',
    this.dreamOptions = const [],
    this.dreamSource = '',
    this.pendingProposal = false,
  });

  /// ユーザー自身が選択・入力した夢かどうか
  bool get isChosenByUser => dreamSource == 'user';

  /// 夢がまだ決まっていないかどうか
  bool get isUnset => dream.isEmpty;

  /// 選択できる候補があるかどうか
  bool get hasOptions => dreamOptions.isNotEmpty;

  factory DreamState.fromMap(Map<String, dynamic> data) {
    final rawOptions = data['dreamOptions'] as List<dynamic>?;
    return DreamState(
      dream: (data['dream'] as String?)?.trim() ?? '',
      dreamOptions: rawOptions
              ?.whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      dreamSource: (data['dreamSource'] as String?) ?? '',
      pendingProposal: (data['pendingDreamProposal'] as bool?) ?? false,
    );
  }
}

/// 現在のキャラクターの夢を購読するプロバイダー
final dreamProvider = StreamProvider<DreamState?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final characterId = ref.watch(currentCharacterIdProvider);

  if (userId == null || characterId == null) {
    return Stream.value(null);
  }

  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(userId)
      .collection('characters')
      .doc(characterId)
      .collection('dream')
      .doc('current')
      .snapshots()
      .map((doc) {
    final data = doc.data();
    if (!doc.exists || data == null) return const DreamState();
    return DreamState.fromMap(data);
  });
});

/// 初回の性格確定で夢の候補ができたことを示すフラグを購読するプロバイダー
///
/// 初回はキャラクター詳細が生成されても通知が一切なく、ユーザーが夢を選ぶ
/// 機会がなかったため、`calculateAndSaveAxisScores` が立てるこのフラグを
/// ホーム画面で監視して選択ダイアログを表示する。
final pendingFirstDreamSelectionProvider = StreamProvider<bool>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(false);

  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(userId)
      .collection('personalityMeta')
      .doc('current')
      .snapshots()
      .map((doc) => (doc.data()?['pendingFirstDreamSelection'] as bool?) ?? false);
});

/// 夢の保存・フラグ解除を行うサービス
class DreamService {
  final FirebaseFirestore _firestore;
  final String? _userId;
  final String? _characterId;

  DreamService(this._firestore, this._userId, this._characterId);

  DocumentReference<Map<String, dynamic>>? get _dreamRef {
    final userId = _userId;
    final characterId = _characterId;
    if (userId == null || characterId == null) return null;
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('dream')
        .doc('current');
  }

  /// 夢のテキストを保存可能な形に整える
  ///
  /// 夢はチャット・日記のシステムプロンプトに埋め込まれるため、改行や制御文字で
  /// プロンプトの行構造を壊されないようにし、長さも制限する。
  /// Cloud Functions 側の `sanitizeDream` と同じ規則。
  static String sanitize(String value) {
    final collapsed = value
        .replaceAll(_controlChars, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // サロゲートペア（絵文字など）を途中で割らないようコードポイント単位で切る
    final runes = collapsed.runes.toList();
    if (runes.length <= kDreamMaxLength) return collapsed;
    return String.fromCharCodes(runes.take(kDreamMaxLength));
  }

  /// ユーザーが選んだ（または入力した）夢を保存する
  Future<void> selectDream(String dream) async {
    final ref = _dreamRef;
    if (ref == null) return;

    final sanitized = sanitize(dream);
    if (sanitized.isEmpty) return;

    await ref.set({
      'dream': sanitized,
      'dreamSource': 'user',
      'dreamUpdatedAt': FieldValue.serverTimestamp(),
      'pendingDreamProposal': false,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _clearFirstSelectionFlag();
  }

  /// 「あとで選ぶ」を選んだときに候補の1個目を暫定採用する
  ///
  /// 夢を空のままにするとチャットが「夢はまだ決まっていません」に切り替わり、
  /// 従来より体験が悪くなるため、暫定値を入れて後から変更できるようにする。
  Future<void> deferSelection(List<String> options) async {
    final ref = _dreamRef;
    if (ref == null) return;

    final payload = <String, dynamic>{
      'pendingDreamProposal': false,
      'updated_at': FieldValue.serverTimestamp(),
    };

    final fallback = options.isNotEmpty ? sanitize(options.first) : '';
    if (fallback.isNotEmpty) {
      final snap = await ref.get();
      final currentDream = (snap.data()?['dream'] as String?)?.trim() ?? '';
      if (currentDream.isEmpty) {
        payload['dream'] = fallback;
        payload['dreamSource'] = 'ai';
      }
    }

    await ref.set(payload, SetOptions(merge: true));
    await _clearFirstSelectionFlag();
  }

  /// 新候補の提案を見送ったときにフラグだけ下ろす
  Future<void> dismissProposal() async {
    final ref = _dreamRef;
    if (ref == null) return;
    await ref.set({
      'pendingDreamProposal': false,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _clearFirstSelectionFlag() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('personalityMeta')
          .doc('current')
          .set({'pendingFirstDreamSelection': false}, SetOptions(merge: true));
    } catch (_) {
      // フラグの解除に失敗してもダイアログは閉じる
    }
  }
}

final dreamServiceProvider = Provider<DreamService>((ref) {
  return DreamService(
    ref.watch(firestoreProvider),
    ref.watch(currentUserIdProvider),
    ref.watch(currentCharacterIdProvider),
  );
});
