import 'package:flutter/painting.dart' show Offset;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// グローバルFAB位置（null = デフォルト右下）
final fabPositionProvider = StateProvider<Offset?>((ref) => null);

/// カレンダー画面のキャラクターオーバーレイ位置（null = デフォルト左下）
final characterOverlayPositionProvider = StateProvider<Offset?>((ref) => null);

/// キャラクターオーバーレイのスケール（1.0 = 等倍）
final characterScaleProvider = StateProvider<double>((ref) => 1.0);
