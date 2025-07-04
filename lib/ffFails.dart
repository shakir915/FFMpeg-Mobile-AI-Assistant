
class FFmpegFailureDetector {
  List<String> errorLogs = [];
  bool hasError = false;
  String? failureReason;

  void analyzeLog(String logMessage) {
    String lowerLog = logMessage.toLowerCase();

    // Critical error patterns
    List<String> criticalErrors = [
      'error',
      'failed',
      'exception',
      'could not',
      'cannot',
      'unable to',
      'not found',
      'permission denied',
      'no such file',
      'invalid',
      'unsupported',
      'codec not found',
      'format not supported'
    ];

    // Hardware encoder specific errors
    List<String> hardwareErrors = [
      'mediacodec configure failed',
      'android.media.mediacodec',
      'error initializing output stream',
      'generic error in an external library',
      'maybe incorrect parameters',
      'h264_mediacodec',
      'encoder not found'
    ];

    // Check for critical errors
    for (String error in criticalErrors) {
      if (lowerLog.contains(error)) {
        hasError = true;
        errorLogs.add(logMessage);
        failureReason = "Critical error: $error";
        print("🚨 DETECTED ERROR: $error");
        break;
      }
    }

    // Check for hardware encoder errors
    for (String hwError in hardwareErrors) {
      if (lowerLog.contains(hwError)) {
        hasError = true;
        errorLogs.add(logMessage);
        failureReason = "Hardware encoder error: $hwError";
        print("🔧 HARDWARE ERROR: $hwError");
        break;
      }
    }

    // Progress indicators (these mean it's working)
    List<String> progressIndicators = [
      'frame=',
      'fps=',
      'time=',
      'bitrate=',
      'speed=',
      'stream mapping:',
      'output #0'
    ];

    bool hasProgress = progressIndicators.any((indicator) =>
        lowerLog.contains(indicator));

    if (hasProgress) {
      print("✅ PROGRESS: Command is working");
    }
  }

  bool isFailure() => hasError;
  String? getFailureReason() => failureReason;
  List<String> getErrorLogs() => errorLogs;
}
