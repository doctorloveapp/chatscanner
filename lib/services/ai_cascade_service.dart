import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../env/env.dart';

/// Multi-tier AI cascade service for Doctor Love
/// Priority: Gemini 2.5 Pro → Llama 3.2 Vision → Qwen2-VL-7B
class AICascadeService {
  static const int _maxAnalysesPerDay = 10;
  static const int _maxRetries = 3;

  // Doctor Love system prompt - shared across all models
  static const String _doctorLovePrompt = '''
Sei Doctor Love, il dating coach più cinico e geniale d'Italia.
Analizza uno o più screenshot di chat WhatsApp/Instagram/Telegram (può esserci testo, emoji, timestamp, doppi check).
Valuta il livello di interesse reale dell'altra persona considerando:
- lunghezza e frequenza dei messaggi
- uso di emoji e punteggiatura
- chi inizia le conversazioni
- tempo di risposta visibile
- tono complessivo (entusiasta, freddo, amichevole, secco)

RESTITUISCI SOLO ed ESCLUSIVAMENTE un oggetto JSON valido (niente markdown, niente ```json, niente testo prima o dopo) con ESATTAMENTE questo schema:

{
  "score": 0-100,
  "analysis": "stringa breve (max 140 caratteri), spiritosa, leggermente pungente e brutale se necessario, sempre in italiano perfetto",
  "line_rating": [
    {
      "text": "testo esatto della frase (max 80 caratteri)",
      "rating": 1-10,
      "sender": "me" oppure "them"
    }
  ],
  "next_move": "il messaggio esatto da inviare ora (1-3 frasi massimo, naturale, italiano perfetto, che massimizzi le probabilità di risposta entusiasta). Se la chat è morta scrivi solo: 'Molla, non c'è più niente da fare 💀'"
}

Regole ferree:
- Mai gentile per forza, sii onesto
- Usa sempre italiano corrente (niente frasi da manuale del 1800)
- Se non vedi testo leggibile rispondi con score 0 e analysis "Screenshot illeggibile o vuoto"
- Il JSON deve essere parsabile al 100%
''';

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

  /// Main analysis method with 3-tier cascade
  static Future<Map<String, dynamic>> analyzeImages(
      List<Uint8List> imageBytesList) async {
    // Check rate limit
    final remaining = await getRemainingAnalyses();
    if (remaining <= 0) {
      throw Exception('RATE_LIMIT_EXCEEDED');
    }

    Exception? lastError;

    // TIER 1: Gemini 2.5 Pro
    debugPrint('=== AI CASCADE: Trying TIER 1 (Gemini 2.5 Pro) ===');
    try {
      final result = await _callGeminiWithRetry(imageBytesList);
      await _incrementAnalysisCount();
      return result;
    } catch (e) {
      debugPrint('=== AI CASCADE: Gemini failed: $e ===');
      lastError = e as Exception;
    }

    // TIER 2: Llama 3.2 Vision
    debugPrint('=== AI CASCADE: Trying TIER 2 (Llama 3.2 Vision) ===');
    try {
      final result = await _callHuggingFaceWithRetry(
        imageBytesList,
        'meta-llama/Llama-3.2-11B-Vision-Instruct',
      );
      await _incrementAnalysisCount();
      return result;
    } catch (e) {
      debugPrint('=== AI CASCADE: Llama failed: $e ===');
      lastError = e as Exception;
    }

    // TIER 3: Qwen2-VL-7B
    debugPrint('=== AI CASCADE: Trying TIER 3 (Qwen2-VL-7B) ===');
    try {
      final result = await _callHuggingFaceWithRetry(
        imageBytesList,
        'Qwen/Qwen2-VL-7B-Instruct',
      );
      await _incrementAnalysisCount();
      return result;
    } catch (e) {
      debugPrint('=== AI CASCADE: Qwen failed: $e ===');
      lastError = e as Exception;
    }

    // All models failed
    throw Exception(
        'ALL_MODELS_FAILED: ${lastError?.toString() ?? "Unknown error"}');
  }

  /// Call Gemini with exponential backoff retry
  static Future<Map<String, dynamic>> _callGeminiWithRetry(
      List<Uint8List> imageBytesList) async {
    Exception? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        debugPrint('--- Gemini attempt $attempt/$_maxRetries ---');
        return await _callGemini(imageBytesList);
      } catch (e) {
        lastError = e as Exception;
        debugPrint('--- Gemini attempt $attempt failed: $e ---');

        if (attempt < _maxRetries) {
          final delay = pow(2, attempt).toInt();
          debugPrint('--- Waiting ${delay}s before retry ---');
          await Future.delayed(Duration(seconds: delay));
        }
      }
    }

    throw lastError ?? Exception('Gemini failed after $_maxRetries attempts');
  }

  /// Call Gemini API
  static Future<Map<String, dynamic>> _callGemini(
      List<Uint8List> imageBytesList) async {
    final model = GenerativeModel(
      model: 'gemini-2.5-pro',
      apiKey: Env.geminiApiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
      systemInstruction: Content.system(_doctorLovePrompt),
    );

    final List<Part> parts = [TextPart('Analizza questi screenshot di chat.')];
    for (var bytes in imageBytesList) {
      parts.add(DataPart('image/jpeg', bytes));
    }

    final content = [Content.multi(parts)];
    final response = await model.generateContent(content);
    final text = response.text;

    if (text == null || text.isEmpty) {
      throw Exception('Empty response from Gemini');
    }

    final cleanText =
        text.replaceAll('```json', '').replaceAll('```', '').trim();
    return jsonDecode(cleanText) as Map<String, dynamic>;
  }

  /// Call HuggingFace with exponential backoff retry
  static Future<Map<String, dynamic>> _callHuggingFaceWithRetry(
    List<Uint8List> imageBytesList,
    String modelId,
  ) async {
    Exception? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        debugPrint(
            '--- HuggingFace ($modelId) attempt $attempt/$_maxRetries ---');
        return await _callHuggingFace(imageBytesList, modelId);
      } catch (e) {
        lastError = e as Exception;
        debugPrint('--- HuggingFace attempt $attempt failed: $e ---');

        if (attempt < _maxRetries) {
          final delay = pow(2, attempt).toInt();
          debugPrint('--- Waiting ${delay}s before retry ---');
          await Future.delayed(Duration(seconds: delay));
        }
      }
    }

    throw lastError ??
        Exception('HuggingFace $modelId failed after $_maxRetries attempts');
  }

  /// Call HuggingFace Inference API for vision models
  static Future<Map<String, dynamic>> _callHuggingFace(
    List<Uint8List> imageBytesList,
    String modelId,
  ) async {
    // Combine images into base64 for the request
    // For vision models, we send the first image with our prompt
    final base64Image = base64Encode(imageBytesList.first);

    final response = await http
        .post(
          Uri.parse('https://api-inference.huggingface.co/models/$modelId'),
          headers: {
            'Authorization': 'Bearer ${Env.hfToken}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'inputs': {
              'image': base64Image,
              'text':
                  '$_doctorLovePrompt\n\nAnalizza questo screenshot di chat e rispondi SOLO con il JSON richiesto.',
            },
            'parameters': {
              'max_new_tokens': 1024,
              'return_full_text': false,
            },
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 503) {
      throw Exception('Model loading, please wait');
    }

    if (response.statusCode != 200) {
      throw Exception(
          'HuggingFace API error: ${response.statusCode} - ${response.body}');
    }

    final responseBody = jsonDecode(response.body);

    // Extract generated text from response
    String generatedText = '';
    if (responseBody is List && responseBody.isNotEmpty) {
      generatedText = responseBody[0]['generated_text'] ?? '';
    } else if (responseBody is Map) {
      generatedText = responseBody['generated_text'] ?? responseBody.toString();
    }

    if (generatedText.isEmpty) {
      throw Exception('Empty response from HuggingFace');
    }

    // Try to extract JSON from response
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(generatedText);
    if (jsonMatch == null) {
      throw Exception('No valid JSON found in response');
    }

    return jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
  }

  /// Parse user-friendly error messages
  static String parseError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('rate_limit_exceeded')) {
      return '⏰ Hai raggiunto il limite di 10 analisi oggi. Riprova domani!';
    }
    if (errorStr.contains('all_models_failed')) {
      return '💕 Servizio temporaneamente sovraccarico, riprova tra 1 minuto';
    }
    if (errorStr.contains('api_key_invalid') ||
        errorStr.contains('invalid api key')) {
      return '❌ Errore di configurazione API. Contatta il supporto.';
    }
    if (errorStr.contains('quota') || errorStr.contains('resource_exhausted')) {
      return '⏳ Limite richieste raggiunto. Riprova tra qualche minuto.';
    }
    if (errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout')) {
      return '📶 Errore di connessione. Verifica internet.';
    }
    if (errorStr.contains('empty response')) {
      return '🤔 L\'AI non ha risposto. Prova con screenshot più chiari.';
    }

    // Generic fallback
    final shortError = error.toString();
    if (shortError.length > 100) {
      return '❌ Errore: ${shortError.substring(0, 100)}...';
    }
    return '❌ Analisi fallita: $shortError';
  }
}
