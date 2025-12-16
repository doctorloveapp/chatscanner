import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;

import '../env/env.dart';
import 'remote_config_service.dart';
import 'user_preferences_service.dart';
import 'translation_service.dart';

/// Available models for debug selection
/// When debugModeEnabled = false, this enum is ignored
enum DebugModelChoice {
  cascade, // Use normal cascade with fallback (default/production)
  geminiPro, // Gemini 2.5 Pro only
  geminiFlash, // Gemini 2.5 Flash only
  groqScout, // Groq Llama 4 Scout only
  groqMaverick, // Groq Llama 4 Maverick only
  customKey, // Force use of custom API Key
}

extension DebugModelChoiceExtension on DebugModelChoice {
  String get displayName {
    switch (this) {
      case DebugModelChoice.cascade:
        return '🔄 Cascade (Auto)';
      case DebugModelChoice.geminiPro:
        return '🟢 Gemini 2.5 Pro';
      case DebugModelChoice.geminiFlash:
        return '⚡ Gemini 2.5 Flash';
      case DebugModelChoice.groqScout:
        return '🦙 Groq Llama Scout';
      case DebugModelChoice.groqMaverick:
        return '🚀 Groq Llama Maverick';
      case DebugModelChoice.customKey:
        return '🔑 Custom API Key';
    }
  }
}

/// Multi-tier AI cascade service for Doctor Love
/// Priority: Gemini 2.5 Pro → Gemini 2.5 Flash → Groq Llama 4 Scout → Groq Llama 4 Maverick
class AICascadeService {
  // Daily limit now comes from Firebase Remote Config
  static int get _maxAnalysesPerDay => RemoteConfigService.dailyAnalysisLimit;
  static const int _maxRetries = 3;

  // ============================================================
  // DEBUG MODE - Set to false for production release
  // ============================================================
  static const bool debugModeEnabled = false;

  /// Currently selected model for debug testing
  static DebugModelChoice selectedModel = DebugModelChoice.cascade;

  /// Debug logging helper with timestamp
  static void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] DEBUG: $message');
  }

  /// Log error with full details
  static void _logError(String context, dynamic error,
      [StackTrace? stackTrace]) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] ERROR in $context:');
    debugPrint('  Type: ${error.runtimeType}');
    debugPrint('  Message: $error');
    if (stackTrace != null) {
      debugPrint('  StackTrace: $stackTrace');
    }
  }

  // Doctor Love system prompt - ITALIAN VERSION
  static const String _doctorLovePromptIT = '''
Sei Doctor Love, il dating coach più cinico, geniale e brutale d'Italia.  
Analizza uno o più screenshot di chat (WhatsApp, Instagram, Telegram, ecc.).  
Considera tutto: testo, emoji, timestamp, lunghezza messaggi, chi inizia, chi risponde subito o dopo ore, doppi check, punteggiatura.

RESTITUISCI SOLO ed ESCLUSIVAMENTE un oggetto JSON valido (niente markdown, niente ```json, niente testo prima o dopo) con ESATTAMENTE questo schema:

{
  "score": 0-100,
  "analysis": "stringa breve (max 140 caratteri), ironica, pungente, brutale se serve, in italiano perfetto",
  "line_rating": [
    {
      "text": "testo esatto della frase (max 80 caratteri)",
      "sender": "me" oppure "them",
      "rating": 1-10
    }
  ],
  "next_move": "il messaggio esatto da inviare ora (1-3 frasi massimo, naturale, italiano perfetto, che massimizzi le chance). Se la chat è morta scrivi solo: 'Molla, non c'è più niente da fare 💀'"
}

Regole ferree:
- Sii sempre onesto, mai gentile per forza
- Usa italiano corrente (niente frasi da manuale del 1800)
- Se lo screenshot è illeggibile o vuoto → score 0 e analysis "Screenshot vuoto o illeggibile"
- Il JSON deve essere 100% parsabile anche su device lenti
- Se l'interesse è altissimo usa emoji 🔥, se è morto usa 💀
''';

  // Doctor Love system prompt - ENGLISH VERSION
  static const String _doctorLovePromptEN = '''
You are Doctor Love, the most cynical, brilliant, and brutally honest dating coach.  
Analyze one or more chat screenshots (WhatsApp, Instagram, Telegram, etc.).  
Consider everything: text, emojis, timestamps, message length, who initiates, who responds immediately or after hours, read receipts, punctuation.

RETURN ONLY and EXCLUSIVELY a valid JSON object (no markdown, no ```json, no text before or after) with EXACTLY this schema:

{
  "score": 0-100,
  "analysis": "short string (max 140 characters), witty, edgy, brutal if needed, in perfect English",
  "line_rating": [
    {
      "text": "exact text of the phrase (max 80 characters)",
      "sender": "me" or "them",
      "rating": 1-10
    }
  ],
  "next_move": "the exact message to send now (1-3 sentences max, natural, perfect English, that maximizes your chances). If the chat is dead just write: 'Move on, there's nothing left here 💀'"
}

Strict rules:
- Always be honest, never nice just to be nice
- Use modern casual English (no formal old-school phrases)
- If the screenshot is unreadable or empty → score 0 and analysis "Screenshot empty or unreadable"
- The JSON must be 100% parsable even on slow devices
- If interest is very high use emoji 🔥, if it's dead use 💀
''';

  /// Get the appropriate prompt based on current language setting
  static String get _doctorLovePrompt {
    // Import TranslationService to check current language
    final currentLang = TranslationService().currentLanguage;
    return currentLang == 'en' ? _doctorLovePromptEN : _doctorLovePromptIT;
  }

  /// Check if user has remaining analyses for today
  static Future<int> getRemainingAnalyses() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString('analysis_date') ?? '';

    if (storedDate != today) {
      // New day, reset counter
      await prefs.setString('analysis_date', today);
      await prefs.setInt('analysis_count', 0);
      return _maxAnalysesPerDay;
    }

    final count = prefs.getInt('analysis_count') ?? 0;
    return _maxAnalysesPerDay - count;
  }

  /// Increment analysis counter
  static Future<void> _incrementAnalysisCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('analysis_count') ?? 0;
    await prefs.setInt('analysis_count', count + 1);
  }

  /// BYOK: Call Gemini with user's own API key (no rate limit)
  /// BYOK: Cascade Gemini 2.5 Pro -> Gemini 2.5 Flash using user's key
  static Future<Map<String, dynamic>> _callWithUserApiKeyCascade(
      List<Uint8List> imageBytesList) async {
    _log('🔑 BYOK: Starting Custom Key Cascade');

    final userApiKey = await UserPreferencesService.getCustomApiKey();
    if (userApiKey == null || userApiKey.isEmpty) {
      throw Exception('User API key not found');
    }

    try {
      _log('🔑 BYOK: Trying TIER 1 (Gemini 2.5 Pro)');
      return await _callGemini(imageBytesList, 'gemini-2.5-pro',
          overrideApiKey: userApiKey);
    } catch (e) {
      _log(
          '⚠️ BYOK: TIER 1 Failed (${e.toString()}). Falling back to TIER 2 (Flash)');

      // Check if it's a critical error that shouldn't be retried?
      // For now, try Flash for everything except maybe invalid key, but even then, safer to try.
      try {
        return await _callGemini(imageBytesList, 'gemini-2.5-flash',
            overrideApiKey: userApiKey);
      } catch (e2) {
        _log('❌ BYOK: TIER 2 Failed also.');
        // Throw the original error or the new one?
        // Throwing e2 is more relevant as it's the final failure.

        // Use existing error parsing to throw specific messages
        final errStr = e2.toString().toLowerCase();
        if (errStr.contains('api_key_invalid') ||
            errStr.contains('invalid api key')) {
          throw Exception('La tua API Key non è valida. Controlla e riprova.');
        }
        if (errStr.contains('quota')) {
          throw Exception('Hai esaurito la quota della tua API Key.');
        }
        rethrow;
      }
    }
  }

  /// DEBUG: Call a specific model directly without fallback
  static Future<Map<String, dynamic>> _callSingleModel(
      List<Uint8List> imageBytesList, DebugModelChoice model) async {
    _log('🔧 DEBUG: Calling single model: ${model.displayName}');

    try {
      Map<String, dynamic> result;

      switch (model) {
        case DebugModelChoice.geminiPro:
          result = await _callGeminiWithRetry(imageBytesList, 'gemini-2.5-pro');
          break;
        case DebugModelChoice.geminiFlash:
          result =
              await _callGeminiWithRetry(imageBytesList, 'gemini-2.5-flash');
          break;
        case DebugModelChoice.groqScout:
          result = await _callGroqWithRetry(
            imageBytesList,
            'meta-llama/llama-4-scout-17b-16e-instruct',
          );
          break;
        case DebugModelChoice.groqMaverick:
          result = await _callGroqWithRetry(
            imageBytesList,
            'meta-llama/llama-4-maverick-17b-128e-instruct',
          );
          break;
        case DebugModelChoice.customKey:
          result = await _callWithUserApiKeyCascade(imageBytesList);
          break;
        case DebugModelChoice.cascade:
          throw Exception('Cascade should not be called via _callSingleModel');
      }

      _log('🔧 DEBUG: ${model.displayName} SUCCESS!');
      await _incrementAnalysisCount();
      return result;
    } catch (e, stackTrace) {
      _logError('DEBUG ${model.displayName}', e, stackTrace);
      throw Exception('${model.displayName} FAILED: $e');
    }
  }

  /// Main analysis method with 4-tier cascade
  /// In debug mode, can call a specific model instead
  /// If user has custom API key, bypasses rate limit and cascade
  static Future<Map<String, dynamic>> analyzeImages(
      List<Uint8List> imageBytesList) async {
    _log('=== STARTING AI CASCADE ANALYSIS ===');
    _log('Images to analyze: ${imageBytesList.length}');
    _log(
        'Total bytes: ${imageBytesList.fold<int>(0, (sum, bytes) => sum + bytes.length)}');

    // Check if user has their own API key (BYOK mode) AND it is enabled
    final hasCustomKey = await UserPreferencesService.hasCustomApiKey();
    final isCustomKeyEnabled =
        await UserPreferencesService.isCustomApiKeyEnabled();

    if (hasCustomKey && isCustomKeyEnabled) {
      _log('🔑 BYOK MODE: User has custom API key ENABLED - bypassing limits');
      try {
        return await _callWithUserApiKeyCascade(imageBytesList);
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('quota') ||
            errStr.contains('resource_exhausted') ||
            errStr.contains('429')) {
          // Only fall back if the user actually has standard analyses remaining!
          // Otherwise, show them the real error from their key so they know it was attempted.
          final existingQuota = await getRemainingAnalyses();
          if (existingQuota > 0) {
            _log('⚠️ Custom Key Exhausted! Falling back to standard cascade.');
          } else {
            // No standard quota left to fall back to.
            // Rethrow the original error so the user sees "Quota Exceeded" from their own key
            // instead of "Daily Limit Reached" from the app.
            _log('⚠️ Custom Key Exhausted and no standard quota. Rethrowing.');
            rethrow;
          }
        } else {
          rethrow; // Invalid key or other errors should still fail
        }
      }
    }

    // Check rate limit (only for default cascade)
    final remaining = await getRemainingAnalyses();
    _log('Rate limit check: $remaining analyses remaining');
    if (remaining <= 0) {
      _log('RATE LIMIT EXCEEDED - no analyses remaining');
      throw Exception('RATE_LIMIT_EXCEEDED');
    }

    // DEBUG MODE: If enabled and specific model selected, use only that model
    if (debugModeEnabled && selectedModel != DebugModelChoice.cascade) {
      _log('🔧 DEBUG MODE: Using single model - ${selectedModel.displayName}');
      return await _callSingleModel(imageBytesList, selectedModel);
    }

    Exception? lastError;

    // TIER 1: Gemini 2.5 Pro
    _log('=== TIER 1: Gemini 2.5 Pro ===');
    try {
      final result =
          await _callGeminiWithRetry(imageBytesList, 'gemini-2.5-pro');
      _log('TIER 1 SUCCESS! Gemini 2.5 Pro responded correctly');
      await _incrementAnalysisCount();
      // If we fell back from custom key, mark it (this is a heuristic, passing a flag would be cleaner but this works if we fell through)
      if (hasCustomKey && isCustomKeyEnabled) {
        final mutableResult = Map<String, dynamic>.from(result);
        mutableResult['__custom_key_fallback__'] = true;
        return mutableResult;
      }
      return result;
    } catch (e, stackTrace) {
      _logError('TIER 1 (Gemini 2.5 Pro)', e, stackTrace);
      lastError = e as Exception;
    }

    // TIER 2: Gemini 2.5 Flash (faster, higher quota)
    _log('=== TIER 2: Gemini 2.5 Flash ===');
    try {
      final result =
          await _callGeminiWithRetry(imageBytesList, 'gemini-2.5-flash');
      _log('TIER 2 SUCCESS! Gemini 2.5 Flash responded correctly');
      await _incrementAnalysisCount();
      if (hasCustomKey && isCustomKeyEnabled) {
        final mutableResult = Map<String, dynamic>.from(result);
        mutableResult['__custom_key_fallback__'] = true;
        return mutableResult;
      }
      return result;
    } catch (e, stackTrace) {
      _logError('TIER 2 (Gemini 2.5 Flash)', e, stackTrace);
      lastError = e as Exception;
    }

    // TIER 3: Groq Llama 4 Scout (multimodal, efficient)
    _log('=== TIER 3: Groq Llama 4 Scout ===');
    try {
      final result = await _callGroqWithRetry(
        imageBytesList,
        'meta-llama/llama-4-scout-17b-16e-instruct',
      );
      _log('TIER 3 SUCCESS! Groq Llama 4 Scout responded correctly');
      await _incrementAnalysisCount();
      if (hasCustomKey && isCustomKeyEnabled) {
        final mutableResult = Map<String, dynamic>.from(result);
        mutableResult['__custom_key_fallback__'] = true;
        return mutableResult;
      }
      return result;
    } catch (e, stackTrace) {
      _logError('TIER 3 (Groq Llama 4 Scout)', e, stackTrace);
      lastError = e as Exception;
    }

    // TIER 4: Groq Llama 4 Maverick (multimodal, high quality)
    _log('=== TIER 4: Groq Llama 4 Maverick ===');
    try {
      final result = await _callGroqWithRetry(
        imageBytesList,
        'meta-llama/llama-4-maverick-17b-128e-instruct',
      );
      _log('TIER 4 SUCCESS! Groq Llama 4 Maverick responded correctly');
      await _incrementAnalysisCount();
      await _incrementAnalysisCount();
      if (hasCustomKey && isCustomKeyEnabled) {
        final mutableResult = Map<String, dynamic>.from(result);
        mutableResult['__custom_key_fallback__'] = true;
        return mutableResult;
      }
      return result;
    } catch (e, stackTrace) {
      _logError('TIER 4 (Groq Llama 4 Maverick)', e, stackTrace);
      lastError = e as Exception;
    }

    // All models failed
    _log('=== ALL 4 TIERS FAILED! ===');
    _log('Last error: $lastError');
    throw Exception('ALL_MODELS_FAILED: ${lastError.toString()}');
  }

  /// Call Gemini with exponential backoff retry
  static Future<Map<String, dynamic>> _callGeminiWithRetry(
      List<Uint8List> imageBytesList, String modelName) async {
    Exception? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        debugPrint('--- Gemini $modelName attempt $attempt/$_maxRetries ---');
        return await _callGemini(imageBytesList, modelName);
      } catch (e) {
        lastError = e as Exception;
        debugPrint('--- Gemini $modelName attempt $attempt failed: $e ---');

        if (attempt < _maxRetries) {
          final delay = pow(2, attempt).toInt();
          debugPrint('--- Waiting ${delay}s before retry ---');
          await Future.delayed(Duration(seconds: delay));
        }
      }
    }

    throw lastError ??
        Exception('Gemini $modelName failed after $_maxRetries attempts');
  }

  /// Call Gemini API
  static Future<Map<String, dynamic>> _callGemini(
      List<Uint8List> imageBytesList, String modelName,
      {String? overrideApiKey}) async {
    _log('Gemini: Creating model instance');
    _log('Gemini: Model = $modelName');

    final apiKeyToUse = overrideApiKey ?? Env.geminiApiKey;
    _log('Gemini: API Key length = ${apiKeyToUse.length} chars');

    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKeyToUse,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
      systemInstruction: Content.system(_doctorLovePrompt),
    );

    if (AICascadeService.debugModeEnabled) {
      final k = apiKeyToUse;
      final masked = k.length > 8
          ? '${k.substring(0, 4)}...${k.substring(k.length - 4)}'
          : 'SHORT';
      _log('Gemini: Using KEY: $masked');
    }

    final List<Part> parts = [TextPart('Analizza questi screenshot di chat.')];
    for (var bytes in imageBytesList) {
      parts.add(DataPart('image/jpeg', bytes));
    }
    _log(
        'Gemini: Prepared ${parts.length} parts (1 text + ${imageBytesList.length} images)');

    final content = [Content.multi(parts)];

    _log('Gemini: Sending request to API...');
    final stopwatch = Stopwatch()..start();

    try {
      final response = await model.generateContent(content);
      stopwatch.stop();
      _log('Gemini: Response received in ${stopwatch.elapsedMilliseconds}ms');

      final text = response.text;
      _log('Gemini: Response text length = ${text?.length ?? 0}');

      if (text == null || text.isEmpty) {
        _log('Gemini: Empty response!');
        throw Exception('Empty response from Gemini');
      }

      _log(
          'Gemini: Response preview: ${text.substring(0, min(200, text.length))}...');

      final cleanText =
          text.replaceAll('```json', '').replaceAll('```', '').trim();

      final parsed = jsonDecode(cleanText) as Map<String, dynamic>;
      _log('Gemini: JSON parsed successfully. Score: ${parsed['score']}');
      return parsed;
    } catch (e, stackTrace) {
      stopwatch.stop();
      _log('Gemini: Request failed after ${stopwatch.elapsedMilliseconds}ms');
      _logError('Gemini._callGemini', e, stackTrace);
      rethrow;
    }
  }

  /// Call Groq with exponential backoff retry
  static Future<Map<String, dynamic>> _callGroqWithRetry(
    List<Uint8List> imageBytesList,
    String modelId,
  ) async {
    Exception? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        _log('Groq ($modelId): Attempt $attempt/$_maxRetries');
        return await _callGroq(imageBytesList, modelId);
      } catch (e, stackTrace) {
        lastError = e as Exception;
        _logError('Groq attempt $attempt', e, stackTrace);

        if (attempt < _maxRetries) {
          final delay = pow(2, attempt).toInt();
          _log('Groq: Waiting ${delay}s before retry...');
          await Future.delayed(Duration(seconds: delay));
        }
      }
    }

    throw lastError ??
        Exception('Groq $modelId failed after $_maxRetries attempts');
  }

  /// Merge multiple images into max 5 composite images by stitching vertically
  /// Groups images together and stacks them vertically in each group
  static Future<List<Uint8List>> _mergeImagesForGroq(
      List<Uint8List> images) async {
    if (images.length <= 5) return images;

    // Calculate how many images per group (aim for 5 output images)
    final imagesPerGroup = (images.length / 5).ceil();
    _log('Groq merge: ${images.length} images -> groups of $imagesPerGroup');

    final List<Uint8List> mergedImages = [];

    for (int groupStart = 0;
        groupStart < images.length;
        groupStart += imagesPerGroup) {
      final groupEnd = (groupStart + imagesPerGroup).clamp(0, images.length);
      final groupImages = images.sublist(groupStart, groupEnd);

      if (groupImages.length == 1) {
        mergedImages.add(groupImages.first);
        continue;
      }

      // Decode all images in the group
      final List<img.Image> decodedImages = [];
      for (final bytes in groupImages) {
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          decodedImages.add(decoded);
        }
      }

      if (decodedImages.isEmpty) continue;
      if (decodedImages.length == 1) {
        mergedImages.add(groupImages.first);
        continue;
      }

      // Calculate total dimensions for vertical stacking
      int maxWidth = 0;
      int totalHeight = 0;
      for (final image in decodedImages) {
        if (image.width > maxWidth) maxWidth = image.width;
        totalHeight += image.height;
      }

      // Create composite image
      final composite = img.Image(width: maxWidth, height: totalHeight);

      // Fill with white background
      img.fill(composite, color: img.ColorRgb8(255, 255, 255));

      // Stack images vertically
      int currentY = 0;
      for (final image in decodedImages) {
        // Center horizontally if narrower than max width
        final offsetX = (maxWidth - image.width) ~/ 2;
        img.compositeImage(composite, image, dstX: offsetX, dstY: currentY);
        currentY += image.height;
      }

      // Encode to PNG and add to result
      final mergedBytes = Uint8List.fromList(img.encodePng(composite));
      mergedImages.add(mergedBytes);
      _log(
          'Groq merge: Group ${mergedImages.length} = ${groupImages.length} images -> ${mergedBytes.length} bytes');
    }

    return mergedImages.take(5).toList(); // Ensure max 5
  }

  /// Call Groq API for Llama Vision models (OpenAI-compatible)
  static Future<Map<String, dynamic>> _callGroq(
    List<Uint8List> imageBytesList,
    String modelId,
  ) async {
    const url = 'https://api.groq.com/openai/v1/chat/completions';
    _log('Groq: Model = $modelId');
    _log('Groq: API Key length = ${Env.groqApiKey.length} chars');
    _log('Groq: Number of images received = ${imageBytesList.length}');

    // Build message content - images first, then text (as recommended)
    final List<Map<String, dynamic>> messageContent = [];

    // Groq Llama 4 supports max 5 images - merge if more
    List<Uint8List> imagesToProcess;
    if (imageBytesList.length > 5) {
      _log(
          'Groq: Merging ${imageBytesList.length} images into max 5 composites');
      imagesToProcess = await _mergeImagesForGroq(imageBytesList);
      _log('Groq: After merge: ${imagesToProcess.length} images');
    } else {
      imagesToProcess = imageBytesList;
    }

    // Add images first
    for (var bytes in imagesToProcess) {
      final b64 = base64Encode(bytes);
      _log(
          'Groq: Image size = ${bytes.length} bytes, base64 = ${b64.length} chars');

      // Detect image type from magic bytes
      String mimeType = 'image/jpeg';
      if (bytes.length > 8) {
        if (bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47) {
          mimeType = 'image/png';
        } else if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
          mimeType = 'image/gif';
        }
      }
      _log('Groq: Detected mime type = $mimeType');

      messageContent.add({
        'type': 'image_url',
        'image_url': {
          'url': 'data:$mimeType;base64,$b64',
        },
      });
    }

    // Add full Doctor Love prompt after images
    messageContent.add({
      'type': 'text',
      'text':
          '$_doctorLovePrompt\n\nAnalizza questi screenshot di chat e rispondi SOLO con il JSON richiesto.',
    });

    final payload = {
      'model': modelId,
      'messages': [
        {
          'role': 'user',
          'content': messageContent,
        },
      ],
      'max_tokens': 2048,
      'temperature': 0.7,
    };

    _log('Groq: Sending POST request...');
    final stopwatch = Stopwatch()..start();

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer ${Env.groqApiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));

      stopwatch.stop();
      _log('Groq: Response received in ${stopwatch.elapsedMilliseconds}ms');
      _log('Groq: Status code = ${response.statusCode}');

      if (response.statusCode == 429) {
        _log('Groq: Rate limit hit (429)');
        throw Exception('Groq rate limit exceeded');
      }

      if (response.statusCode != 200) {
        _log('Groq: API error ${response.statusCode}');
        _log('Groq: Response body = ${response.body}');
        throw Exception(
            'Groq API error: ${response.statusCode} - ${response.body}');
      }

      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

      // Extract content from OpenAI-style response
      final choices = responseBody['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('Groq: No choices in response');
      }

      final message = choices[0]['message'] as Map<String, dynamic>;
      final content = message['content'] as String?;

      if (content == null || content.isEmpty) {
        _log('Groq: Empty content in response');
        throw Exception('Empty response from Groq');
      }

      _log('Groq: Content length = ${content.length}');
      _log(
          'Groq: Content preview = ${content.substring(0, min(200, content.length))}...');

      // Extract JSON from response
      final cleanContent =
          content.replaceAll('```json', '').replaceAll('```', '').trim();

      // Try to find JSON object in response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(cleanContent);
      if (jsonMatch == null) {
        _log('Groq: No valid JSON found in response');
        _log('Groq: Raw content: $cleanContent');
        throw Exception('No valid JSON found in Groq response');
      }

      final parsed = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      _log('Groq: JSON parsed successfully. Score: ${parsed['score']}');

      // Log usage stats
      final usage = responseBody['usage'] as Map<String, dynamic>?;
      if (usage != null) {
        _log(
            'Groq: Tokens used - prompt: ${usage['prompt_tokens']}, completion: ${usage['completion_tokens']}');
      }

      return parsed;
    } catch (e, stackTrace) {
      stopwatch.stop();
      _log('Groq: Request failed after ${stopwatch.elapsedMilliseconds}ms');
      _logError('Groq._callGroq', e, stackTrace);
      rethrow;
    }
  }

  /// Parse user-friendly error messages
  static String parseError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Differentiate between App Limit and API Quota
    if (errorStr.contains('rate_limit_exceeded')) {
      return TranslationService()
          .tr('error_rate_limit')
          .replaceAll('{limit}', '$_maxAnalysesPerDay');
    }
    // Deep check for API quota - usually triggered by Custom Keys
    if (errorStr.contains('quota') ||
        errorStr.contains('resource_exhausted') ||
        errorStr.contains('429')) {
      return TranslationService().tr('error_quota_exhausted');
    }

    if (errorStr.contains('all_models_failed')) {
      return TranslationService().tr('error_all_models_failed');
    }
    if (errorStr.contains('api_key_invalid') ||
        errorStr.contains('invalid api key') ||
        errorStr.contains('invalid_api_key')) {
      return TranslationService().tr('error_invalid_api_key');
    }
    if (errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout')) {
      return TranslationService().tr('error_network');
    }
    if (errorStr.contains('empty response')) {
      return TranslationService().tr('error_empty_response');
    }

    // Generic fallback
    final shortError = error.toString();
    if (shortError.length > 100) {
      return '${TranslationService().tr('error_prefix')}: ${shortError.substring(0, 100)}...';
    }
    return '${TranslationService().tr('error_analysis_failed')}: $shortError';
  }
}
