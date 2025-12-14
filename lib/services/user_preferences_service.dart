// lib/services/user_preferences_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user preferences
/// Uses flutter_secure_storage for sensitive data (API keys)
/// Uses shared_preferences for non-sensitive data (theme, language)
class UserPreferencesService {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Keys
  static const _keyApiKey = 'user_gemini_api_key';
  static const _keyApiKeyEnabled = 'user_gemini_api_key_enabled'; // New toggle
  static const _keyDarkMode = 'dark_mode';
  static const _keyLanguageOverride = 'language_override';
  static const _keyDontShowInstructions = 'dont_show_instructions';

  // ============================================================
  // API KEY (Secure Storage)
  // ============================================================

  /// Check if user has set a custom API key
  static Future<bool> hasCustomApiKey() async {
    final key = await _secureStorage.read(key: _keyApiKey);
    return key != null && key.isNotEmpty;
  }

  /// Get user's custom API key (returns null if not set)
  static Future<String?> getCustomApiKey() async {
    return await _secureStorage.read(key: _keyApiKey);
  }

  /// Save user's custom API key securely
  static Future<void> setCustomApiKey(String apiKey) async {
    await _secureStorage.write(key: _keyApiKey, value: apiKey);
    // Auto-enable when setting a new key
    await setCustomApiKeyEnabled(true);
    debugPrint('✅ User API key saved securely');
  }

  /// Remove user's custom API key (return to default cascade)
  static Future<void> removeCustomApiKey() async {
    await _secureStorage.delete(key: _keyApiKey);
    await setCustomApiKeyEnabled(false);
    debugPrint('✅ User API key removed');
  }

  /// Check if custom API key is enabled by user
  static Future<bool> isCustomApiKeyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyApiKeyEnabled) ??
        true; // Default to true if key exists
  }

  /// Set custom API key enabled status
  static Future<void> setCustomApiKeyEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyApiKeyEnabled, enabled);
  }

  // ============================================================
  // DARK MODE
  // ============================================================

  /// Get dark mode preference (null = system default)
  static Future<bool?> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_keyDarkMode)) return null;
    return prefs.getBool(_keyDarkMode);
  }

  /// Set dark mode preference (null = reset to system)
  static Future<void> setDarkMode(bool? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_keyDarkMode);
    } else {
      await prefs.setBool(_keyDarkMode, value);
    }
  }

  // ============================================================
  // LANGUAGE OVERRIDE
  // ============================================================

  /// Get language override (null = use device language)
  /// Returns 'it' or 'en' or null
  static Future<String?> getLanguageOverride() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguageOverride);
  }

  /// Set language override (null = reset to device language)
  static Future<void> setLanguageOverride(String? languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    if (languageCode == null) {
      await prefs.remove(_keyLanguageOverride);
    } else {
      await prefs.setString(_keyLanguageOverride, languageCode);
    }
  }

  // ============================================================
  // INSTRUCTIONS
  // ============================================================

  /// Check if user wants to skip instructions
  static Future<bool> getDontShowInstructions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDontShowInstructions) ?? false;
  }

  /// Set instruction preference
  static Future<void> setDontShowInstructions(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDontShowInstructions, value);
  }

  // ============================================================
  // DELETE ALL DATA (GDPR)
  // ============================================================

  /// Delete all user data (for GDPR compliance)
  static Future<void> deleteAllData() async {
    // Clear secure storage
    await _secureStorage.deleteAll();

    // Clear shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    debugPrint('✅ All user data deleted');
  }
}
