import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/analytics_service.dart';
import '../../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // 画面いっぱいに広げず、ホーム画面の上に小ウィンドウ（ダイアログ）として重ねる。
  // 端末が小さい場合は LayoutBuilder 側で利用可能サイズまで縮む。
  static const _cardMaxWidth = 420.0;
  static const _cardMaxHeight = 620.0;
  static const _cardMargin = 24.0;

  /// 背景のホーム画面をうっすら透かすための暗幕の濃さ
  static const _scrimOpacity = 0.45;

  // 「AIがあなたを知っていく」という一本の物語として構成する。
  // 機能紹介の順ではなく、出会い→話す→変化が起きる→使える→はじめる、の体験順に並べる。
  // 読み飛ばされないよう1枚3〜4行に抑える。
  static const _pages = [
    _OnboardingPage(
      icon: Icons.egg_alt_outlined,
      title: 'はじめまして',
      body: 'このAIは、あなたを何も知りません。\n\n名前も、好きなものも、\nどんなときに嬉しくなるのかも。\n\nこれから、あなたが教えていきます。',
    ),
    _OnboardingPage(
      icon: Icons.chat_bubble_outline,
      title: '話すだけでいい',
      body: '性格テストはありません。\n質問に答える必要もありません。\n\nただ話しかけるだけで、\n言葉の選び方から、\nAIがあなたを読み取っていきます。',
    ),
    _OnboardingPage(
      icon: Icons.local_fire_department,
      imagePath: 'assets/images/character_growth/赤ちゃん.png',
      clipImageToCircle: true,
      // 本文が5枚の中で一番長く、既定の配置では下が切れるため詰めて上へ寄せる
      compactLayout: true,
      title: '30回話すと、\nあなたの元素が決まる',
      body:
          '言葉が30回分たまると、\nあなたの性格が9つの元素のどれかに宿ります。\n\n炎、水、風、雷、光、土、氷、闇、そして無。\n\nこのときAIも、\n赤ちゃんから幼少期へ育ちます。\nあなたを知るほど、あなたに似ていく。',
    ),
    _OnboardingPage(
      icon: Icons.groups,
      title: '迷ったら、自分に聞けばいい',
      body:
          '「今の自分」「真逆の自分」「本音の自分」\n「理想の自分」「子供の頃の自分」\n「未来の自分」。\n\n6人のあなたが、\nあなたの悩みで本気で言い争います。\n\n他人の助言より、少しだけ刺さります。',
    ),
    _OnboardingPage(
      icon: Icons.send_outlined,
      imagePath: 'assets/images/character_growth/赤ちゃん.png',
      clipImageToCircle: true,
      title: 'さあ、最初のひと言を',
      body: '「おはよう」でも「疲れた」でも\nかまいません。\n\nその一言が、最初の記憶になります。\n\n今日あったことは、\n毎晩AIが日記に書いて待っています。',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // オンボーディング到達数と、1枚目の閲覧を記録する。
    // 2枚目以降は onPageChanged で記録するため、1枚目だけはここで送る。
    AnalyticsService.instance.logTutorialBegin();
    AnalyticsService.instance.logOnboardingSlideView(slideIndex: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// オンボーディングを終了する。[skipped] はスキップボタン経由かどうか。
  Future<void> _complete({required bool skipped}) async {
    await AnalyticsService.instance.logTutorialComplete(skipped: skipped);
    final userId = ref.read(currentUserIdProvider) ?? '';
    if (userId.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'hasSeenOnboardingSlides': true,
      });
    }
    if (!mounted) return;
    // ホームの上に push されているので閉じるだけでよい。
    // 直接 /onboarding を開いた場合など、戻れないときはホームへ送る。
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        // 背後のホーム画面をうっすら見せたまま、カードへ視線を集める暗幕
        color: Colors.black.withValues(alpha: _scrimOpacity),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(_cardMargin),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Column 内の Expanded を成立させるため、カードの高さを確定させる
                  return SizedBox(
                    width: min(constraints.maxWidth, _cardMaxWidth),
                    height: min(constraints.maxHeight, _cardMaxHeight),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // スキップ
                          Align(
                            alignment: Alignment.topRight,
                            child: TextButton(
                              onPressed: () => _complete(skipped: true),
                              child: const Text('スキップ', style: TextStyle(color: Colors.grey)),
                            ),
                          ),

                          // ページコンテンツ
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: _pages.length,
                              onPageChanged: (i) {
                                setState(() => _currentPage = i);
                                // 5枚のどこで離脱しているかを見るため1枚ごとに記録する
                                AnalyticsService.instance.logOnboardingSlideView(slideIndex: i);
                              },
                              itemBuilder: (_, i) => _PageContent(page: _pages[i]),
                            ),
                          ),

                          // ドットインジケーター
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_pages.length, (i) {
                              final active = i == _currentPage;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: active ? 20 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: active
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),

                          const SizedBox(height: 24),

                          // ボタン
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () {
                                  if (isLast) {
                                    _complete(skipped: false);
                                  } else {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  isLast ? 'チャットを始める！' : '次へ',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;
  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    // 通常は上下中央。本文が長い compactLayout のページだけ上寄せにして下の切れを防ぐ。
    // どちらの場合も収まらないときはスクロールできる。
    final compact = page.compactLayout;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: compact ? 0 : 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                (constraints.maxHeight - (compact ? 0 : 48)).clamp(0.0, double.infinity),
          ),
          child: Column(
            mainAxisAlignment:
                compact ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              _PageVisual(page: page),
              SizedBox(height: compact ? 12 : 32),
              Text(
                page.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.4),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: compact ? 12 : 20),
              Text(
                page.body,
                style: const TextStyle(fontSize: 15, height: 1.7, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String body;

  /// 指定するとアイコンの代わりに画像を表示する
  final String? imagePath;

  /// 画像を円形に切り抜くか。
  /// 成長キャラの画像は背景がグレーで透過していないため、
  /// 円形に切り抜いてカード背景に馴染ませる（敵画像は透過済みなので不要）。
  final bool clipImageToCircle;

  /// 本文が長いページ向けの詰めたレイアウト。
  /// ビジュアルと余白を小さくし、上下中央ではなく上寄せで配置する。
  final bool compactLayout;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    this.imagePath,
    this.clipImageToCircle = false,
    this.compactLayout = false,
  });
}

/// ページ上部のビジュアル（画像があれば画像、なければアイコン）
class _PageVisual extends StatelessWidget {
  final _OnboardingPage page;
  const _PageVisual({required this.page});

  static const double _size = 130;
  static const double _imageHeight = 120;

  // compactLayout のページは本文に高さを譲るため一回り小さくする
  static const double _compactSize = 80;
  static const double _compactImageHeight = 76;
  static const double _iconSize = 80;
  static const double _compactIconSize = 56;

  @override
  Widget build(BuildContext context) {
    final compact = page.compactLayout;
    final iconSize = compact ? _compactIconSize : _iconSize;
    final path = page.imagePath;
    if (path == null) {
      return Icon(page.icon, size: iconSize, color: Theme.of(context).colorScheme.primary);
    }

    // 画像が欠けていてもオンボーディングが止まらないようアイコンに退避する
    Widget fallback(BuildContext context, Object error, StackTrace? stack) =>
        Icon(page.icon, size: iconSize, color: Theme.of(context).colorScheme.primary);

    if (page.clipImageToCircle) {
      // 円を埋めるため cover で切り抜く
      final size = compact ? _compactSize : _size;
      return ClipOval(
        child: Image.asset(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: fallback,
        ),
      );
    }

    // 横長の敵画像は左右が切れないよう高さだけ指定して全体を見せる
    return Image.asset(
      path,
      height: compact ? _compactImageHeight : _imageHeight,
      fit: BoxFit.contain,
      errorBuilder: fallback,
    );
  }
}
