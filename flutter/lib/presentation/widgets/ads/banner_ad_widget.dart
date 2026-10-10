import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../data/services/ad_service.dart';

/// バナー広告ウィジェット
class BannerAdWidget extends StatefulWidget {
  /// カスタム広告ユニットID（オプション）
  final String? adUnitId;

  const BannerAdWidget({
    super.key,
    this.adUnitId,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  Timer? _retryTimer;

  /// 読み込みに失敗したとき、読み込み直すまでの時間
  static const _retryDelay = Duration(seconds: 60);

  /// この広告が画面に見えているか（TickerMode が有効か）
  bool _active = false;

  // 見えていないあいだは読み込まない。IndexedStack の裏のタブや、上に別の画面が重なっている画面では
  // TickerMode が無効になる。そこで読み込むと表示されないまま「リクエスト」だけが数えられ、表示率が下がる。
  // 見えなくなったら広告を破棄し、見えるようになったら読み込み直す
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.of(context);
    if (active == _active) return;
    _active = active;
    if (active) {
      if (_bannerAd == null) _loadAd();
    } else {
      _unloadAd();
    }
  }

  /// 広告を破棄して「読み込み前」に戻す
  void _unloadAd() {
    _retryTimer?.cancel();
    final ad = _bannerAd;
    _bannerAd = null;
    _isLoaded = false;
    // AdWidget が画面から外れるのは次の描画なので、破棄はそのあとにする
    if (ad != null) WidgetsBinding.instance.addPostFrameCallback((_) => ad.dispose());
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadAd() {
    // Webプラットフォームでは広告を表示しない
    if (kIsWeb) return;

    final adUnitId = widget.adUnitId ?? AdConfig.homeScreenBannerAdUnitId;

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner, // 320x50
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          // 読み込み中に見えなくなって破棄済みの広告は表示しない
          if (!identical(ad, _bannerAd)) {
            ad.dispose();
            return;
          }
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
          print('✅ BannerAd: Loaded');
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ BannerAd: Failed to load - ${error.message}');
          // 表示中の広告の自動更新が失敗したときもここに来る。破棄した広告を
          // AdWidget に表示し続けると画面が壊れる（白・グレーになる）ため、
          // 先に「読み込み中」の表示へ戻してから破棄し、少し待って読み込み直す
          if (mounted) {
            setState(() {
              _isLoaded = false;
              _bannerAd = null;
            });
            // AdWidget が画面から外れるのは次の描画なので、破棄はそのあとにする
            WidgetsBinding.instance.addPostFrameCallback((_) => ad.dispose());
          } else {
            _bannerAd = null;
            ad.dispose();
          }
          _retryTimer?.cancel();
          _retryTimer = Timer(_retryDelay, () {
            if (mounted && _active) _loadAd();
          });
        },
        onAdOpened: (ad) {
          print('📱 BannerAd: Opened');
        },
        onAdClosed: (ad) {
          print('📱 BannerAd: Closed');
        },
        onAdImpression: (ad) {
          print('👁️ BannerAd: Impression');
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  Widget build(BuildContext context) {
    // Webプラットフォームでは何も表示しない
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    if (!_isLoaded || _bannerAd == null) {
      // 広告読み込み中はプレースホルダーを表示
      return Container(
        width: 320,
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFEDE6F2),
              const Color(0xFFF9F6F0),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 320,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFEDE6F2),
            const Color(0xFFF9F6F0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

/// バナー広告コンテナ（中央揃え＋パディング付き）
class BannerAdContainer extends StatelessWidget {
  final String? adUnitId;
  final EdgeInsets padding;

  const BannerAdContainer({
    super.key,
    this.adUnitId,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: BannerAdWidget(adUnitId: adUnitId),
      ),
    );
  }
}
