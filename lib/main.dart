import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'services/ai_cascade_service.dart';
import 'services/remote_config_service.dart';
import 'services/user_preferences_service.dart';
import 'services/theme_service.dart';
import 'services/translation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Remote Config (for dynamic daily limit)
  await RemoteConfigService.initialize();

  // Initialize Translation Service
  await TranslationService().initialize();

  // Initialize Theme Service
  await themeService.initialize();

  runApp(const MyApp());
}

// Overlay entry point - MUST be in main.dart with @pragma annotation
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch any uncaught errors to prevent overlay from crashing
  FlutterError.onError = (details) {
    debugPrint("Overlay Flutter Error: ${details.exception}");
  };

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ScannerOverlayWidget(),
    ),
  );
}

class ScannerOverlayWidget extends StatefulWidget {
  const ScannerOverlayWidget({super.key});

  @override
  State<ScannerOverlayWidget> createState() => _ScannerOverlayWidgetState();
}

class _ScannerOverlayWidgetState extends State<ScannerOverlayWidget> {
  int _captureCount = 0;
  bool _isCapturing = false;
  Timer? _resetCheckTimer;

  @override
  void initState() {
    super.initState();
    // Start polling for reset file every 500ms
    _resetCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkForReset();
    });
  }

  @override
  void dispose() {
    _resetCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkForReset() async {
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) return;

      final resetFile = File('${extDir.path}/ghost_comm/reset_counter');
      if (await resetFile.exists()) {
        await resetFile.delete();
        if (mounted) {
          setState(() {
            _captureCount = 0;
          });
        }
        debugPrint("Overlay: Reset detected, counter = 0");
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _closeAndReturnToApp() async {
    debugPrint("Overlay: Closing overlay and returning to app...");
    try {
      // First, bring the app to foreground
      // This uses a method channel to launch the main activity
      const platform = MethodChannel('device_screenshot');
      try {
        await platform.invokeMethod('bringAppToForeground');
      } catch (e) {
        debugPrint("Overlay: Error bringing app to foreground: $e");
      }

      // Then close the overlay
      await FlutterOverlayWindow.closeOverlay();
      debugPrint("Overlay: Closed successfully");
    } catch (e) {
      debugPrint("Overlay: Error closing overlay: $e");
    }
  }

  Future<void> _requestScreenshot() async {
    // Prevent multiple simultaneous captures
    if (_isCapturing) {
      debugPrint("Overlay: Already capturing, ignoring tap");
      return;
    }

    _isCapturing = true;
    debugPrint("Overlay: Starting screenshot capture #${_captureCount + 1}...");

    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) {
        debugPrint("Overlay: Cannot get external storage");
        _isCapturing = false;
        return;
      }

      final commDir = Directory('${extDir.path}/ghost_comm');
      if (!await commDir.exists()) {
        await commDir.create(recursive: true);
      }

      final requestFile = File('${commDir.path}/capture_request');
      final resultFile = File('${commDir.path}/capture_result');

      // Delete old result file
      try {
        if (await resultFile.exists()) {
          await resultFile.delete();
        }
      } catch (_) {}

      // Write request file to trigger capture
      await requestFile.writeAsString(
        'capture_${DateTime.now().millisecondsSinceEpoch}',
      );
      debugPrint("Overlay: Request file written");

      // Simple polling with for loop
      bool success = false;
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 100));

        try {
          if (await resultFile.exists()) {
            final content = await resultFile.readAsString();
            debugPrint("Overlay: Result received: $content");

            if (content.startsWith('success:')) {
              success = true;
              debugPrint("Overlay: Screenshot captured successfully!");
            }

            // Clean up result file
            try {
              await resultFile.delete();
            } catch (_) {}
            break;
          }
        } catch (e) {
          debugPrint("Overlay: Error checking result: $e");
        }
      }

      if (success) {
        if (mounted) {
          setState(() {
            _captureCount++;
          });
        }
      }
    } catch (e) {
      debugPrint("Overlay: Error in _requestScreenshot: $e");
    }

    _isCapturing = false;
    debugPrint(
      "Overlay: Capture complete, ready for next tap. Total: $_captureCount",
    );
  }

  @override
  Widget build(BuildContext context) {
    // SOLUZIONE DEFINITIVA:
    // Finestra overlay: 200x200 dp
    // Cerchio riempie tutta la finestra
    // ClipOval per mascherare il quadrato

    const double size = 200.0; // Deve corrispondere a showOverlay height/width
    const double capturingSize = 185.0;
    const double emojiSize = 50.0; // Emoji proporzionata al cerchio

    final currentSize = _isCapturing ? capturingSize : size;

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _requestScreenshot,
        onDoubleTap: _closeAndReturnToApp,
        onLongPress: _closeAndReturnToApp,
        child: ClipOval(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: currentSize,
            height: currentSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFBA68C8), width: 3),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Text("👻", style: TextStyle(fontSize: emojiSize)),
                // Badge showing capture count
                if (_captureCount > 0)
                  Positioned(
                    right: 15,
                    top: 15,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFBA68C8),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_captureCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ... (MyApp class with theme support) ...
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    themeService.addListener(_onThemeChanged);
    TranslationService().addListener(
      _onThemeChanged,
    ); // Rebuild on language change too
  }

  @override
  void dispose() {
    themeService.removeListener(_onThemeChanged);
    TranslationService().removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  // Light Theme
  ThemeData get _lightTheme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: const Color(0xFFBA68C8), // Pastel Purple
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFBA68C8),
          secondary: Color(0xFFF06292), // Pastel Pink
          surface: Colors.white,
          onSurface: Color(0xFF37474F), // Dark Grey Text
        ),
        textTheme:
            GoogleFonts.jetBrainsMonoTextTheme(ThemeData.light().textTheme)
                .apply(
          bodyColor: const Color(0xFF37474F),
          displayColor: const Color(0xFF37474F),
        ),
        useMaterial3: true,
      );

  // Dark Theme
  ThemeData get _darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFFCE93D8), // Light Purple
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFCE93D8),
          secondary: Color(0xFFF48FB1), // Light Pink
          surface: Color(0xFF1E1E1E),
          onSurface: Colors.white,
        ),
        textTheme: GoogleFonts.jetBrainsMonoTextTheme(
          ThemeData.dark().textTheme,
        ).apply(bodyColor: Colors.white, displayColor: Colors.white),
        useMaterial3: true,
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: TranslationService().tr('app_title'),
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: themeService.themeMode,
      home: const ChatScannerHome(),
    );
  }
}

class ChatScannerHome extends StatefulWidget {
  const ChatScannerHome({super.key});

  @override
  State<ChatScannerHome> createState() => _ChatScannerHomeState();
}

class _ChatScannerHomeState extends State<ChatScannerHome>
    with WidgetsBindingObserver {
  // API key is now securely obfuscated via envied package

  final List<File> _images = [];
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _analysisResult;
  String _loadingMessage = "";

  static bool _sessionInstructionsShown =
      false; // Static flag for session strictness
  int _remainingAnalyses =
      RemoteConfigService.dailyAnalysisLimit; // Daily rate limit counter
  bool _isCustomKeyEnabled = false; // Cache custom key status

  final ImagePicker _picker = ImagePicker();

  /// Get translated loading messages dynamically
  List<String> get _loadingMessages => [
        TranslationService().tr('loading_1'),
        TranslationService().tr('loading_2'),
        TranslationService().tr('loading_3'),
        TranslationService().tr('loading_4'),
        TranslationService().tr('loading_5'),
        TranslationService().tr('loading_6'),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToOverlay();
    // Load any existing screenshots on startup
    _loadScreenshotsFromFolder();
    // Load saved preference for instruction dialog
    _loadInstructionPreference();
    // Load remaining analyses counter
    _loadRemainingAnalyses();

    // Listen to language changes
    TranslationService().addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadRemainingAnalyses() async {
    // Check custom key first
    final hasKey = await UserPreferencesService.hasCustomApiKey();
    final isEnabled = await UserPreferencesService.isCustomApiKeyEnabled();

    if (hasKey && isEnabled) {
      if (mounted) {
        setState(() {
          _remainingAnalyses = 999; // Code for unlimited
          _isCustomKeyEnabled = true;
        });
      }
      return;
    }

    final remaining = await AICascadeService.getRemainingAnalyses();
    if (mounted) {
      setState(() {
        _remainingAnalyses = remaining;
        _isCustomKeyEnabled = false;
      });
    }
  }

  Future<void> _loadInstructionPreference() async {
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) return;
      final prefFile = File('${extDir.path}/dont_show_instructions.txt');
      if (await prefFile.exists()) {
        // Preference loaded: do not show instructions
      } else {
        // First launch - show instructions automatically
        // STRICT CHECK: Only if not already shown this session AND no pending work
        // Check if there are screenshots manually to avoid race condition with _loadScreenshotsFromFolder
        bool hasPendingScreenshots = false;
        try {
          final screenshotsDir = Directory('${extDir.path}/screenshots');
          if (await screenshotsDir.exists()) {
            final files = await screenshotsDir.list().toList();
            hasPendingScreenshots =
                files.where((f) => f.path.endsWith('.png')).isNotEmpty;
          }
        } catch (_) {}

        if (!_sessionInstructionsShown && !hasPendingScreenshots && mounted) {
          _sessionInstructionsShown = true;
          // Delay slightly to ensure UI is ready
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            _resetAndShowInstructions();
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading instruction preference: $e");
    }
  }

  Future<void> _saveInstructionPreference() async {
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) return;
      final prefFile = File('${extDir.path}/dont_show_instructions.txt');
      await prefFile.writeAsString('true');
    } catch (e) {
      debugPrint("Error saving instruction preference: $e");
    }
  }

  Future<void> _resetAndShowInstructions() async {
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final prefFile = File('${extDir.path}/dont_show_instructions.txt');
        if (await prefFile.exists()) {
          await prefFile.delete();
        }
      }
      // Preference reset
    } catch (e) {
      debugPrint("Error resetting instruction preference: $e");
    }

    // Show instruction dialog
    if (mounted) {
      bool dontShowAgain = false;
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(TranslationService().tr('dialog_instructions_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${TranslationService().tr('dialog_instructions_how_works')}\n\n"
                  "${TranslationService().tr('dialog_instructions_step_1')}\n"
                  "${TranslationService().tr('dialog_instructions_step_2')}\n"
                  "${TranslationService().tr('dialog_instructions_step_3')}\n\n"
                  "${TranslationService().tr('dialog_instructions_icon_usage')}\n\n"
                  "${TranslationService().tr('dialog_instructions_tap_single')}\n"
                  "${TranslationService().tr('dialog_instructions_tap_double')}\n\n"
                  "${TranslationService().tr('dialog_instructions_drag')}",
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: dontShowAgain,
                      onChanged: (v) =>
                          setDialogState(() => dontShowAgain = v ?? false),
                    ),
                    Text(
                      TranslationService().tr('dialog_instructions_dont_show'),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  if (dontShowAgain) {
                    await _saveInstructionPreference();
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                },
                child: Text(
                  TranslationService().tr('btn_understood'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ============================================================
  // MENU METHODS
  // ============================================================

  /// Build a PopupMenuItem with icon and text
  PopupMenuItem<String> _buildMenuItem(
    String value,
    IconData icon,
    String text, {
    bool isDestructive = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            color: isDestructive ? Colors.red : const Color(0xFFBA68C8),
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: isDestructive
                  ? Colors.red
                  : (ThemeService().isDarkMode ? Colors.white : Colors.black87),
              fontWeight: isDestructive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// Handle menu item selection
  Future<void> _handleMenuSelection(String value) async {
    switch (value) {
      case 'instructions':
        _resetAndShowInstructions();
        break;
      case 'api_key':
        _showApiKeyDialog();
        break;
      case 'privacy':
        _openPrivacyPolicy();
        break;
      case 'contact':
        _openContactEmail();
        break;
      case 'rate':
        _requestAppReview();
        break;
      case 'share':
        _shareApp();
        break;
      case 'dark_mode':
        _showDarkModeDialog();
        break;
      case 'language':
        _showLanguageDialog();
        break;
      case 'credits':
        _showCreditsDialog();
        break;
      case 'version':
        _showVersionDialog();
        break;
      case 'delete_data':
        _showDeleteDataDialog();
        break;
    }
  }

  /// Open Privacy Policy in browser
  Future<void> _openPrivacyPolicy() async {
    final Uri url = Uri.parse(
      'https://doctorloveapp.github.io/chatscanner/privacy.html',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Open email for contact
  Future<void> _openContactEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'doctorloveapp@gmail.com',
      queryParameters: {'subject': 'Doctor Love App - Feedback'},
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  /// Request app review
  Future<void> _requestAppReview() async {
    final InAppReview inAppReview = InAppReview.instance;
    if (await inAppReview.isAvailable()) {
      await inAppReview.requestReview();
    } else {
      // Fallback: open Play Store page
      final Uri url = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.doctorloveapp.chatscanner',
      );
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Share app
  Future<void> _shareApp() async {
    await Share.share(
      TranslationService().tr('share_message').replaceAll('\\n', '\n'),
      subject: 'Doctor Love App',
    );
  }

  /// Show API Key dialog with input and save/remove functionality
  void _showApiKeyDialog() async {
    final hasKey = await UserPreferencesService.hasCustomApiKey();

    if (!mounted) return;

    final TextEditingController controller = TextEditingController(
      text: hasKey ? '••••••••••••••••••••' : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.key, color: Color(0xFFBA68C8)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(TranslationService().tr('dialog_api_title')),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(TranslationService().tr('dialog_api_desc_1')),
                const SizedBox(height: 12),
                Text(
                  TranslationService().tr('dialog_api_desc_2'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: hasKey,
                  decoration: InputDecoration(
                    labelText: hasKey
                        ? TranslationService().tr('api_key_new_optional')
                        : TranslationService().tr('api_key_insert'),
                    hintText: TranslationService().tr('dialog_api_hint'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.vpn_key),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste),
                      tooltip: TranslationService().tr('api_key_paste_tooltip'),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          controller.text = data!.text!;
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // TOGGLE SWITCH FOR CUSTOM API KEY
                if (hasKey)
                  FutureBuilder<bool>(
                    future: UserPreferencesService.isCustomApiKeyEnabled(),
                    builder: (context, snapshot) {
                      final isEnabled = snapshot.data ?? true;
                      return Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              TranslationService().tr('api_key_use_this'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              isEnabled
                                  ? TranslationService().tr('api_key_active')
                                  : TranslationService()
                                      .tr('api_key_disabled_default'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isEnabled ? Colors.green : Colors.grey,
                              ),
                            ),
                            value: isEnabled,
                            activeThumbColor: const Color(0xFFBA68C8),
                            onChanged: (bool value) async {
                              await UserPreferencesService
                                  .setCustomApiKeyEnabled(value);
                              setDialogState(() {}); // Update dialog
                              if (mounted) {
                                _loadRemainingAnalyses(); // Update main UI
                                setState(() {}); // Rebuild main
                              }
                            },
                          ),
                          if (isEnabled) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      TranslationService()
                                          .tr('api_key_active_banner'),
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  )
                else ...[
                  Text(
                    TranslationService().tr('api_key_benefits_title'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    TranslationService().tr('api_key_benefit_1'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    TranslationService().tr('api_key_benefit_2'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    TranslationService().tr('api_key_benefit_3'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TranslationService().tr('api_key_how_to_title'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          TranslationService().tr('api_key_instructions'),
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final url = Uri.parse(
                              'https://aistudio.google.com/apikey',
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.open_in_new,
                                size: 14,
                                color: Color(0xFFBA68C8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                TranslationService().tr('api_key_open_studio'),
                                style: const TextStyle(
                                  color: Color(0xFFBA68C8),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (hasKey)
              TextButton(
                onPressed: () async {
                  // Confirm removal
                  final confirm = await showDialog<bool>(
                    context: ctx,
                    builder: (c) => AlertDialog(
                      title:
                          Text(TranslationService().tr('api_key_remove_title')),
                      content: Text(
                        TranslationService().tr('api_key_remove_desc'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: Text(TranslationService().tr('btn_cancel')),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: Text(
                            TranslationService().tr('btn_remove'),
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await UserPreferencesService.removeCustomApiKey();
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      if (mounted) {
                        await _loadRemainingAnalyses(); // Update UI immediately
                        setState(() {});
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ API Key rimossa'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }
                  }
                },
                child: Text(
                  TranslationService().tr('btn_remove_key'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(TranslationService().tr('btn_cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBA68C8),
              ),
              onPressed: () async {
                final newKey = controller.text.trim();
                if (newKey.isEmpty || newKey.startsWith('••')) {
                  Navigator.pop(ctx);
                  return;
                }

                // Basic validation
                if (!newKey.startsWith('AIzaSy') || newKey.length < 30) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        TranslationService().tr('api_key_invalid_format'),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Save the key
                await UserPreferencesService.setCustomApiKey(newKey);
                // Force enable it
                await UserPreferencesService.setCustomApiKeyEnabled(true);

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }

                if (mounted) {
                  await _loadRemainingAnalyses(); // Logic inside checks mounted
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        TranslationService().tr('api_key_saved_active'),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: Text(
                hasKey
                    ? TranslationService().tr('btn_update')
                    : TranslationService().tr('btn_save'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show dark mode dialog with toggle switch
  void _showDarkModeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.dark_mode, color: Color(0xFFBA68C8)),
              const SizedBox(width: 8),
              Text(TranslationService().tr('theme_dark_title')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: const Color(0xFFBA68C8),
                ),
                title: Text(
                  themeService.isDarkMode
                      ? TranslationService().tr('theme_dark')
                      : TranslationService().tr('theme_light'),
                ),
                subtitle: Text(TranslationService().tr('theme_toggle_hint')),
                trailing: Switch(
                  value: themeService.isDarkMode,
                  activeThumbColor: const Color(0xFFBA68C8),
                  onChanged: (value) async {
                    await themeService.toggleTheme();
                    setDialogState(() {});
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                TranslationService().tr('theme_auto_save'),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(TranslationService().tr('btn_close')),
            ),
          ],
        ),
      ),
    );
  }

  /// Show credits dialog
  void _showCreditsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFBA68C8)),
            const SizedBox(width: 8),
            Flexible(child: Text(TranslationService().tr('menu_credits'))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Doctor Love',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text("${TranslationService().tr('credits_developed_by')}\n"),
              Text(
                TranslationService().tr('credits_tech_used'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Text('• Flutter (Google)'),
              const Text('• Google Gemini AI'),
              const Text('• Groq Llama 4'),
              const Text('• Firebase'),
              const SizedBox(height: 16),
              const Text(
                'Open Source',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              InkWell(
                onTap: () async {
                  final url = Uri.parse(
                    'https://github.com/doctorloveapp/chatscanner',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text(
                  'github.com/doctorloveapp/chatscanner',
                  style: TextStyle(
                    color: Color(0xFFBA68C8),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(TranslationService().tr('btn_close')),
          ),
        ],
      ),
    );
  }

  /// Show version dialog
  Future<void> _showVersionDialog() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Color(0xFFBA68C8)),
            const SizedBox(width: 8),
            Text(TranslationService().tr('version_title')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${TranslationService().tr('version_label')}${packageInfo.version}'),
            Text(
                '${TranslationService().tr('build_label')}${packageInfo.buildNumber}'),
            const SizedBox(height: 8),
            Text(
              TranslationService().tr('version_latest'),
              style: const TextStyle(color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(TranslationService().tr('btn_ok')),
          ),
        ],
      ),
    );
  }

  /// Show language selection dialog
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.language, color: Color(0xFFBA68C8)),
            const SizedBox(width: 8),
            Flexible(child: Text(TranslationService().tr('menu_language'))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text("🇮🇹", style: TextStyle(fontSize: 24)),
              title: const Text("Italiano"),
              trailing: TranslationService().currentLanguage == 'it'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                TranslationService().setLanguage('it');
                Navigator.pop(ctx);
                setState(() {}); // Rebuild UI
              },
            ),
            ListTile(
              leading: const Text("🇺🇸", style: TextStyle(fontSize: 24)),
              title: const Text("English"),
              trailing: TranslationService().currentLanguage == 'en'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                TranslationService().setLanguage('en');
                Navigator.pop(ctx);
                setState(() {}); // Rebuild UI
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Show delete data confirmation dialog
  void _showDeleteDataDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red),
            const SizedBox(width: 8),
            Text(TranslationService().tr('delete_data_title')),
          ],
        ),
        content: Text(TranslationService().tr('dialog_delete_content')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(TranslationService().tr('btn_cancel')),
          ),
          TextButton(
            onPressed: () async {
              await UserPreferencesService.deleteAllData();
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(TranslationService().tr('delete_data_success')),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text(
              TranslationService().tr('btn_delete_all'),
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App is back in foreground - load any new screenshots
      debugPrint("App resumed - loading screenshots from folder");
      _loadScreenshotsFromFolder();
    }
  }

  Future<void> _loadScreenshotsFromFolder() async {
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) return;

      final screenshotsDir = Directory('${extDir.path}/screenshots');
      if (!await screenshotsDir.exists()) {
        debugPrint("Screenshots folder does not exist yet");
        return;
      }

      final files = await screenshotsDir.list().toList();
      final pngFiles = files
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .toList();

      debugPrint("Found ${pngFiles.length} screenshots in folder");

      // Add new files that aren't already in the list
      int newCount = 0;
      for (final file in pngFiles) {
        final alreadyExists = _images.any((img) => img.path == file.path);
        if (!alreadyExists && await file.exists()) {
          _images.add(file);
          newCount++;
        }
      }

      if (newCount > 0) {
        debugPrint("Added $newCount new screenshots");
        setState(() {
          // Reset analysis if we added new images
          if (_analysisResult != null) {
            _analysisResult = null;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "📸 $newCount ${TranslationService().tr('screenshots_new_ready')}",
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error loading screenshots from folder: $e");
    }
  }

  Future<void> _clearAllScreenshots({bool showMessage = true}) async {
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) return;

      final screenshotsDir = Directory('${extDir.path}/screenshots');
      if (await screenshotsDir.exists()) {
        await screenshotsDir.delete(recursive: true);
        debugPrint("Deleted screenshots folder");
      }

      // Reset the overlay counter - create directory if needed
      final commDir = Directory('${extDir.path}/ghost_comm');
      if (!await commDir.exists()) {
        await commDir.create(recursive: true);
      }
      // Create reset file to signal overlay to reset
      final resetFile = File('${commDir.path}/reset_counter');
      await resetFile.writeAsString(
        'reset_${DateTime.now().millisecondsSinceEpoch}',
      );
      debugPrint("Reset counter file created at: ${resetFile.path}");

      setState(() {
        _images.clear();
        _analysisResult = null;
      });

      if (mounted && showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TranslationService().tr('screenshots_deleted')),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error clearing screenshots: $e");
    }
  }

  void _listenToOverlay() {
    // Just listen for overlay close events
    FlutterOverlayWindow.overlayListener.listen((event) async {
      debugPrint("Overlay event received: $event");
      // Screenshots are now loaded from folder when app resumes
    });
  }

  Future<void> _startLiveMode() async {
    debugPrint("--- STARTING LIVE MODE ---");

    // Request MediaProjection permission directly (instructions now only shown at first app launch)
    debugPrint("Requesting MediaProjection permission...");

    try {
      const platform = MethodChannel('device_screenshot');
      await platform.invokeMethod('requestMediaProjection');
      debugPrint("MediaProjection request sent");

      // Wait a moment for user to grant permission
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if service is running
      final bool serviceRunning =
          await platform.invokeMethod('checkMediaProjectionService') ?? false;
      debugPrint("MediaProjection Service Running: $serviceRunning");

      if (!serviceRunning) {
        // Show message and wait for user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "⚠️ Concedi il permesso di registrazione schermo nella finestra popup",
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        // Wait for permission dialog
        await Future.delayed(const Duration(seconds: 3));

        // Check again
        final bool serviceRunning2 =
            await platform.invokeMethod('checkMediaProjectionService') ?? false;
        if (!serviceRunning2) {
          setState(() {
            _error =
                "Permesso registrazione schermo necessario per catturare screenshot!";
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("Error requesting MediaProjection: $e");
      setState(() {
        _error = "Errore richiesta permesso registrazione: $e";
      });
      return;
    }

    // Then check overlay permission
    final bool status = await FlutterOverlayWindow.isPermissionGranted();
    debugPrint("Overlay Permission Granted: $status");
    if (!status) {
      debugPrint("Requesting Overlay Permission...");
      final bool? granted = await FlutterOverlayWindow.requestPermission();
      debugPrint("Overlay Permission Result: $granted");
      if (granted != true) {
        setState(() {
          _error =
              "Permesso 'Mostra sopra altre app' necessario per lo Scanner!";
        });
        return;
      }
    }

    final bool isActive = await FlutterOverlayWindow.isActive();
    debugPrint("Is Overlay Active: $isActive");
    if (isActive) {
      debugPrint("Overlay is already active. Closing it first.");
      await FlutterOverlayWindow.closeOverlay();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    debugPrint("Showing Overlay...");
    try {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "Doctor Love",
        overlayContent: "Tap = screenshot, Doppio tap = torna all'app",
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilitySecret,
        positionGravity: PositionGravity.auto,
        height: 200,
        width: 200,
        startPosition: const OverlayPosition(
          0,
          200,
        ), // Start below status bar area
      );
      debugPrint("Overlay Show Command Sent.");

      // Send app to background so user can use other apps
      await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      debugPrint("App sent to background.");
    } catch (e) {
      debugPrint("Error showing overlay: $e");
      setState(() {
        _error = "Errore avvio overlay: $e";
      });
      return;
    }
  }

  Future<void> _showAddScreenshotsOptions() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("📸 Aggiungi Screenshot"),
        content: const Text("Come vuoi aggiungere altri screenshot?"),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _startLiveMode();
            },
            icon: const Icon(
              Icons.emergency_recording,
              color: Color(0xFFF06292),
            ),
            label: const Text(
              "SCANNER LIVE 👻",
              style: TextStyle(
                color: Color(0xFFF06292),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _pickImages();
            },
            icon: const Icon(Icons.folder_open, color: Color(0xFFBA68C8)),
            label: const Text(
              "DA DISPOSITIVO",
              style: TextStyle(
                color: Color(0xFFBA68C8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _images.addAll(pickedFiles.map((f) => File(f.path)));
          _error = null;
          if (_analysisResult != null) {
            _analysisResult = null;
            _analyzeImages();
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = "Errore selezione immagini: $e";
      });
    }
  }

  Future<void> _analyzeImages() async {
    if (_images.isEmpty) return;

    // Check rate limit first
    // Check custom key first
    final hasKey = await UserPreferencesService.hasCustomApiKey();
    final isEnabled = await UserPreferencesService.isCustomApiKeyEnabled();

    // Only check rate limit if NOT using custom key
    if (!hasKey || !isEnabled) {
      final remaining = await AICascadeService.getRemainingAnalyses();
      if (remaining <= 0) {
        if (mounted) {
          setState(() {
            _remainingAnalyses = 0;
            _error =
                '⏰ Hai esaurito le ${RemoteConfigService.dailyAnalysisLimit} analisi giornaliere!\n\n🌙 Il contatore si resetterà a mezzanotte.\nTorna domani per altre ${RemoteConfigService.dailyAnalysisLimit} analisi gratuite! 💕';
          });
        }
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = _loadingMessages[0];
      _error = null;
    });

    _cycleLoadingMessages();

    try {
      final List<Uint8List> imageBytesList = [];
      for (var img in _images) {
        imageBytesList.add(await img.readAsBytes());
      }

      final result = await AICascadeService.analyzeImages(imageBytesList);

      // Refresh remaining analyses counter
      await _loadRemainingAnalyses();

      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isLoading = false;
        });

        // Check for fallback flag
        if (result.containsKey('__custom_key_fallback__')) {
          _showCustomKeyFallbackDialog();
        }
      }
    } catch (e) {
      // Refresh remaining analyses counter even on error
      await _loadRemainingAnalyses();

      if (mounted) {
        setState(() {
          _error = AICascadeService.parseError(e);
          _isLoading = false;
        });
      }
    }
  }

  void _cycleLoadingMessages() async {
    int index = 0;
    while (_isLoading) {
      await Future.delayed(const Duration(seconds: 2));
      if (!_isLoading) break;
      setState(() {
        index = (index + 1) % _loadingMessages.length;
        _loadingMessage = _loadingMessages[index];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeService.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "DOCTOR LOVE",
          style: GoogleFonts.orbitron(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            shadows: [
              // Pink outline effect using multiple shadows
              Shadow(
                offset: const Offset(-1, -1),
                color:
                    isDark ? const Color(0xFFCE93D8) : const Color(0xFFF06292),
                blurRadius: 0,
              ),
              Shadow(
                offset: const Offset(1, -1),
                color:
                    isDark ? const Color(0xFFCE93D8) : const Color(0xFFF06292),
                blurRadius: 0,
              ),
              Shadow(
                offset: const Offset(-1, 1),
                color:
                    isDark ? const Color(0xFFCE93D8) : const Color(0xFFF06292),
                blurRadius: 0,
              ),
              Shadow(
                offset: const Offset(1, 1),
                color:
                    isDark ? const Color(0xFFCE93D8) : const Color(0xFFF06292),
                blurRadius: 0,
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.menu, color: Colors.white.withValues(alpha: 0.9)),
            tooltip: 'Menu',
            color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: _handleMenuSelection,
            itemBuilder: (context) => [
              _buildMenuItem(
                'instructions',
                Icons.help_outline,
                TranslationService().tr('menu_instructions'),
              ),
              _buildMenuItem(
                'api_key',
                Icons.key,
                TranslationService().tr('menu_api_key'),
              ),
              const PopupMenuDivider(),
              _buildMenuItem(
                'privacy',
                Icons.privacy_tip_outlined,
                TranslationService().tr('menu_privacy'),
              ),
              _buildMenuItem(
                'contact',
                Icons.email_outlined,
                TranslationService().tr('menu_contact'),
              ),
              _buildMenuItem(
                'rate',
                Icons.star_outline,
                TranslationService().tr('menu_rate'),
              ),
              _buildMenuItem(
                'share',
                Icons.share_outlined,
                TranslationService().tr('menu_share'),
              ),
              const PopupMenuDivider(),
              _buildMenuItem(
                'dark_mode',
                Icons.dark_mode_outlined,
                TranslationService().tr('menu_dark_mode'),
              ),
              _buildMenuItem(
                'language',
                Icons.language,
                TranslationService().tr('menu_language'),
              ),
              _buildMenuItem(
                'credits',
                Icons.info_outline,
                TranslationService().tr('menu_credits'),
              ),
              _buildMenuItem(
                'version',
                Icons.system_update_outlined,
                TranslationService().tr('menu_version'),
              ),
              const PopupMenuDivider(),
              _buildMenuItem(
                'delete_data',
                Icons.delete_forever_outlined,
                TranslationService().tr('menu_delete_data'),
                isDestructive: true,
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background gradient + hearts pattern
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        const Color(0xFF1A1A2E), // Dark blue-purple
                        const Color(0xFF16213E), // Darker blue
                        const Color(0xFF4A0E4E), // Dark purple
                      ]
                    : [
                        Colors.white,
                        const Color(0xFFFFD1DC), // Pink light
                        const Color(0xFFE040FB), // Neon pink/violet
                      ],
                stops: const [0.0, 0.15, 1.0],
              ),
            ),
          ),
          // Hearts pattern overlay
          Opacity(
            opacity: 0.08,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/icon.png'),
                  repeat: ImageRepeat.repeat,
                  scale: 8,
                  colorFilter: ColorFilter.mode(
                    Colors.white.withValues(alpha: 0.3),
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
          // Main scrollable content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                children: [
                  // Subtitle
                  Text(
                    TranslationService().tr('subtitle_desc'),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 30),

                  // Pulsing heart counter
                  GestureDetector(
                    onTap: _showCounterExplanation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.2),
                            Colors.white.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFE040FB,
                            ).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _remainingAnalyses > 0
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 32,
                                color: _remainingAnalyses > 3
                                    ? Colors.white
                                    : _remainingAnalyses > 0
                                        ? const Color(0xFFFFAB40)
                                        : const Color(0xFFFF5252),
                              )
                                  .animate(
                                    onPlay: (c) => c.repeat(reverse: true),
                                  )
                                  .scale(
                                    begin: const Offset(1, 1),
                                    end: const Offset(1.2, 1.2),
                                    duration: 800.ms,
                                  ),
                              const SizedBox(width: 12),
                              Text(
                                _remainingAnalyses == 999
                                    ? "∞"
                                    : "$_remainingAnalyses/${RemoteConfigService.dailyAnalysisLimit}",
                                style: GoogleFonts.orbitron(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _remainingAnalyses == 999
                                ? "MODALITÀ ILLIMITATA 💎"
                                : _remainingAnalyses >=
                                        RemoteConfigService.dailyAnalysisLimit
                                    ? TranslationService().tr(
                                        'main_today_limit_reached',
                                      )
                                    : _remainingAnalyses > 0
                                        ? TranslationService().tr(
                                            'main_analysis_remaining',
                                          )
                                        : TranslationService().tr(
                                            'main_come_back_tomorrow',
                                          ),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Error message if present
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  if (_analysisResult == null && !_isLoading) ...[
                    // Live Scanner Button with neon glow (CIRCULAR shadow only)
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFE040FB,
                            ).withValues(alpha: 0.5),
                            blurRadius: 25,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _startLiveMode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                          elevation: 0,
                        ),
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFE040FB),
                                Color(0xFFBA68C8),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFE040FB,
                                ).withValues(alpha: 0.6),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: const Color(
                                  0xFFE040FB,
                                ).withValues(alpha: 0.3),
                                blurRadius: 40,
                                spreadRadius: 5,
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                TranslationService().tr('btn_scanner_usa'),
                                style: GoogleFonts.orbitron(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                TranslationService().tr('btn_scanner_live'),
                                style: GoogleFonts.orbitron(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                TranslationService().tr(
                                  'btn_scanner_live_text',
                                ),
                                style: GoogleFonts.orbitron(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                "👻",
                                style: TextStyle(fontSize: 22),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.05, 1.05),
                          duration: 1500.ms,
                        )
                        .then()
                        .shimmer(
                          duration: 2.seconds,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),

                    const SizedBox(height: 40),

                    // Upload area (RECTANGULAR, NO ANIMATION)
                    if (_images.isEmpty)
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.8,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.15),
                                Colors.white.withValues(alpha: 0.05),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 32,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                TranslationService().tr('btn_upload_chat'),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      _buildImagePreviewList(),

                    const SizedBox(height: 20),

                    // Clear screenshots button
                    if (_images.isNotEmpty)
                      TextButton.icon(
                        onPressed: _clearAllScreenshots,
                        icon: Icon(
                          Icons.delete_sweep,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        label: Text(
                          TranslationService().tr('btn_clear_all'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    if (_images.isNotEmpty) _buildAnalyzeButton(),
                  ] else if (_isLoading) ...[
                    const SizedBox(height: 100),
                    _buildLoadingView(),
                  ] else if (_analysisResult != null) ...[
                    _buildResultsView(),
                  ],

                  const SizedBox(height: 10),

                  // Footer
                  Column(
                    children: [
                      Text(
                        _isCustomKeyEnabled
                            ? TranslationService().tr('unlimited_mode')
                            : "${TranslationService().tr('instant_analysis')} · ${TranslationService().tr('daily_limit_subtitle')}",
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        TranslationService().tr('anonymous_100'),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCounterExplanation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.favorite, color: Color(0xFFBA68C8)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                TranslationService().tr('daily_limit_title'),
                style: GoogleFonts.orbitron(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          TranslationService().tr('daily_limit_explanation').replaceAll(
              '{limit}', '${RemoteConfigService.dailyAnalysisLimit}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(TranslationService().tr('btn_got_it_normal')),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreviewList() {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _images.length + 1,
            itemBuilder: (context, index) {
              if (index == _images.length) {
                return GestureDetector(
                  onTap: _showAddScreenshotsOptions,
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add,
                        color: Color(0xFFBA68C8),
                        size: 40,
                      ),
                    ),
                  ),
                );
              }
              return Container(
                width: 150,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFBA68C8).withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _images[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _images.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Color(0xFFBA68C8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "${_images.length} SCREENSHOT${_images.length > 1 ? 'S' : ''}",
          style: GoogleFonts.orbitron(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton() {
    return Column(
      children: [
        // DEBUG MODE: Model selector dropdown
        if (AICascadeService.debugModeEnabled) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Text(
                  '🔧 DEBUG MODE',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButton<DebugModelChoice>(
                  value: AICascadeService.selectedModel,
                  dropdownColor: const Color(0xFF2D2D2D),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                  underline: Container(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.orange),
                  items: DebugModelChoice.values.map((model) {
                    return DropdownMenuItem<DebugModelChoice>(
                      value: model,
                      child: Text(model.displayName),
                    );
                  }).toList(),
                  onChanged: (model) {
                    if (model != null) {
                      setState(() {
                        AICascadeService.selectedModel = model;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Main analyze button with glow
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE040FB).withValues(alpha: 0.5),
                blurRadius: 25,
                spreadRadius: 3,
              ),
              BoxShadow(
                color: const Color(0xFFBA68C8).withValues(alpha: 0.3),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _analyzeImages,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(
                0xFFE040FB,
              ), // Brighter purple-pink
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 50,
                vertical: 20,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: Text(
              TranslationService().tr('btn_analyze'),
              style: GoogleFonts.orbitron(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.03, 1.03),
              duration: 1200.ms,
            )
            .then()
            .shimmer(
              duration: 2.seconds,
              color: Colors.white.withValues(alpha: 0.4),
            ),
      ],
    );
  }

  void _showCustomKeyFallbackDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(TranslationService().tr('fallback_title')),
        content: Text(TranslationService().tr('fallback_content')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(TranslationService().tr('fallback_keep_active')),
          ),
          ElevatedButton(
            onPressed: () async {
              await UserPreferencesService.setCustomApiKeyEnabled(false);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                _loadRemainingAnalyses();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        TranslationService().tr('fallback_disabled_success')),
                  ),
                );
              }
            },
            child: Text(TranslationService().tr('fallback_disable_key')),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Column(
      children: [
        Animate(
          onPlay: (controller) => controller.repeat(),
          effects: [RotateEffect(duration: 2.seconds, curve: Curves.easeInOut)],
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 4,
              ),
            ),
            child: const Center(
              child: Icon(Icons.radar, size: 50, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 30),
        Text(
          _loadingMessage,
          style: GoogleFonts.jetBrainsMono(fontSize: 16, color: Colors.white),
          textAlign: TextAlign.center,
        ).animate().fadeIn().shimmer(
              duration: 2.seconds,
              color: Colors.white.withValues(alpha: 0.5),
            ),
      ],
    );
  }

  Widget _buildResultsView() {
    final score = _analysisResult!['score'] as int;
    final isGood = score >= 50;
    // Pastel Green (Mint) for good, Pastel Red (Coral) for bad
    final color = isGood ? const Color(0xFF81C784) : const Color(0xFFE57373);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Score Circle
        Center(
          child: Container(
            width: 180, // Increased size
            height: 180, // Increased size
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: color, width: 6),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    // Ensures text scales down if needed
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        "$score/100",
                        style: GoogleFonts.orbitron(
                          fontSize: 40, // Slightly reduced base size
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    TranslationService().tr('result_interest'),
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      color: color.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
        ),
        const SizedBox(height: 30),

        // Analysis
        _buildSectionTitle(
            TranslationService().tr('result_verdict'), Colors.white),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            _analysisResult!['analysis'],
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              height: 1.5,
              color: const Color(0xFF37474F),
            ),
          ),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 20),

        // Line Ratings
        if (_analysisResult!['line_rating'] != null) ...[
          _buildSectionTitle(
              TranslationService().tr('result_line_analysis'), Colors.white),
          ...(_analysisResult!['line_rating'] as List).map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4DD0E1).withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '"${item['text']}"',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF546E7A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F7FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${item['rating']}/10",
                      style: GoogleFonts.orbitron(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00BCD4),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
        ],

        // Next Move
        _buildSectionTitle(
            TranslationService().tr('result_next_move'), Colors.white),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            border: Border.all(color: const Color(0xFFFFB74D)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                _analysisResult!['next_move'],
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFEF6C00),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: _analysisResult!['next_move']),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(TranslationService()
                            .tr('result_copied_clipboard'))),
                  );
                },
                icon: const Icon(Icons.copy, color: Colors.white),
                label: Text(
                  TranslationService().tr('btn_copy'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB74D),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),

        const SizedBox(height: 40),

        // Add more screenshots button - now shows options
        OutlinedButton.icon(
          onPressed: _showAddScreenshotsOptions,
          icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
          label: Text(
            TranslationService().tr('btn_add_more_screens'),
            style: const TextStyle(color: Colors.white),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        const SizedBox(height: 20),

        Center(
          child: TextButton(
            onPressed: () async {
              await _clearAllScreenshots(showMessage: false);
            },
            child: Text(
              TranslationService().tr('btn_analyze_another'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.orbitron(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
