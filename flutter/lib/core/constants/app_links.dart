/// 外部URL定数
class AppLinks {
  AppLinks._();

  /// 共有テキストに載せる配布URL
  ///
  /// アクセスした端末を判定して App Store / LP へ振り分ける
  /// リダイレクトページ（リポジトリ直下の `dl/`）を指す。
  /// ストアURLを直接載せるとiOS/Androidで出し分けが必要になるため、
  /// 共有テキストからは常にこの1本を使う。
  static const String share = 'https://dariasapp.web.app';
}
