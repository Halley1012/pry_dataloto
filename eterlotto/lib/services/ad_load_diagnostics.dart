import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Keep format-specific SDK errors available in release device logs.
/// main.dart disables debugPrint in release; do not enable other app logging.
void logAdLoadFailure(String format, LoadAdError error) {
  debugPrintSynchronously(
    '[ADS] format=$format event=load_failed code=${error.code} '
    'domain=${error.domain} message=${error.message} '
    'response_id=${error.responseInfo?.responseId ?? "none"}',
  );
}
