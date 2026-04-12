import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/friend_model.dart';
import '../../providers/friend_provider.dart';
import '../../providers/theme_provider.dart';

class FriendShareLevelSheet extends ConsumerWidget {
  final FriendModel friend;
  final Color accentColor;

  const FriendShareLevelSheet({
    super.key,
    required this.friend,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = ref.watch(backgroundGradientProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${friend.name}への共有設定',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '予定の共有範囲を設定します',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          ...FriendShareLevel.values.map((level) {
            final isSelected = friend.shareLevel == level;
            return _ShareLevelOption(
              level: level,
              isSelected: isSelected,
              accentColor: accentColor,
              onTap: () async {
                await ref.read(friendControllerProvider.notifier)
                    .updateShareLevel(friend.id, level);
                if (context.mounted) Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }
}

class _ShareLevelOption extends StatelessWidget {
  final FriendShareLevel level;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _ShareLevelOption({
    required this.level,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, description) = _levelInfo(level);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accentColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? accentColor : Colors.grey, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? accentColor : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: accentColor, size: 20),
          ],
        ),
      ),
    );
  }

  (IconData, String) _levelInfo(FriendShareLevel level) {
    switch (level) {
      case FriendShareLevel.none:
        return (Icons.visibility_off_outlined, '予定を一切共有しません');
      case FriendShareLevel.public:
        return (Icons.visibility_outlined, '非公開フラグのない予定を共有します');
      case FriendShareLevel.full:
        return (Icons.public, '非公開設定の予定も含めてすべて共有します');
    }
  }
}
