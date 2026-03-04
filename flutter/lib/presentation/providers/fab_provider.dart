import 'package:flutter/painting.dart' show Offset;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// グローバルFAB位置（null = デフォルト右下）
final fabPositionProvider = StateProvider<Offset?>((ref) => null);
