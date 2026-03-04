import 'dart:convert';
import 'package:flutter/services.dart' show TextSelection;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart' show Delta;

bool isDeltaJson(String content) {
  try {
    final decoded = jsonDecode(content);
    return decoded is List;
  } catch (_) {
    return false;
  }
}

String extractPlainText(String content) {
  if (content.isEmpty) return content;
  if (isDeltaJson(content)) {
    final doc = Document.fromJson(jsonDecode(content) as List);
    return doc.toPlainText().trim();
  }
  return content;
}

QuillController buildQuillController(String content) {
  if (isDeltaJson(content)) {
    return QuillController(
      document: Document.fromJson(jsonDecode(content) as List),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }
  if (content.isEmpty) {
    return QuillController.basic();
  }
  final delta = Delta()..insert('$content\n');
  return QuillController(
    document: Document.fromDelta(delta),
    selection: const TextSelection.collapsed(offset: 0),
  );
}
