import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../data/datasources/remote/big5_datasource.dart';
import '../../data/models/big5_model.dart';
import 'auth_provider.dart';

/// Big5Datasourceのプロバイダー
final big5DatasourceProvider = Provider<Big5Datasource>((ref) {
  return Big5Datasource(
    firestore: ref.watch(firestoreProvider),
    functions: FirebaseFunctions.instanceFor(region: 'asia-northeast1'),
  );
});

/// BIG5進捗のストリームプロバイダー
final big5ProgressProvider = StreamProvider.family<Big5Progress, String>((ref, characterId) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(Big5Progress.initial());

  final datasource = ref.watch(big5DatasourceProvider);
  return datasource.watchBig5Progress(
    userId: userId,
    characterId: characterId,
  );
});

/// BIG5診断状態
class Big5DiagnosisState {
  final bool isLoading;
  final Big5Question? currentQuestion;
  final String? lastReply;
  final String? error;

  Big5DiagnosisState({
    this.isLoading = false,
    this.currentQuestion,
    this.lastReply,
    this.error,
  });

  Big5DiagnosisState copyWith({
    bool? isLoading,
    Big5Question? currentQuestion,
    String? lastReply,
    String? error,
    bool clearQuestion = false,
  }) {
    return Big5DiagnosisState(
      isLoading: isLoading ?? this.isLoading,
      currentQuestion: clearQuestion ? null : (currentQuestion ?? this.currentQuestion),
      lastReply: lastReply ?? this.lastReply,
      error: error,
    );
  }
}

/// BIG5診断コントローラー
class Big5DiagnosisController extends StateNotifier<Big5DiagnosisState> {
  final Big5Datasource _datasource;
  final Ref _ref;

  Big5DiagnosisController(this._datasource, this._ref) : super(Big5DiagnosisState());

  /// 診断を開始
  Future<void> startDiagnosis(String characterId) async {
    final userId = _ref.read(currentUserIdProvider);
    final user = _ref.read(userDocProvider).valueOrNull;
    if (userId == null || user == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _datasource.startDiagnosis(
        userId: userId,
        characterId: characterId,
        isPremium: user.isPremium,
      );

      state = state.copyWith(
        isLoading: false,
        currentQuestion: result.question,
        lastReply: result.reply,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 回答を送信
  Future<void> submitAnswer({
    required String characterId,
    required int answerValue,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    final user = _ref.read(userDocProvider).valueOrNull;
    if (userId == null || user == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _datasource.submitAnswer(
        userId: userId,
        characterId: characterId,
        answerValue: answerValue,
        isPremium: user.isPremium,
      );

      state = state.copyWith(
        isLoading: false,
        currentQuestion: result.nextQuestion,
        lastReply: result.reply,
        clearQuestion: result.nextQuestion == null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 質問をスキップしてチャットに戻る
  void skipToChat() {
    state = state.copyWith(clearQuestion: true);
  }

  /// 状態をリセット
  void reset() {
    state = Big5DiagnosisState();
  }
}

/// BIG5診断コントローラーのプロバイダー
final big5DiagnosisControllerProvider =
    StateNotifierProvider<Big5DiagnosisController, Big5DiagnosisState>((ref) {
  return Big5DiagnosisController(
    ref.watch(big5DatasourceProvider),
    ref,
  );
});

/// BIG5解析データのプロバイダー
final big5AnalysisDataProvider = FutureProvider.family<Big5AnalysisData?, String>((ref, characterId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final datasource = ref.watch(big5DatasourceProvider);

  // まずpersonalityKeyを取得
  final personalityKey = await datasource.fetchPersonalityKey(
    userId: userId,
    characterId: characterId,
  );

  if (personalityKey == null) return null;

  // 解析データを取得
  return datasource.fetchAnalysisData(personalityKey: personalityKey);
});
