import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/firebase_image_service.dart' as firebase_image;
import '../providers/character_provider.dart';

/// キャラクター画像の上半分を丸く切り抜いて表示するアバターウィジェット
class CharacterAvatarWidget extends ConsumerWidget {
  final String userId;
  final double size;
  final String fallbackText;
  final Color fallbackBackgroundColor;
  final Color fallbackTextColor;

  const CharacterAvatarWidget({
    super.key,
    required this.userId,
    required this.size,
    this.fallbackText = '?',
    this.fallbackBackgroundColor = const Color(0xFFE0E0E0),
    this.fallbackTextColor = const Color(0xFF757575),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(userCharacterDetailsProvider(userId));

    return detailsAsync.when(
      loading: () => _FallbackAvatar(
        size: size,
        text: fallbackText,
        backgroundColor: fallbackBackgroundColor,
        textColor: fallbackTextColor,
      ),
      error: (e, st) => _FallbackAvatar(
        size: size,
        text: fallbackText,
        backgroundColor: fallbackBackgroundColor,
        textColor: fallbackTextColor,
      ),
      data: (details) {
        if (details == null) {
          return _FallbackAvatar(
            size: size,
            text: fallbackText,
            backgroundColor: fallbackBackgroundColor,
            textColor: fallbackTextColor,
          );
        }
        final fileName = details.personalityImageFileName;
        if (fileName == null) {
          return _FallbackAvatar(
            size: size,
            text: fallbackText,
            backgroundColor: fallbackBackgroundColor,
            textColor: fallbackTextColor,
          );
        }
        final gender = details.gender == '男性'
            ? firebase_image.CharacterGender.male
            : firebase_image.CharacterGender.female;

        return _CharacterImageAvatar(
          fileName: fileName,
          gender: gender,
          size: size,
          fallbackText: fallbackText,
          fallbackBackgroundColor: fallbackBackgroundColor,
          fallbackTextColor: fallbackTextColor,
        );
      },
    );
  }
}

/// Firebaseから画像を取得して上半分を丸く表示
class _CharacterImageAvatar extends StatefulWidget {
  final String fileName;
  final firebase_image.CharacterGender gender;
  final double size;
  final String fallbackText;
  final Color fallbackBackgroundColor;
  final Color fallbackTextColor;

  const _CharacterImageAvatar({
    required this.fileName,
    required this.gender,
    required this.size,
    required this.fallbackText,
    required this.fallbackBackgroundColor,
    required this.fallbackTextColor,
  });

  @override
  State<_CharacterImageAvatar> createState() => _CharacterImageAvatarState();
}

class _CharacterImageAvatarState extends State<_CharacterImageAvatar> {
  Uint8List? _imageData;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final data = await firebase_image.FirebaseImageService.shared.fetchImage(
        fileName: widget.fileName,
        gender: widget.gender,
      );
      if (mounted) {
        setState(() {
          _imageData = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: widget.fallbackBackgroundColor,
        ),
      );
    }

    if (_failed || _imageData == null) {
      return _FallbackAvatar(
        size: widget.size,
        text: widget.fallbackText,
        backgroundColor: widget.fallbackBackgroundColor,
        textColor: widget.fallbackTextColor,
      );
    }

    // 上半分を丸く切り抜く: ClipOval + OverflowBox で縦2倍にしてトップ基準で表示
    return ClipOval(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: OverflowBox(
          maxHeight: widget.size * 2,
          alignment: Alignment.topCenter,
          child: Image.memory(
            _imageData!,
            width: widget.size,
            height: widget.size * 2,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
          ),
        ),
      ),
    );
  }
}

/// フォールバック用シンプルなCircleAvatar
class _FallbackAvatar extends StatelessWidget {
  final double size;
  final String text;
  final Color backgroundColor;
  final Color textColor;

  const _FallbackAvatar({
    required this.size,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor,
      child: text == '__icon_person__'
          ? Icon(Icons.person, color: textColor, size: size * 0.55)
          : Text(
              text,
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
    );
  }
}
