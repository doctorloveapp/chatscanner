// File: lib/services/remote_config_service.dart
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Service for Firebase Remote Config
/// Manages dynamic configuration values like daily analysis limit
class RemoteConfigService {
  static final FirebaseRemoteConfig _remoteConfig =
      FirebaseRemoteConfig.instance;

  // Default value - used if Remote Config fetch fails
  static const int _defaultDailyLimit = 5;

  /// Initialize Remote Config with defaults and fetch latest values
  static Future<void> initialize() async {
    try {
      // 1. Configuration settings
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          // Update interval - in production use hours, in debug use seconds
          minimumFetchInterval: kDebugMode
              ? const Duration(seconds: 10)
              : const Duration(hours: 1),
        ),
      );

      // 2. Default values (used if fetch fails or on first launch)
      await _remoteConfig.setDefaults(<String, dynamic>{
        'daily_analysis_limit': _defaultDailyLimit,
      });

      // 3. Fetch and activate latest values
      await _remoteConfig.fetchAndActivate();
      debugPrint(
          '✅ Remote Config initialized. Daily limit: $dailyAnalysisLimit');
    } catch (e) {
      debugPrint('⚠️ Remote Config fetch failed, using defaults. Error: $e');
    }
  }

  /// Get the daily analysis limit from Remote Config
  /// Returns the remote value or default (5) if not available
  static int get dailyAnalysisLimit {
    return _remoteConfig.getInt('daily_analysis_limit');
  }
}
