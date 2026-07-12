import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/remote/survey_datasource.dart';

/// 手帳タブ廃止アンケートの選択肢。
///
/// `name`（keepAll など）をそのまま Firestore の `choice` に保存するため、
/// あとで選択肢別の集計がしやすい。
enum SurveyChoice {
  keepAll,
  keepSchedule,
  keepTodo,
  keepMemo,
  removeAll,
  unsure;

  String get label => switch (this) {
        SurveyChoice.keepAll => '手帳タブは全部残してほしい',
        SurveyChoice.keepSchedule => '予定（カレンダー）だけ残せばいい',
        SurveyChoice.keepTodo => 'タスクだけ残せばいい',
        SurveyChoice.keepMemo => 'メモだけ残せばいい',
        SurveyChoice.removeAll => '全部消してゲーム機能に期待する',
        SurveyChoice.unsure => 'わからない / どちらでもいい',
      };
}

final surveyDatasourceProvider = Provider<SurveyDatasource>((ref) {
  return SurveyDatasource();
});

/// 「回答済みか」を端末ローカルに永続化するフラグ。
/// 匿名回答のためサーバー側では判定できないので SharedPreferences で管理する。
/// null = 読み込み中 / false = 未回答 / true = 回答済み（以降は表示しない）。
class TechouSurveyAnsweredNotifier extends StateNotifier<bool?> {
  TechouSurveyAnsweredNotifier() : super(null) {
    _load();
  }

  static const String _prefKey = 'techou_survey_answered_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_prefKey) ?? false;
  }

  Future<void> markAnswered() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
    state = true;
  }
}

final techouSurveyAnsweredProvider =
    StateNotifierProvider<TechouSurveyAnsweredNotifier, bool?>((ref) {
  return TechouSurveyAnsweredNotifier();
});
