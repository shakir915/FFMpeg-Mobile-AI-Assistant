import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

Future<void> waitForBuildIfPending() async {
  if (SchedulerBinding.instance.hasScheduledFrame) {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    return completer.future;
  }
  // Already built, no need to wait
  return;
}


String getExtension(String? fileName) {
  if (fileName == null || fileName.trim().isEmpty) return '';

  final trimmedName = fileName.trim();
  final lastDotIndex = trimmedName.lastIndexOf('.');

  // No dot found or dot is at the beginning/end
  if (lastDotIndex <= 0 || lastDotIndex >= trimmedName.length - 1) {
    return '';
  }

  return trimmedName.substring(lastDotIndex + 1).toLowerCase();
}

String getFileNameWithoutExtension(String? fileName) {
  if (fileName == null || fileName.trim().isEmpty) return '';

  final trimmedName = fileName.trim();
  final lastDotIndex = trimmedName.lastIndexOf('.');

  if (lastDotIndex <= 0) return trimmedName;

  return trimmedName.substring(0, lastDotIndex);
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

