import 'package:flutter/material.dart';
import '../../data/services/hint_service.dart';

/// 初回のみ表示されるインラインヒントバナー
/// [feature]: HintService.k* の定数を指定
/// [message]: 表示するヒントテキスト
class InlineHintBanner extends StatefulWidget {
  final String userId;
  final String feature;
  final String message;
  final IconData icon;

  const InlineHintBanner({
    required this.userId,
    required this.feature,
    required this.message,
    this.icon = Icons.lightbulb_outline,
    super.key,
  });

  @override
  State<InlineHintBanner> createState() => _InlineHintBannerState();
}

class _InlineHintBannerState extends State<InlineHintBanner>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _checkAndShow();
  }

  Future<void> _checkAndShow() async {
    final service = HintService(widget.userId);
    final shown = await service.isShown(widget.feature);
    if (!shown && mounted) {
      setState(() => _visible = true);
      _ctrl.forward();
    }
  }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    if (mounted) setState(() => _visible = false);
    await HintService(widget.userId).markShown(widget.feature);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final color = Theme.of(context).colorScheme.primary;

    return SizeTransition(
      sizeFactor: _anim,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.message,
                style: TextStyle(fontSize: 13, color: color, height: 1.45),
              ),
            ),
            GestureDetector(
              onTap: _dismiss,
              child: Icon(Icons.close, size: 18, color: color.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

/// ホーム画面専用：タップで3ステップを順に表示するバナー
class HomeHintBanner extends StatefulWidget {
  final String userId;

  const HomeHintBanner({required this.userId, super.key});

  @override
  State<HomeHintBanner> createState() => _HomeHintBannerState();
}

class _HomeHintBannerState extends State<HomeHintBanner>
    with SingleTickerProviderStateMixin {
  static const _steps = [
    (
      icon: Icons.chat_bubble_outline,
      text: '"明日14時に会議"と送ると予定を自動登録。"メモして"でメモ、"タスクに追加"でタスクにも登録できます',
    ),
    (
      icon: Icons.help_outline,
      text: '"この機能の使い方は？"とチャットで聞くとアプリの操作方法を教えてくれます。設定 → 使い方ガイドからもいつでも確認できます',
    ),
    (
      icon: Icons.psychology_outlined,
      text: '"性格診断して"と送ると100問のBIG5診断が始まります。スコアがキャラクターの返答や日記に反映されます',
    ),
  ];

  int _step = 0;
  bool _visible = false;
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _checkAndShow();
  }

  Future<void> _checkAndShow() async {
    final service = HintService(widget.userId);
    final step = await service.getHomeStep();
    if (step < _steps.length && mounted) {
      setState(() {
        _step = step;
        _visible = true;
      });
      _ctrl.forward();
    }
  }

  Future<void> _next() async {
    final service = HintService(widget.userId);
    final nextStep = _step + 1;
    if (nextStep >= _steps.length) {
      await _ctrl.reverse();
      if (mounted) setState(() => _visible = false);
      await service.setHomeStep(nextStep);
    } else {
      await _ctrl.reverse();
      await service.setHomeStep(nextStep);
      if (mounted) {
        setState(() => _step = nextStep);
        _ctrl.forward();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _step >= _steps.length) return const SizedBox.shrink();

    final color = Theme.of(context).colorScheme.primary;
    final current = _steps[_step];
    final total = _steps.length;

    return SizeTransition(
      sizeFactor: _anim,
      child: GestureDetector(
        onTap: _next,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(current.icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  current.text,
                  style: TextStyle(fontSize: 13, color: color, height: 1.45),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_step + 1}/$total ›',
                style: TextStyle(
                  fontSize: 12,
                  color: color.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
