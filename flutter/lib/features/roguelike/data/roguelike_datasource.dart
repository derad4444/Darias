// features/roguelike/data/roguelike_datasource.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/action_log.dart';

/// 冒険履歴の1件分のサマリ（一覧表示用）。
class RoguelikeRunSummary {
  final String title;
  final String result; // GameResult.name
  final String dungeonId; // 挑戦したダンジョン（ボスアイコン表示用）
  final String worry; // 挑戦した悩み（ダンジョン名）
  final String inferredElement;
  final String topTrait;
  final DateTime? createdAt;

  RoguelikeRunSummary({
    required this.title,
    required this.result,
    required this.dungeonId,
    required this.worry,
    required this.inferredElement,
    required this.topTrait,
    this.createdAt,
  });

  factory RoguelikeRunSummary.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    return RoguelikeRunSummary(
      title: (m['title'] as String?) ?? '',
      result: (m['result'] as String?) ?? '',
      dungeonId: (m['dungeonId'] as String?) ?? '',
      worry: (m['worry'] as String?) ?? '',
      inferredElement: (m['inferredElement'] as String?) ?? '無',
      topTrait: (m['topTrait'] as String?) ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// 冒険1回分の詳細（解析結果の再表示用）。`traits` はレーダー用の全特性マップ。
class RoguelikeRunDetail {
  final String title;
  final String result; // GameResult.name
  final String inferredElement;
  final String dungeonId;
  final Map<String, int> traits;
  final DateTime? createdAt;

  RoguelikeRunDetail({
    required this.title,
    required this.result,
    required this.inferredElement,
    required this.dungeonId,
    required this.traits,
    this.createdAt,
  });

  factory RoguelikeRunDetail.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    final rawTraits = (m['traits'] as Map?) ?? const {};
    return RoguelikeRunDetail(
      title: (m['title'] as String?) ?? '',
      result: (m['result'] as String?) ?? '',
      inferredElement: (m['inferredElement'] as String?) ?? '無',
      dungeonId: (m['dungeonId'] as String?) ?? '',
      traits: rawTraits.map((k, v) => MapEntry(k as String, (v as num).toInt())),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// 冒険履歴を `users/{userId}/roguelike_runs/{runId}` に保存・取得する。
/// firestore.rules の users/{userId}/{subcollection=**} ルールで本人のみ read/write 可。
class RoguelikeDatasource {
  final FirebaseFirestore _firestore;

  RoguelikeDatasource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .collection('roguelike_runs');

  /// **そのユーザーの冒険記録をすべて削除する**（設定画面のリセット用）。
  ///
  /// 消すのは以下の5種類。冒険に関するものだけで、本編のデータには触れない。
  /// - `roguelike_runs`   … 冒険履歴（結果画面から保存されるもの）
  /// - `roguelike_clears` … 克服した悩みの記録
  /// - `roguelike_meta/codex`     … 図鑑（出会ったイベント・敵・称号）
  /// - `roguelike_meta/diagnosis` … 全踏破時の総合診断
  /// - `roguelike_meta/stamina`   … 1日の挑戦回数
  ///
  /// 履歴が多いと1バッチ（500件）に収まらないため分割してコミットする。
  Future<void> deleteAllRecords({required String userId}) async {
    Future<void> deleteCollection(CollectionReference<Map<String, dynamic>> col) async {
      while (true) {
        final snap = await col.limit(400).get();
        if (snap.docs.isEmpty) return;
        final batch = _firestore.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
        if (snap.docs.length < 400) return;
      }
    }

    await deleteCollection(_col(userId));
    await deleteCollection(_clearsCol(userId));

    final meta = _firestore.collection('users').doc(userId).collection('roguelike_meta');
    await Future.wait([
      meta.doc('codex').delete(),
      meta.doc('diagnosis').delete(),
      meta.doc('stamina').delete(),
    ]);
  }

  /// 冒険結果を保存する（createdAt はサーバ時刻）。
  Future<void> saveRun({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    await _col(userId).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 直近の冒険履歴をリアルタイム取得する。
  Stream<List<RoguelikeRunSummary>> watchRecentRuns({
    required String userId,
    int limit = 5,
  }) {
    return _col(userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => RoguelikeRunSummary.fromDoc(d)).toList());
  }

  /// 指定ダンジョンの最新の踏破（クリア）ランを取得する。無ければ null。
  /// `dungeonId` の単一等価フィルタ（自動インデックス）で取得し、result=='clear' を
  /// クライアント側で絞り込み・新しい順に並べて先頭を返す（複合インデックス不要）。
  Stream<RoguelikeRunDetail?> watchLatestClear({
    required String userId,
    required String dungeonId,
  }) {
    return _col(userId)
        .where('dungeonId', isEqualTo: dungeonId)
        .snapshots()
        .map((snap) {
      final clears = snap.docs
          .where((d) => (d.data()['result'] as String?) == 'clear')
          .map((d) => RoguelikeRunDetail.fromDoc(d))
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return clears.isEmpty ? null : clears.first;
    });
  }

  // --- 克服記録（心の図鑑） ---
  // `users/{userId}/roguelike_clears/{dungeonId}` に「克服した悩み」を1件ずつ記録する。
  // firestore.rules の users/{userId}/{subcollection=**} で本人のみ read/write 可（専用ルール追加なし）。

  CollectionReference<Map<String, dynamic>> _clearsCol(String userId) =>
      _firestore.collection('users').doc(userId).collection('roguelike_clears');

  /// ダンジョン（悩み）を克服したことを記録する。dungeonId をドキュメントIDにして冪等。
  Future<void> recordClear({
    required String userId,
    required String dungeonId,
    required String worry,
  }) async {
    await _clearsCol(userId).doc(dungeonId).set({
      'worry': worry,
      'clearedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 克服済みダンジョンIDの集合をリアルタイム取得する。
  Stream<Set<String>> watchClears({required String userId}) {
    return _clearsCol(userId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  // --- 図鑑（出会ったイベント・敵・獲得した称号の累積コレクション） ---
  // `users/{userId}/roguelike_meta/codex` の1ドキュメントに arrayUnion で蓄積する。

  DocumentReference<Map<String, dynamic>> _codexDoc(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .collection('roguelike_meta')
      .doc('codex');

  /// 今回の冒険で出会ったイベント/敵・獲得称号を図鑑に追記する（冪等・arrayUnion）。
  Future<void> recordCodex({
    required String userId,
    required Set<String> events,
    required Set<String> enemies,
    String? title,
  }) async {
    await _codexDoc(userId).set({
      if (events.isNotEmpty) 'events': FieldValue.arrayUnion(events.toList()),
      if (enemies.isNotEmpty) 'enemies': FieldValue.arrayUnion(enemies.toList()),
      if (title != null && title.isNotEmpty) 'titles': FieldValue.arrayUnion([title]),
    }, SetOptions(merge: true));
  }

  /// 図鑑（累積コレクション）をリアルタイム取得する。
  Stream<RoguelikeCodex> watchCodex({required String userId}) {
    return _codexDoc(userId).snapshots().map((doc) {
      final m = doc.data() ?? const {};
      Set<String> asSet(String key) =>
          ((m[key] as List?)?.cast<String>() ?? const <String>[]).toSet();
      return RoguelikeCodex(
        events: asSet('events'),
        enemies: asSet('enemies'),
        titles: asSet('titles'),
      );
    });
  }

  // --- 全踏破の総合診断（冒険の性格） ---
  // 全ラン横断で行動特性を合算し、AI（Cloud Function）で診断文を生成。
  // 生成結果は `users/{userId}/roguelike_meta/diagnosis` に保存する。

  DocumentReference<Map<String, dynamic>> _diagnosisDoc(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .collection('roguelike_meta')
      .doc('diagnosis');

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  /// 全ラン（roguelike_runs・最大500件）の `traits` を横断合算した ActionLog を返す。
  /// 全踏破診断の「総合の行動傾向」に使う。
  Future<ActionLog> aggregateRunTraits({required String userId}) async {
    final snap = await _col(userId)
        .orderBy('createdAt', descending: true)
        .limit(500)
        .get();
    final sum = <String, int>{};
    for (final doc in snap.docs) {
      final traits = (doc.data()['traits'] as Map?) ?? const {};
      traits.forEach((k, v) {
        if (v is num) sum[k as String] = (sum[k] ?? 0) + v.toInt();
      });
    }
    return ActionLog.fromMap(sum);
  }

  /// これまでの冒険ラン数（`roguelike_runs` の件数）。
  /// 総合診断の「更新」ボタンを、前回生成時から結果が変わった（ラン数が増えた）ときだけ
  /// 出すための基準値に使う。
  Future<int> runCount({required String userId}) async {
    final agg = await _col(userId).count().get();
    return agg.count ?? 0;
  }

  /// AI（`generateAdventureDiagnosis`）で診断文（summary/advice）を生成する。
  Future<({String summary, String advice})> generateDiagnosisText({
    required String userId,
    required String characterName,
    required String topTraits,
    required String inferredElement,
    required String homeElement,
  }) async {
    final callable = _functions.httpsCallable('generateAdventureDiagnosis');
    final result = await callable.call<Map<String, dynamic>>({
      'userId': userId,
      'characterName': characterName,
      'topTraits': topTraits,
      'inferredElement': inferredElement,
      'homeElement': homeElement,
    });
    final data = result.data;
    return (
      summary: (data['summary'] as String?) ?? '',
      advice: (data['advice'] as String?) ?? '',
    );
  }

  /// 生成した診断を保存する。
  Future<void> saveDiagnosis({
    required String userId,
    required String summary,
    required String advice,
    required String element,
    required String topTrait,
    required int runCount,
  }) async {
    await _diagnosisDoc(userId).set({
      'summary': summary,
      'advice': advice,
      'element': element,
      'topTrait': topTrait,
      'runCount': runCount, // 生成時点のラン数（更新ボタン表示判定用）
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 保存済みの診断をリアルタイム取得する（未生成なら null）。
  Stream<RoguelikeDiagnosis?> watchDiagnosis({required String userId}) {
    return _diagnosisDoc(userId).snapshots().map((doc) {
      final m = doc.data();
      final summary = (m?['summary'] as String?) ?? '';
      if (summary.isEmpty) return null;
      return RoguelikeDiagnosis(
        summary: summary,
        advice: (m?['advice'] as String?) ?? '',
        element: (m?['element'] as String?) ?? '無',
        topTrait: (m?['topTrait'] as String?) ?? '',
        runCount: (m?['runCount'] as num?)?.toInt(),
        updatedAt: (m?['updatedAt'] as Timestamp?)?.toDate(),
      );
    });
  }

  // --- スタミナ（ダンジョンは基本1回＋広告で+1回。プレミアム無制限） ---
  // `users/{userId}/roguelike_meta/stamina` に基本プレイ時刻を保存。
  // 基本プレイから24時間経過で回復（判定はクライアント側）。広告+1回はその1サイクル内で有効。

  DocumentReference<Map<String, dynamic>> _staminaDoc(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .collection('roguelike_meta')
      .doc('stamina');

  /// スタミナ状態をリアルタイム取得する。
  Stream<RoguelikeStamina> watchStamina({required String userId}) {
    return _staminaDoc(userId).snapshots().map((doc) {
      final m = doc.data();
      return RoguelikeStamina(
        basePlayAt: (m?['basePlayAt'] as Timestamp?)?.toDate(),
        adPlayUsed: (m?['adPlayUsed'] as bool?) ?? false,
      );
    });
  }

  /// スタミナの消費状況を保存する（基本プレイ時刻＋広告使用フラグ）。
  Future<void> setStamina({
    required String userId,
    required RoguelikeStamina stamina,
  }) async {
    await _staminaDoc(userId).set({
      'basePlayAt': stamina.basePlayAt != null ? Timestamp.fromDate(stamina.basePlayAt!) : null,
      'adPlayUsed': stamina.adPlayUsed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

/// ダンジョンのスタミナ状態（無料は基本1回＋広告で+1回）。
/// `basePlayAt`＝基本1回を使った時刻（null＝未使用/回復済み）。そこから24時間で回復。
class RoguelikeStamina {
  final DateTime? basePlayAt;
  final bool adPlayUsed; // 現在のサイクル（基本プレイ後24時間）で広告+1回を使ったか
  const RoguelikeStamina({this.basePlayAt, this.adPlayUsed = false});
}

/// 全踏破の総合診断（AI生成テキスト）。
class RoguelikeDiagnosis {
  final String summary; // 「あなたはこういう選択を多く取る」
  final String advice;  // 「この傾向をこう活かそう」
  final String element; // 生成時の推定元素
  final String topTrait; // 生成時の最上位特性
  final int? runCount; // 生成時点のラン数（null=旧データ）
  final DateTime? updatedAt;
  const RoguelikeDiagnosis({
    required this.summary,
    required this.advice,
    this.element = '無',
    this.topTrait = '',
    this.runCount,
    this.updatedAt,
  });
}

/// 図鑑の累積コレクション（出会ったイベント・敵・獲得称号）。
class RoguelikeCodex {
  final Set<String> events;
  final Set<String> enemies;
  final Set<String> titles;
  const RoguelikeCodex({
    this.events = const {},
    this.enemies = const {},
    this.titles = const {},
  });
}
