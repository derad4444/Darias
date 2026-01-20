import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/meeting_model.dart';
import '../../providers/meeting_provider.dart';

/// 6人会議画面
class MeetingScreen extends ConsumerStatefulWidget {
  final String? meetingId;

  const MeetingScreen({super.key, this.meetingId});

  @override
  ConsumerState<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends ConsumerState<MeetingScreen> {
  final _topicController = TextEditingController();
  String? _currentMeetingId;
  bool _isGenerating = false;
  int _currentSpeakerIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentMeetingId = widget.meetingId;
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('6人会議'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_currentMeetingId != null)
            IconButton(
              icon: const Icon(Icons.stop_circle),
              onPressed: _endMeeting,
              tooltip: '会議を終了',
            ),
        ],
      ),
      body: _currentMeetingId == null
          ? _buildTopicInput()
          : _buildMeetingRoom(),
    );
  }

  /// 議題入力画面
  Widget _buildTopicInput() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.groups,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              '6人会議',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '6人のAIキャラクターが議題について議論します',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // 参加者紹介
            _buildParticipantsPreview(),
            const SizedBox(height: 32),
            // 議題入力
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: '議題を入力',
                hintText: '例: 新製品のマーケティング戦略について',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.topic),
              ),
              maxLines: 3,
              minLines: 1,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _startMeeting,
                icon: const Icon(Icons.play_arrow),
                label: const Text('会議を開始'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 参加者プレビュー
  Widget _buildParticipantsPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '参加者',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MeetingModel.defaultParticipants.map((p) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: Color(int.parse(p.iconColor)),
                    child: Text(
                      p.name[0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  label: Text(p.role),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 会議室画面
  Widget _buildMeetingRoom() {
    final meetingAsync = ref.watch(meetingProvider(_currentMeetingId!));

    return meetingAsync.when(
      data: (meeting) {
        if (meeting == null) {
          return const Center(child: Text('会議が見つかりません'));
        }
        return Column(
          children: [
            // 議題表示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '議題',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meeting.topic,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            // 参加者一覧
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: meeting.participants.length,
                itemBuilder: (context, index) {
                  final participant = meeting.participants[index];
                  final isSpeaking = _isGenerating && _currentSpeakerIndex == index;
                  return _ParticipantAvatar(
                    participant: participant,
                    isSpeaking: isSpeaking,
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // メッセージ一覧
            Expanded(
              child: meeting.messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '会議を開始してください',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: meeting.messages.length,
                      itemBuilder: (context, index) {
                        final message = meeting.messages[index];
                        final participant = meeting.participants.firstWhere(
                          (p) => p.id == message.participantId,
                          orElse: () => MeetingModel.defaultParticipants.first,
                        );
                        return _MessageBubble(
                          message: message,
                          participant: participant,
                        );
                      },
                    ),
            ),
            // アクションボタン
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isGenerating ? null : () => _continueDiscussion(meeting),
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(_isGenerating ? '議論中...' : '議論を進める'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _isGenerating ? null : _endMeeting,
                    icon: const Icon(Icons.stop),
                    label: const Text('終了'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('エラー: $e')),
    );
  }

  /// 会議を開始
  Future<void> _startMeeting() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('議題を入力してください')),
      );
      return;
    }

    final meetingId = await ref
        .read(meetingControllerProvider.notifier)
        .createMeeting(topic);

    if (meetingId != null && mounted) {
      setState(() {
        _currentMeetingId = meetingId;
      });
    }
  }

  /// 議論を進める（6人全員が順番に発言）
  Future<void> _continueDiscussion(MeetingModel meeting) async {
    setState(() {
      _isGenerating = true;
    });

    final controller = ref.read(meetingControllerProvider.notifier);

    // 6人全員が順番に発言
    for (int i = 0; i < meeting.participants.length; i++) {
      if (!mounted) break;

      setState(() {
        _currentSpeakerIndex = i;
      });

      final participant = meeting.participants[i];

      // 最新のメッセージを取得
      final currentMeeting = await ref.read(meetingProvider(_currentMeetingId!).future);

      await controller.generateParticipantResponse(
        meetingId: _currentMeetingId!,
        topic: meeting.topic,
        participant: participant,
        previousMessages: currentMeeting?.messages ?? [],
      );

      // 少し待機（より自然な会議感を出すため）
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (mounted) {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  /// 会議を終了
  Future<void> _endMeeting() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('会議を終了'),
        content: const Text('この会議を終了しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('終了'),
          ),
        ],
      ),
    );

    if (confirmed == true && _currentMeetingId != null) {
      await ref
          .read(meetingControllerProvider.notifier)
          .endMeeting(_currentMeetingId!);

      if (mounted) {
        setState(() {
          _currentMeetingId = null;
        });
        _topicController.clear();
      }
    }
  }
}

/// 参加者アバター
class _ParticipantAvatar extends StatelessWidget {
  final MeetingParticipant participant;
  final bool isSpeaking;

  const _ParticipantAvatar({
    required this.participant,
    required this.isSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Color(int.parse(participant.iconColor)),
                child: Text(
                  participant.name.substring(participant.name.length - 2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isSpeaking)
                Positioned.fill(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            participant.name.split('・').last,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// メッセージバブル
class _MessageBubble extends StatelessWidget {
  final MeetingMessage message;
  final MeetingParticipant participant;

  const _MessageBubble({
    required this.message,
    required this.participant,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Color(int.parse(participant.iconColor)),
            child: Text(
              participant.name.substring(participant.name.length - 2),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      participant.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      participant.role,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message.content,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
