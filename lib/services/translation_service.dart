import 'package:flutter/material.dart';
import 'dart:ui';
import 'user_preferences_service.dart';

class TranslationService extends ChangeNotifier {
  static final TranslationService _instance = TranslationService._internal();

  factory TranslationService() {
    return _instance;
  }

  TranslationService._internal();

  /// Current language code ('it' or 'en')
  String _currentLanguage = 'it';

  /// Get current language
  String get currentLanguage => _currentLanguage;

  /// Initialize service
  Future<void> initialize() async {
    // 1. Check for manual override
    final override = await UserPreferencesService.getLanguageOverride();
    if (override != null) {
      _currentLanguage = override;
      notifyListeners();
      return;
    }

    // 2. Auto-detect from device
    final deviceLocale = PlatformDispatcher.instance.locale.languageCode;
    if (deviceLocale == 'it') {
      _currentLanguage = 'it';
    } else {
      _currentLanguage = 'en'; // Default to English for everything else
    }
    notifyListeners();
  }

  /// Change language
  Future<void> setLanguage(String languageCode) async {
    if (languageCode != 'it' && languageCode != 'en') return;
    _currentLanguage = languageCode;
    await UserPreferencesService.setLanguageOverride(languageCode);
    notifyListeners();
  }

  /// Get translated string
  String tr(String key) {
    if (_localizedValues.containsKey(key)) {
      return _localizedValues[key]![_currentLanguage] ??
          _localizedValues[key]!['en'] ??
          key;
    }
    return key;
  }

  // ============================================================
  // DICTIONARY
  // ============================================================

  static const Map<String, Map<String, String>> _localizedValues = {
    // APP TITLE
    'app_title': {
      'it': 'Doctor Love',
      'en': 'Doctor Love',
    },
    'subtitle': {
      'it': 'Analizzatore di Chat AI',
      'en': 'AI Chat Analyzer',
    },
    'subtitle_desc': {
      'it': 'Scopri in pochi secondi se ti desidera davvero 💜',
      'en': 'Discover if they really desire you in a few seconds 💜',
    },

    // MENU ITEMS
    'menu_instructions': {
      'it': 'Istruzioni',
      'en': 'Instructions',
    },
    'menu_api_key': {
      'it': 'API Key Personale',
      'en': 'Personal API Key',
    },
    'menu_privacy': {
      'it': 'Privacy Policy',
      'en': 'Privacy Policy',
    },
    'menu_contact': {
      'it': 'Contattaci',
      'en': 'Contact Us',
    },
    'menu_rate': {
      'it': 'Valuta l\'app',
      'en': 'Rate App',
    },
    'menu_share': {
      'it': 'Condividi',
      'en': 'Share',
    },
    'menu_dark_mode': {
      'it': 'Tema Scuro',
      'en': 'Dark Mode',
    },
    'menu_language': {
      'it': 'Lingua / Language',
      'en': 'Language / Lingua',
    },
    'menu_credits': {
      'it': 'Crediti & Licenze',
      'en': 'Credits & Licenses',
    },
    'menu_version': {
      'it': 'Versione',
      'en': 'Version',
    },
    'menu_delete_data': {
      'it': 'Elimina Dati',
      'en': 'Delete Data',
    },

    // BUTTONS
    'btn_analyze': {
      'it': 'ANALIZZA ORA',
      'en': 'ANALYZE NOW',
    },
    'btn_scanner_live': {
      'it': 'SCANNER',
      'en': 'SCANNER',
    },
    'btn_scanner_usa': {
      'it': 'USA',
      'en': 'USE',
    },
    'btn_scanner_live_text': {
      'it': 'LIVE',
      'en': 'LIVE',
    },
    'btn_upload_chat': {
      'it': 'Upload Chat',
      'en': 'Upload Chat',
    },
    'btn_cancel': {
      'it': 'Annulla',
      'en': 'Cancel',
    },
    'btn_save': {
      'it': 'Salva',
      'en': 'Save',
    },
    'btn_remove': {
      'it': 'Rimuovi',
      'en': 'Remove',
    },
    'btn_close': {
      'it': 'Chiudi',
      'en': 'Close',
    },
    'btn_understood': {
      'it': 'HO CAPITO',
      'en': 'GOT IT',
    },
    'btn_delete_all': {
      'it': 'Elimina tutto',
      'en': 'Delete all',
    },
    'btn_clear_all': {
      'it': 'Cancella tutti',
      'en': 'Clear all',
    },

    // DIALOGS - API KEY
    'dialog_api_title': {
      'it': 'Google Gemini API Key',
      'en': 'Google Gemini API Key',
    },
    'dialog_api_desc_1': {
      'it':
          'Vantaggi con la tua API Key:\n\n• Modello Gemini 2.5 Pro (con abbonamento Google attivo)\n• Modello Gemini 2.5 Flash (anche senza abbonamento attivo)\n\nPer analisi ILLIMITATE e più veloci.',
      'en':
          'Benefits with your API Key:\n\n• Gemini 2.5 Pro Model (with active Google subscription)\n• Gemini 2.5 Flash Model (even without active subscription)\n\nFor UNLIMITED and faster analyses.',
    },
    'dialog_api_desc_2': {
      'it':
          'La tua chiave verrà salvata in modo sicuro nel dispositivo crittografato.',
      'en': 'Your key will be securely saved in the encrypted device storage.',
    },
    'dialog_api_hint': {
      'it': 'Incolla qui la tua API Key',
      'en': 'Paste your API Key here',
    },
    'dialog_api_get_key': {
      'it': 'Ottieni una API Key gratuita qui',
      'en': 'Get a free API Key here',
    },
    'dialog_api_status_used': {
      'it': '✅ Chiave salvata e in uso',
      'en': '✅ Key saved and in use',
    },
    'dialog_api_status_test_ok': {
      'it': '✅ Connessione riuscita!',
      'en': '✅ Connection successful!',
    },
    'dialog_api_status_test_fail': {
      'it': '❌ Chiave non valida',
      'en': '❌ Invalid Key',
    },

    // DIALOGS - INSTRUCTIONS
    'dialog_instructions_title': {
      'it': '📱 Istruzioni',
      'en': '📱 Instructions',
    },
    'dialog_instructions_how_works': {
      'it': 'COME FUNZIONA',
      'en': 'HOW IT WORKS',
    },
    'dialog_instructions_step_1': {
      'it': '1. Premi \'Attiva Scanner Live\'',
      'en': '1. Tap \'Use Live Scanner\'',
    },
    'dialog_instructions_step_2': {
      'it': '2. Clicca su \'Condividi schermo\'',
      'en': '2. Tap \'Share screen\'',
    },
    'dialog_instructions_step_3': {
      'it': '3. Apri la chat da analizzare',
      'en': '3. Open the chat to analyze',
    },
    'dialog_instructions_icon_usage': {
      'it': 'COME USARE L\'ICONA 👻',
      'en': 'HOW TO USE THE ICON 👻',
    },
    'dialog_instructions_tap_single': {
      'it': '• Tap singolo → Cattura screenshot',
      'en': '• Single tap → Capture screenshot',
    },
    'dialog_instructions_tap_double': {
      'it': '• Doppio tap → Torna all\'app',
      'en': '• Double tap → Return to app',
    },
    'dialog_instructions_drag': {
      'it': 'Trascina l\'icona dove preferisci!',
      'en': 'Drag the icon wherever you want!',
    },
    'dialog_instructions_dont_show': {
      'it': 'Non mostrare più',
      'en': 'Don\'t show again',
    },

    // DIALOGS - DELETE DATA
    'dialog_delete_title': {
      'it': 'Elimina Dati',
      'en': 'Delete Data',
    },
    'dialog_delete_content': {
      'it':
          '⚠️ Questa azione eliminerà:\n\n• Preferenze salvate\n• API key personale (se inserita)\n\nL\'app tornerà alle impostazioni di fabbrica.\n\nSei sicuro di voler procedere?',
      'en':
          '⚠️ This action will delete:\n\n• Saved preferences\n• Personal API key (if set)\n\nThe app will reset to factory settings.\n\nAre you sure you want to proceed?',
    },
    'dialog_delete_success': {
      'it': '✅ Tutti i dati sono stati eliminati',
      'en': '✅ All data has been deleted',
    },

    // DIALOGS - CREDITS
    'credits_developed_by': {
      'it': 'Sviluppato da Doctor Love Team',
      'en': 'Developed by Doctor Love Team',
    },
    'credits_tech_used': {
      'it': 'Tecnologie utilizzate:',
      'en': 'Technologies used:',
    },

    // MAIN SCREEN TEXTS
    'main_screenshots_count': {
      'it': 'SCREENSHOT',
      'en': 'SCREENSHOTS',
    },
    'main_today_limit_reached': {
      'it': 'Oggi sei al 100% 🔥',
      'en': 'You\'re at 100% today 🔥',
    },
    'main_analysis_remaining': {
      'it': 'Analisi rimaste oggi',
      'en': 'Analyses remaining today',
    },
    'main_come_back_tomorrow': {
      'it': 'Torna domani! 🌙',
      'en': 'Come back tomorrow! 🌙',
    },
    'main_analyzing': {
      'it': 'Analisi in corso...',
      'en': 'Analyzing...',
    },
    'main_analyzing_long': {
      'it':
          'Analisi approfondita con Gemini 2.5 Pro...\nPotrebbe richiedere fino a 30 secondi.',
      'en': 'Deep analysis with Gemini 2.5 Pro...\nMay take up to 30 seconds.',
    },
    'main_error_generic': {
      'it': 'Si è verificato un errore',
      'en': 'An error occurred',
    },
    'main_error_no_images': {
      'it': 'Seleziona almeno un\'immagine',
      'en': 'Select at least one image',
    },
    'main_result_title': {
      'it': 'RISULTATO ANALISI',
      'en': 'ANALYSIS RESULT',
    },
    'main_rating_explanation': {
      'it': 'Punteggio basato su segnali verbali e non verbali',
      'en': 'Score based on verbal and non-verbal signals',
    },
    'main_share_text': {
      'it': 'Ho analizzato una chat con Doctor Love! Risultato: ',
      'en': 'I analyzed a chat with Doctor Love! Result: ',
    },

    // TOASTS / SNACKBARS
    'toast_gallery_error': {
      'it': 'Errore apertura galleria',
      'en': 'Error opening gallery',
    },
    'toast_analysis_limit': {
      'it': 'Hai raggiunto il limite giornaliero!',
      'en': 'You reached the daily limit!',
    },

    // NEW KEYS v3.7.1
    'api_key_active_banner': {
      'it': 'Api key attiva! Stai usando analisi illimitate',
      'en': 'Api key active! You are using unlimited analyses',
    },
    'instant_analysis': {
      'it': 'Analisi Istantanea',
      'en': 'Instant Analysis',
    },
    'daily_limit_subtitle': {
      'it': '5 al giorno - 100% anonimo',
      'en': '5 per day - 100% anonymous',
    },
    'unlimited_mode': {
      'it': 'Modalità Illimitata',
      'en': 'Unlimited Mode',
    },
  };
}
