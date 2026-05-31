import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/daily_mission_model.dart';
import '../providers/daily_mission_provider.dart';
import '../providers/theme_provider.dart';

void showDailyMissionSheet(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const _DailyMissionDialog(),
  );
}

class _DailyMissionDialog extends ConsumerStatefulWidget {
  const _DailyMissionDialog();

  @override
  ConsumerState<_DailyMissionDialog> createState() =>
      _DailyMissionDialogState();
}

class _DailyMissionDialogState extends ConsumerState<_DailyMissionDialog> {
  late final ConfettiController _confettiController;
  bool _celebrated = false;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 1800));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _celebrate() {
    _confettiController.play();
  }

  void _goToTodaySheet() {
    Navigator.pop(context);
    if (context.mounted) {
      ref.read(dailyMissionNavigationProvider.notifier).state =
          DailyMissionNavigation.goToTodaySheet;
    }
  }

  void _goToYesterdaySheet() {
    Navigator.pop(context);
    if (context.mounted) {
      ref.read(dailyMissionNavigationProvider.notifier).state =
          DailyMissionNavigation.goToYesterdaySheet;
    }
  }

  @override
  Widget build(BuildContext context) {
    final missionAsync = ref.watch(dailyMissionProvider);
    final accentColor = ref.watch(accentColorProvider);
    final sheetBg = Color.alphaBlend(
      accentColor.withValues(alpha: 0.08),
      Colors.white,
    );

    // 全達成済みの状態でダイアログを開いた時に紙吹雪を再生
    missionAsync.whenData((mission) {
      if (mission.allCompleted && !_celebrated) {
        _celebrated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _confettiController.play();
        });
      }
    });

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // ポップアップ本体（先に描画してconfettiを上に重ねる）
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: missionAsync.when(
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('読み込みに失敗しました'),
              ),
              data: (mission) => _buildContent(mission, accentColor),
            ),
          ),
        ),

        // 紙吹雪（Dialogの上に重ねる）
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirection: pi / 2,
          emissionFrequency: 0.06,
          numberOfParticles: 25,
          gravity: 0.25,
          colors: [
            accentColor,
            Colors.pinkAccent,
            Colors.amber,
            Colors.lightBlueAccent,
            Colors.purpleAccent,
          ],
        ),
      ],
    );
  }

  Widget _buildContent(DailyMission mission, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // タイトル
          Text(
            '今日のミッション',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 8),

          // 進捗テキスト（キャプチャの「現在の進捗: 12 / 30」スタイル）
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '現在の進捗: ${mission.completedCount} / ${DailyMission.total}',
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF333333),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // 進捗バー
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: DailyMission.total > 0
                  ? mission.completedCount / DailyMission.total
                  : 0,
              backgroundColor: accentColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 5,
            ),
          ),

          const SizedBox(height: 16),
          Divider(color: accentColor.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 14),

          // ミッション一覧
          _MissionRow(
            label: 'ログイン',
            isDone: mission.loginDone,
            accentColor: accentColor,
          ),
          const SizedBox(height: 10),
          _MissionRow(
            label: 'チャットを2回する',
            isDone: mission.chat2Done,
            subLabel: mission.chat2Done ? null : '現在の進捗: ${mission.chatCount} / 2',
            accentColor: accentColor,
          ),
          const SizedBox(height: 10),
          _MissionRow(
            label: 'チャットを6回する',
            isDone: mission.chat6Done,
            subLabel: mission.chat6Done ? null : '現在の進捗: ${mission.chatCount} / 6',
            accentColor: accentColor,
          ),
          const SizedBox(height: 10),
          _MissionRow(
            label: '今日のスケジュールを確認する',
            isDone: mission.diaryViewed,
            subLabel: mission.diaryViewed ? null : 'タップして開く →',
            accentColor: accentColor,
            onTap: mission.diaryViewed ? null : _goToTodaySheet,
          ),
          const SizedBox(height: 10),
          _MissionRow(
            label: '日記を確認する',
            isDone: mission.diaryRead,
            subLabel: mission.diaryRead ? null : 'タップして開く →',
            accentColor: accentColor,
            onTap: mission.diaryRead ? null : _goToYesterdaySheet,
          ),

          // 全達成メッセージ
          if (mission.allCompleted) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('⭐', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '全ミッション達成！カレンダーに⭐がつくよ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          Divider(color: accentColor.withValues(alpha: 0.15), height: 1),

          // 閉じるボタン（スクリーンショットスタイル）
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '閉じる',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ポップアップ内のミッション行
class _MissionRow extends StatelessWidget {
  final String label;
  final bool isDone;
  final String? subLabel;
  final Color accentColor;
  final VoidCallback? onTap;

  const _MissionRow({
    required this.label,
    required this.isDone,
    required this.accentColor,
    this.subLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: isDone ? accentColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            // チェックボックス
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isDone ? accentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDone ? accentColor : accentColor.withValues(alpha: 0.5),
                  width: 1.8,
                ),
              ),
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDone ? accentColor : const Color(0xFF333333),
                    ),
                  ),
                  if (subLabel != null)
                    Text(
                      subLabel!,
                      style: TextStyle(
                        fontSize: 11,
                        color: accentColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 画面遷移を通知するプロバイダー
enum DailyMissionNavigation { none, goToCalendar, goToTodaySheet, goToYesterdaySheet }

final dailyMissionNavigationProvider =
    StateProvider<DailyMissionNavigation>((ref) => DailyMissionNavigation.none);

// カレンダーのボトムシートを開く日付トリガー（null = 何もしない）
final dailyMissionBottomSheetTriggerProvider =
    StateProvider<DateTime?>((ref) => null);
