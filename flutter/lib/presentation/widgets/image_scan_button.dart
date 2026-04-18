import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/datasources/remote/image_extraction_datasource.dart';
import '../../data/services/rewarded_ad_service.dart';
import '../providers/subscription_provider.dart';

/// AIで画像を読み取り、データを抽出するボタン
/// [targetType]: 'schedule' | 'memo' | 'todo'
/// [onExtracted]: 抽出データを受け取るコールバック
class ImageScanButton extends ConsumerStatefulWidget {
  final String targetType;
  final void Function(Map<String, dynamic> data) onExtracted;

  const ImageScanButton({
    required this.targetType,
    required this.onExtracted,
    super.key,
  });

  @override
  ConsumerState<ImageScanButton> createState() => _ImageScanButtonState();
}

class _ImageScanButtonState extends ConsumerState<ImageScanButton> {
  bool _isProcessing = false;

  Future<void> _onTap() async {
    if (_isProcessing) return;

    final isPremium = ref.read(effectiveIsPremiumProvider);

    // 無料ユーザーはリワード広告を表示
    if (!isPremium) {
      final adService = RewardedAdService();

      _setProcessing(true);
      await adService.load();
      _setProcessing(false);

      if (!mounted) return;
      final rewarded = await adService.showAndAwaitReward();

      if (!rewarded) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('広告を最後まで視聴するとご利用いただけます')),
          );
        }
        return;
      }
    }

    // 画像ソース選択
    if (!mounted) return;
    final source = await _showSourcePicker();
    if (source == null) return;

    // 画像取得（最大1024px・品質75%で自動圧縮）
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 75,
    );
    if (image == null) return;

    _setProcessing(true);
    if (mounted) _showLoadingDialog();

    try {
      final bytes = await image.readAsBytes();
      final base64Str = base64Encode(bytes);

      final datasource = ImageExtractionDatasource();
      final result = await datasource.extractFromImage(
        imageBase64: base64Str,
        targetType: widget.targetType,
      );

      if (mounted) {
        Navigator.of(context).pop(); // ローディング閉じる
        widget.onExtracted(result);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('画像の読み取りに失敗しました。もう一度お試しください')),
        );
      }
    } finally {
      _setProcessing(false);
    }
  }

  Future<ImageSource?> _showSourcePicker() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('カメラで撮影'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('ライブラリから選択'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('AIが画像を読み取り中...'),
            ],
          ),
        ),
      ),
    );
  }

  void _setProcessing(bool value) {
    if (mounted) setState(() => _isProcessing = value);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: _isProcessing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.camera_alt_outlined),
      tooltip: 'AIで画像から読み取り',
      onPressed: _isProcessing ? null : _onTap,
    );
  }
}
