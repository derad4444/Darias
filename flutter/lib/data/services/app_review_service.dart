// lib/data/services/app_review_service.dart

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// アプリ評価を「出してよいか」を判断し、OS標準の評価画面を呼ぶ。
///
/// **なぜ自前のポップアップを1枚挟むのか**
/// iOSの評価ダイアログは**1年に3回まで**しか表示できず、4回目以降はOSが黙って
/// 握り潰す。しかも**表示されたか・評価されたかをアプリ側から知る方法がない**。
/// いきなりOSのダイアログを出すと、評価する気のない人にも貴重な枠を使ってしまう。
/// 先に自前のポップアップで意思を確認し、「評価する」を押した人にだけ枠を使う。
///
/// 判定に使う状態は端末ローカル（SharedPreferences）に持つ。
/// アカウントに紐づける必要はなく、端末ごとに1回聞ければ十分なため。
class AppReviewService {
  static const _kDone = 'app_review_done';           // 評価済み（以後出さない）
  static const _kDismissCount = 'app_review_dismiss'; // 「また今度」の回数
  static const _kNextAt = 'app_review_next_at';       // 次に出してよい日時(ms)
  static const _kFirstLaunch = 'app_review_first_at'; // 初回起動日時(ms)
  static const _kMeetingCount = 'app_review_meeting_n'; // 会議の完了回数

  /// 「また今度」を押されたあと、次に聞くまでの日数。
  /// 断られるほど間隔を空け、3回断られたら二度と聞かない。
  static const List<int> _backoffDays = [30, 90];

  /// インストール直後のユーザーには聞かない（体験が浅く判断材料がない）。
  static const int _minDaysSinceInstall = 3;

  /// 会議はほかの2つより頻度が高いので、通算この回数以降に絞る。
  static const int _minMeetingCount = 3;

  final InAppReview _inAppReview;
  AppReviewService({InAppReview? inAppReview})
      : _inAppReview = inAppReview ?? InAppReview.instance;

  /// 初回起動日を記録する（未記録なら今日）。アプリ起動時に呼ぶ。
  Future<void> markFirstLaunch() async {
    final p = await SharedPreferences.getInstance();
    if (p.getInt(_kFirstLaunch) == null) {
      await p.setInt(_kFirstLaunch, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// 会議が1回終わったことを記録する（表示条件の判定に使う）。
  Future<void> recordMeetingFinished() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kMeetingCount, (p.getInt(_kMeetingCount) ?? 0) + 1);
  }

  /// いま評価を聞いてよいか。
  ///
  /// [isMeeting] が true のときは会議の完了回数も条件に加える。
  Future<bool> shouldAsk({bool isMeeting = false}) async {
    if (kIsWeb) return false; // Webにストア評価は無い
    final p = await SharedPreferences.getInstance();

    if (p.getBool(_kDone) == true) return false;
    if ((p.getInt(_kDismissCount) ?? 0) > _backoffDays.length) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final nextAt = p.getInt(_kNextAt);
    if (nextAt != null && now < nextAt) return false;

    final first = p.getInt(_kFirstLaunch);
    if (first == null) return false; // 記録前＝初回起動中
    final days = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(first))
        .inDays;
    if (days < _minDaysSinceInstall) return false;

    if (isMeeting && (p.getInt(_kMeetingCount) ?? 0) < _minMeetingCount) {
      return false;
    }
    return true;
  }

  /// 「評価する」が押されたとき。OS標準の評価画面をアプリ内に出す。
  ///
  /// **ストアには飛ばさない。** 上限に達しているとOSが何も出さないが、
  /// 表示されたか判別できないため、押した時点で完了として扱う
  /// （ここでストアへ誘導すると、評価済みの人を無駄に外へ出すことになる）。
  Future<void> openReview() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDone, true);
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      }
    } catch (e) {
      debugPrint('AppReviewService: requestReview failed ($e)');
    }
  }

  /// 「また今度」が押されたとき。回数に応じて次回まで間隔を空ける。
  Future<void> postpone() async {
    final p = await SharedPreferences.getInstance();
    final count = (p.getInt(_kDismissCount) ?? 0) + 1;
    await p.setInt(_kDismissCount, count);
    if (count <= _backoffDays.length) {
      final days = _backoffDays[count - 1];
      await p.setInt(
        _kNextAt,
        DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch,
      );
    }
    // count が _backoffDays を超えたら shouldAsk() が false を返し続ける
  }
}
