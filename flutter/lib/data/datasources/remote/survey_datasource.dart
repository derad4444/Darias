import 'package:cloud_firestore/cloud_firestore.dart';

/// 手帳タブ廃止アンケートの匿名回答を保存するデータソース。
///
/// 回答は誰のものか特定せず、トップレベルの独立コレクション
/// `techou_survey_responses` に1回答1ドキュメントで追加する。
/// 施策終了後はこのコレクションを丸ごと削除すれば後片付けが完了する。
class SurveyDatasource {
  final FirebaseFirestore _firestore;

  SurveyDatasource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String collectionName = 'techou_survey_responses';

  /// 匿名でアンケート回答を送信する。
  Future<void> submitTechouSurvey({
    required String choice,
    required String choiceLabel,
    required String comment,
    required String appVersion,
    required String platform,
  }) async {
    await _firestore.collection(collectionName).add({
      'choice': choice,
      'choiceLabel': choiceLabel,
      'comment': comment,
      'appVersion': appVersion,
      'platform': platform,
      'answeredAt': FieldValue.serverTimestamp(),
    });
  }
}
