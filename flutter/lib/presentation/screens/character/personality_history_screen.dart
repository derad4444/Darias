import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/character/element_effect_widget.dart';

/// 性格履歴レコード
class PersonalityHistoryRecord {
  final String id;
  final String? element;
  final String? typeName;
  final String? gender;

  /// 記録した時点の成長段階（0=赤ちゃん 1=幼少期 2=大人）
  final int growthStage;
  final DateTime recordedAt;

  const PersonalityHistoryRecord({
    required this.id,
    this.element,
    this.typeName,
    this.gender,
    required this.growthStage,
    required this.recordedAt,
  });

  bool get isBabyStage => growthStage < 1;

  /// 回数制の頃の記録は growthStage を持たず signalCount だけなので、そこから求める
  static int _stageOf(Map<String, dynamic> data) {
    final stage = (data['growthStage'] as num?)?.toInt();
    if (stage != null) return stage;
    final signalCount = (data['signalCount'] as num?)?.toInt() ?? 0;
    if (signalCount >= 100) return 2;
    if (signalCount >= 30) return 1;
    return 0;
  }

  factory PersonalityHistoryRecord.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['recordedAt'] as Timestamp?;
    return PersonalityHistoryRecord(
      id: doc.id,
      element: data['element'] as String?,
      typeName: data['typeName'] as String?,
      gender: data['gender'] as String?,
      growthStage: _stageOf(data),
      recordedAt: ts?.toDate() ?? DateTime.now(),
    );
  }
}

/// 性格履歴一覧プロバイダー
final personalityHistoryProvider =
    StreamProvider.family<List<PersonalityHistoryRecord>, String>(
        (ref, characterId) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('characters')
      .doc(characterId)
      .collection('personalityHistory')
      .orderBy('recordedAt', descending: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map(PersonalityHistoryRecord.fromDoc).toList());
});

class PersonalityHistoryScreen extends ConsumerStatefulWidget {
  final String characterId;

  const PersonalityHistoryScreen({
    super.key,
    required this.characterId,
  });

  @override
  ConsumerState<PersonalityHistoryScreen> createState() =>
      _PersonalityHistoryScreenState();
}

class _PersonalityHistoryScreenState
    extends ConsumerState<PersonalityHistoryScreen> {
  bool _migrationAttempted = false;

  /// 既存ユーザー向け移行処理
  /// - 赤ちゃん期: element なしの赤ちゃんレコードを書く
  /// - 幼少期以降: 現在の element/typeName を書く
  Future<void> _migrateIfNeeded(String userId) async {
    if (_migrationAttempted) return;
    _migrationAttempted = true;

    final db = FirebaseFirestore.instance;

    // 既存レコードがあれば追記不要
    final existingSnap = await db
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(widget.characterId)
        .collection('personalityHistory')
        .limit(1)
        .get();

    if (existingSnap.docs.isNotEmpty) return;

    // 成長段階を取得
    final userSnap = await db.collection('users').doc(userId).get();
    final growthStage = (userSnap.data()?['growthStage'] as num?)?.toInt() ?? 0;

    if (growthStage < 1) {
      // 赤ちゃん期：element/typeName なしで書き込む
      await db
          .collection('users')
          .doc(userId)
          .collection('characters')
          .doc(widget.characterId)
          .collection('personalityHistory')
          .add({
        'growthStage': growthStage,
        'recordedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    // 元素が決まっている：現在の性格データを読んで書き込む
    final detailsSnap = await db
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(widget.characterId)
        .collection('details')
        .doc('current')
        .get();

    if (!detailsSnap.exists) return;

    final data = detailsSnap.data()!;
    final element = data['element'] as String?;
    final typeName = data['typeName'] as String?;
    final gender = data['gender'] as String?;

    if (element == null || typeName == null) return;

    final axisUpdatedAt = data['axisUpdatedAt'] as Timestamp?;

    await db
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(widget.characterId)
        .collection('personalityHistory')
        .add({
      'element': element,
      'typeName': typeName,
      'gender': gender,
      'growthStage': growthStage,
      'recordedAt': axisUpdatedAt ?? FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final colorSettings = ref.watch(colorSettingsProvider);
    final textColor = colorSettings.textColor;
    final userId = ref.watch(currentUserIdProvider);
    final historyAsync =
        ref.watch(personalityHistoryProvider(widget.characterId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('性格変動履歴', style: TextStyle(color: textColor)),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: historyAsync.when(
          data: (records) {
            // データ取得後に必ず移行処理を実行（フラグで1回のみ）
            if (userId != null) {
              Future.microtask(() => _migrateIfNeeded(userId));
            }
            return records.isEmpty
                ? _buildLoading(textColor)
                : _buildList(records, textColor);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('エラー: $e', style: TextStyle(color: textColor)),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(Color textColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 48, color: textColor.withAlpha(80)),
          const SizedBox(height: 12),
          Text(
            '履歴を読み込み中...',
            style: TextStyle(color: textColor.withAlpha(160), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<PersonalityHistoryRecord> records, Color textColor) {
    return ListView.separated(
      padding: EdgeInsets.only(
        top: kToolbarHeight + 60,
        bottom: 32,
        left: 16,
        right: 16,
      ),
      itemCount: records.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _HistoryCard(record: records[index], textColor: textColor),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final PersonalityHistoryRecord record;
  final Color textColor;

  const _HistoryCard({required this.record, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final isBaby = record.isBabyStage;
    final elementType =
        isBaby ? null : elementTypeFromString(record.element);
    final elementColor = elementType?.color ?? Colors.grey.shade400;
    final dateStr = DateFormat('yyyy年M月d日').format(record.recordedAt);
    final displayTypeName = isBaby ? '赤ちゃん期' : (record.typeName ?? '');

    final assetPath = characterGrowthAssetPath(
      growthStage: record.growthStage,
      element: record.element,
      gender: record.gender,
    );

    return Container(
      decoration: BoxDecoration(
        color: textColor.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: elementColor.withAlpha(80), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // キャラクター画像
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              assetPath,
              width: 80,
              height: 80,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: elementColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person, color: elementColor, size: 40),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    color: textColor.withAlpha(140),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 20,
                      decoration: BoxDecoration(
                        color: elementColor,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: elementColor.withAlpha(120),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayTypeName,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _growthLabel(record.growthStage),
                  style: TextStyle(
                    color: textColor.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _growthLabel(int growthStage) {
    if (growthStage >= 2) return '大人期';
    if (growthStage >= 1) return '幼少期';
    return '赤ちゃん期';
  }
}
