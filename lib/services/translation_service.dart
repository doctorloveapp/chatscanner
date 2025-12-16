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
    'anonymous_100': {
      'it': '100% Anonimo',
      'en': '100% Anonymous',
    },

    // V3.7.2 MISSING TRANSLATIONS
    // API KEY DIALOG
    'api_key_new_optional': {
      'it': 'Nuova API Key (opzionale)',
      'en': 'New API Key (optional)',
    },
    'api_key_insert': {
      'it': 'Inserisci API Key',
      'en': 'Insert API Key',
    },
    'api_key_paste_tooltip': {
      'it': 'Incolla',
      'en': 'Paste',
    },
    'api_key_use_this': {
      'it': 'Usa questa API Key',
      'en': 'Use this API Key',
    },
    'api_key_active': {
      'it': 'Attiva',
      'en': 'Active',
    },
    'api_key_disabled_default': {
      'it': 'Disattivata (Usa default)',
      'en': 'Disabled (Use default)',
    },
    'api_key_benefits_title': {
      'it': 'Vantaggi con la tua Google API Key:',
      'en': 'Benefits with your Google API Key:',
    },
    'api_key_benefit_1': {
      'it': '✓ Analisi illimitate',
      'en': '✓ Unlimited analyses',
    },
    'api_key_benefit_2': {
      'it': '✓ Nessun limite giornaliero',
      'en': '✓ No daily limit',
    },
    'api_key_benefit_3': {
      'it': '✓ Modello Gemini 2.5 Pro',
      'en': '✓ Gemini 2.5 Pro Model',
    },
    'api_key_how_to_title': {
      'it': '📋 Come ottenere la tua API Key:',
      'en': '📋 How to get your API Key:',
    },
    'api_key_instructions': {
      'it':
          '1. Vai su Google AI Studio\n2. Accedi e clicca "Get API Key"\n3. Clicca "Create API Key" (seleziona "New Project")\n4. Copia la chiave e incollala qui sotto',
      'en':
          '1. Go to Google AI Studio\n2. Sign in and click "Get API Key"\n3. Click "Create API Key" (select "New Project")\n4. Copy the key and paste it below',
    },
    'api_key_open_studio': {
      'it': 'Apri Google AI Studio',
      'en': 'Open Google AI Studio',
    },
    'api_key_remove_title': {
      'it': 'Rimuovere API Key?',
      'en': 'Remove API Key?',
    },
    'api_key_remove_desc': {
      'it': 'Tornerai al piano gratuito con 5 analisi al giorno.',
      'en': 'You will return to the free plan with 5 analyses per day.',
    },
    'btn_remove_key': {
      'it': 'Rimuovi Key',
      'en': 'Remove Key',
    },
    'btn_update': {
      'it': 'Aggiorna',
      'en': 'Update',
    },
    'api_key_invalid_format': {
      'it': '❌ API Key non valida. Deve iniziare con "AIzaSy"',
      'en': '❌ Invalid API Key. Must start with "AIzaSy"',
    },
    'api_key_saved_active': {
      'it': '✅ Chiave salvata e attivata! Analisi illimitate 🎉',
      'en': '✅ Key saved and activated! Unlimited analyses 🎉',
    },
    'api_key_removed_msg': {
      'it': '✅ API Key rimossa',
      'en': '✅ API Key removed',
    },

    // DARK MODE DIALOG
    'theme_dark_title': {
      'it': 'Tema Scuro',
      'en': 'Dark Mode',
    },
    'theme_dark': {
      'it': 'Tema Scuro',
      'en': 'Dark Mode',
    },
    'theme_light': {
      'it': 'Tema Chiaro',
      'en': 'Light Mode',
    },
    'theme_toggle_hint': {
      'it': 'Tocca per cambiare',
      'en': 'Tap to switch',
    },
    'theme_auto_save': {
      'it': 'Il tema viene salvato automaticamente.',
      'en': 'Theme is saved automatically.',
    },

    // VERSION DIALOG
    'version_title': {
      'it': 'Versione',
      'en': 'Version',
    },
    'version_label': {
      'it': 'Versione: ',
      'en': 'Version: ',
    },
    'build_label': {
      'it': 'Build: ',
      'en': 'Build: ',
    },
    'version_latest': {
      'it': '✅ Sei alla versione più recente!',
      'en': '✅ You are on the latest version!',
    },
    'btn_ok': {
      'it': 'OK',
      'en': 'OK',
    },

    // DELETE DATA
    'delete_data_title': {
      'it': 'Elimina Dati',
      'en': 'Delete Data',
    },
    'delete_data_success': {
      'it': '✅ Tutti i dati sono stati eliminati',
      'en': '✅ All data has been deleted',
    },
    'screenshots_deleted': {
      'it': '🗑️ Tutti gli screenshot sono stati eliminati',
      'en': '🗑️ All screenshots have been deleted',
    },
    'screenshots_new_ready': {
      'it': '📸 nuovi screenshot pronti per l\'analisi!',
      'en': '📸 new screenshots ready for analysis!',
    },
    // DAILY LIMIT DIALOG
    'daily_limit_title': {
      'it': 'Analisi Giornaliere',
      'en': 'Daily Analysis',
    },
    'daily_limit_explanation': {
      'it':
          'Hai a disposizione {limit} analisi gratuite ogni giorno.\n\nIl contatore si resetta automaticamente a mezzanotte.\n\n💜 Viola = 4+ rimaste\n🧡 Arancio = 1-3 rimaste\n❤️ Rosso = 0 rimaste',
      'en':
          'You have {limit} free analyses available every day.\n\nThe counter resets automatically at midnight.\n\n💜 Purple = 4+ left\n🧡 Orange = 1-3 left\n❤️ Red = 0 left',
    },
    'btn_got_it_normal': {
      'it': 'Ho capito!',
      'en': 'Got it!',
    },

    // LOADING MESSAGES (during analysis)
    'loading_init': {
      'it': 'Inizializzazione...',
      'en': 'Initializing...',
    },
    'loading_1': {
      'it': 'Analisi pattern comunicativi...',
      'en': 'Analyzing communication patterns...',
    },
    'loading_2': {
      'it': 'Elaborazione tempi di risposta...',
      'en': 'Processing response times...',
    },
    'loading_3': {
      'it': 'Valutazione coinvolgimento emotivo...',
      'en': 'Evaluating emotional engagement...',
    },
    'loading_4': {
      'it': 'Calcolo indice di interesse...',
      'en': 'Calculating interest index...',
    },
    'loading_5': {
      'it': 'Analisi linguaggio non verbale...',
      'en': 'Analyzing non-verbal language...',
    },
    'loading_6': {
      'it': 'Elaborazione risultati finali...',
      'en': 'Processing final results...',
    },

    // RESULT SECTION
    'result_section_analysis': {
      'it': 'ANALISI',
      'en': 'ANALYSIS',
    },
    'result_section_rating': {
      'it': 'VALUTAZIONE FRASI',
      'en': 'LINE RATINGS',
    },
    'result_section_nextmove': {
      'it': 'PROSSIMA MOSSA',
      'en': 'NEXT MOVE',
    },
    'result_copy': {
      'it': 'Copia',
      'en': 'Copy',
    },
    'result_copied': {
      'it': 'Copiato! 📋',
      'en': 'Copied! 📋',
    },
    'result_new_analysis': {
      'it': 'NUOVA ANALISI',
      'en': 'NEW ANALYSIS',
    },

    // ERROR MESSAGES
    'error_service_overloaded': {
      'it': '😔 Servizio sovraccarico, riprova tra poco',
      'en': '😔 Service overloaded, try again shortly',
    },
    'error_quota_exceeded': {
      'it': '⏰ Quota giornaliera esaurita! Torna domani 💜',
      'en': '⏰ Daily quota exceeded! Come back tomorrow 💜',
    },
    'error_generic': {
      'it': '❌ Si è verificato un errore',
      'en': '❌ An error occurred',
    },

    // SHARE APP
    'share_message': {
      'it':
          '💕 Prova Doctor Love - Analizza le tue chat e scopri se c\'è interesse!\\n\\nhttps://play.google.com/store/apps/details?id=com.doctorloveapp.chatscanner',
      'en':
          '💕 Try Doctor Love - Analyze your chats and discover if there\'s interest!\\n\\nhttps://play.google.com/store/apps/details?id=com.doctorloveapp.chatscanner',
    },

    // SCREEN RECORDING PERMISSION
    'permission_screen_record': {
      'it':
          '⚠️ Concedi il permesso di registrazione schermo nella finestra popup',
      'en': '⚠️ Grant screen recording permission in the popup window',
    },

    // RESULT SECTION - MORE
    'result_verdict': {
      'it': 'VERDETTO',
      'en': 'VERDICT',
    },
    'result_line_analysis': {
      'it': 'ANALISI FRASI',
      'en': 'LINE ANALYSIS',
    },
    'result_next_move': {
      'it': 'PROSSIMA MOSSA',
      'en': 'NEXT MOVE',
    },
    'result_copied_clipboard': {
      'it': 'Copiato negli appunti!',
      'en': 'Copied to clipboard!',
    },
    'btn_copy': {
      'it': 'COPIA',
      'en': 'COPY',
    },
    'btn_add_more_screens': {
      'it': 'AGGIUNGI ALTRI SCREEN',
      'en': 'ADD MORE SCREENSHOTS',
    },
    'btn_analyze_another': {
      'it': "ANALIZZA UN'ALTRA CHAT",
      'en': 'ANALYZE ANOTHER CHAT',
    },
    'result_interest': {
      'it': 'INTERESSE',
      'en': 'INTEREST',
    },

    // ERROR MESSAGES - DETAILED
    'error_rate_limit': {
      'it': 'Hai raggiunto il limite di {limit} analisi oggi. Riprova domani!',
      'en':
          'You reached the limit of {limit} analyses today. Try again tomorrow!',
    },
    'error_quota_exhausted': {
      'it': '⚠️ La tua API Key ha esaurito la quota disponibile.',
      'en': '⚠️ Your API Key has exhausted its available quota.',
    },
    'error_all_models_failed': {
      'it': 'Servizio temporaneamente sovraccarico, riprova tra 1 minuto',
      'en': 'Service temporarily overloaded, try again in 1 minute',
    },
    'error_invalid_api_key': {
      'it': '❌ La tua API Key non è valida. Controlla di averla copiata bene.',
      'en': '❌ Your API Key is not valid. Check that you copied it correctly.',
    },
    'error_network': {
      'it': 'Errore di connessione. Verifica internet.',
      'en': 'Connection error. Check your internet.',
    },
    'error_empty_response': {
      'it': "L'AI non ha risposto. Prova con screenshot più chiari.",
      'en': 'The AI did not respond. Try with clearer screenshots.',
    },
    'error_prefix': {
      'it': 'Errore',
      'en': 'Error',
    },
    'error_analysis_failed': {
      'it': 'Analisi fallita',
      'en': 'Analysis failed',
    },

    // API KEY FALLBACK DIALOG
    'fallback_title': {
      'it': '⚠️ API Key Consumata',
      'en': '⚠️ API Key Exhausted',
    },
    'fallback_content': {
      'it':
          "La tua API Key ha raggiunto il limite di quota.\n\nAbbiamo completato l'analisi usando il sistema di riserva di Doctor Love.\n\nVuoi disabilitare temporaneamente la tua chiave?",
      'en':
          "Your API Key has reached its quota limit.\n\nWe completed the analysis using Doctor Love's backup system.\n\nWould you like to temporarily disable your key?",
    },
    'fallback_keep_active': {
      'it': 'Mantieni attiva',
      'en': 'Keep active',
    },
    'fallback_disable_key': {
      'it': 'Disabilita Key',
      'en': 'Disable Key',
    },
    'fallback_disabled_success': {
      'it': '✅ Chiave disabilitata. Usiamo il sistema standard.',
      'en': '✅ Key disabled. Using standard system.',
    },
  };
}
