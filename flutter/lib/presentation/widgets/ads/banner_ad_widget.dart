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

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void dispose() {
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
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
          print('✅ BannerAd: Loaded');
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('❌ BannerAd: Failed to load - ${error.message}');
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
