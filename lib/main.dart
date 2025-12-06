import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:path_provider/path_provider.dart';

void main() {
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
      await requestFile
          .writeAsString('capture_${DateTime.now().millisecondsSinceEpoch}');
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
        "Overlay: Capture complete, ready for next tap. Total: $_captureCount");
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
              border: Border.all(
                color: const Color(0xFFBA68C8),
                width: 3,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Text(
                  "👻",
                  style: TextStyle(fontSize: emojiSize),
                ),
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

// ... (MyApp class remains the same) ...
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doctor Love',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: const Color(0xFFBA68C8), // Pastel Purple
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFBA68C8),
          secondary: Color(0xFFF06292), // Pastel Pink
          surface: Colors.white,
          onSurface: Color(0xFF37474F), // Dark Grey Text
        ),
        textTheme: GoogleFonts.jetBrainsMonoTextTheme(
          ThemeData.light().textTheme,
        ).apply(
          bodyColor: const Color(0xFF37474F),
          displayColor: const Color(0xFF37474F),
        ),
        useMaterial3: true,
      ),
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
  static const String _apiKey = 'AIzaSyAhA7Ny4V-QUlNhvJNEgcSEviN8VXOtBPE';

  final List<File> _images = [];
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _analysisResult;
  String _loadingMessage = "Inizializzazione...";
  bool _dontShowInstructionAgain = false;

  final ImagePicker _picker = ImagePicker();

  final List<String> _loadingMessages = [
    "Analisi pattern comunicativi...",
    "Elaborazione tempi di risposta...",
    "Valutazione coinvolgimento emotivo...",
    "Calcolo indice di interesse...",
    "Analisi linguaggio non verbale...",
    "Elaborazione risultati finali...",
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
  }

  Future<void> _loadInstructionPreference() async {
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) return;
      final prefFile = File('${extDir.path}/dont_show_instructions.txt');
      if (await prefFile.exists()) {
        _dontShowInstructionAgain = true;
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
      _dontShowInstructionAgain = true;
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
      _dontShowInstructionAgain = false;
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
            title: const Text("📱 Istruzioni"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "CONFIGURAZIONE INIZIALE\n\n"
                  "Nella schermata di autorizzazione:\n"
                  "1. Clicca sulla freccia del menu\n"
                  "2. Seleziona 'Schermo intero'\n"
                  "3. Premi 'Avvia ora'\n\n"
                  "COME USARE L'ICONA 👻\n\n"
                  "• Tap singolo → Cattura screenshot\n"
                  "• Doppio tap → Torna all'app\n\n"
                  "Trascina l'icona dove preferisci!",
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: dontShowAgain,
                      onChanged: (v) =>
                          setDialogState(() => dontShowAgain = v ?? false),
                    ),
                    const Text("Non mostrare più"),
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
                child: const Text("HO CAPITO",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }
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
              content:
                  Text("📸 $newCount nuovi screenshot pronti per l'analisi!"),
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
      await resetFile
          .writeAsString('reset_${DateTime.now().millisecondsSinceEpoch}');
      debugPrint("Reset counter file created at: ${resetFile.path}");

      setState(() {
        _images.clear();
        _analysisResult = null;
      });

      if (mounted && showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🗑️ Tutti gli screenshot sono stati eliminati"),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
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

    // First, request MediaProjection permission
    debugPrint("Requesting MediaProjection permission...");

    // Show instruction dialog BEFORE MediaProjection request (unless user said don't show)
    if (mounted && !_dontShowInstructionAgain) {
      bool dontShowAgain = false;
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text("📱 Istruzioni"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "CONFIGURAZIONE INIZIALE\n\n"
                  "Nella schermata di autorizzazione:\n"
                  "1. Clicca sulla freccia del menu\n"
                  "2. Seleziona 'Schermo intero'\n"
                  "3. Premi 'Avvia ora'\n\n"
                  "COME USARE L'ICONA 👻\n\n"
                  "• Tap singolo → Cattura screenshot\n"
                  "• Doppio tap → Torna all'app\n\n"
                  "Trascina l'icona dove preferisci!",
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: dontShowAgain,
                      onChanged: (v) =>
                          setDialogState(() => dontShowAgain = v ?? false),
                    ),
                    const Text("Non mostrare più"),
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
                child: const Text("HO CAPITO",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

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
                  "⚠️ Concedi il permesso di registrazione schermo nella finestra popup"),
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
        startPosition: const OverlayPosition(0, 200), // Start below status bar area
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
            icon:
                const Icon(Icons.emergency_recording, color: Color(0xFFF06292)),
            label: const Text("SCANNER LIVE 👻",
                style: TextStyle(
                    color: Color(0xFFF06292), fontWeight: FontWeight.bold)),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _pickImages();
            },
            icon: const Icon(Icons.folder_open, color: Color(0xFFBA68C8)),
            label: const Text("DA DISPOSITIVO",
                style: TextStyle(
                    color: Color(0xFFBA68C8), fontWeight: FontWeight.bold)),
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
    if (_apiKey == 'YOUR_API_KEY_HERE') {
      setState(() {
        _error = "Inserisci la tua API Key in main.dart";
      });
      return;
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

      final result = await _callGeminiWithFallback(imageBytesList);

      setState(() {
        _analysisResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Analisi fallita: $e";
        _isLoading = false;
      });
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

  Future<Map<String, dynamic>> _callGeminiWithFallback(
      List<Uint8List> imageBytesList) async {
    try {
      debugPrint(
          "--- GEMINI LOG: Tentativo con modello PRIMARIO (gemini-2.5-pro) ---");
      return await _callGemini(imageBytesList, 'gemini-2.5-pro');
    } catch (e) {
      debugPrint("--- GEMINI LOG: gemini-2.5-pro FALLITO. Errore: $e ---");
      debugPrint(
          "--- GEMINI LOG: Tentativo con modello FALLBACK (gemini-1.5-pro) ---");
      return await _callGemini(imageBytesList, 'gemini-1.5-pro');
    }
  }

  Future<Map<String, dynamic>> _callGemini(
      List<Uint8List> imageBytesList, String modelName) async {
    debugPrint("--- GEMINI LOG: Inizio richiesta a $modelName ---");
    final model = GenerativeModel(
      model: modelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
      systemInstruction: Content.system(
          "Sei un Dating Coach di classe mondiale ed esperto di Teoria dei Giochi. Analizza visivamente questi screenshot di chat (potrebbero essere più di uno, in sequenza). "
          "Guarda i timestamp, la lunghezza dei messaggi e l'uso delle emoji attraverso tutta la conversazione. "
          "Restituisci SOLO un oggetto JSON grezzo (nessuna formattazione markdown) con questo schema: "
          "{ "
          "'score': (int 0-100 che rappresenta il livello di interesse), "
          "'analysis': (string, un'analisi breve, spiritosa e leggermente pungente in ITALIANO), "
          "'line_rating': [{'text': 'frase dalla chat', 'rating': (int 1-10)}], "
          "'next_move': (string, IL CONSIGLIO D'ORO. Scrivi l'esatto messaggio di testo che l'utente dovrebbe inviare in questo momento per massimizzare l'impatto, in ITALIANO) "
          "}"),
    );

    final List<Part> parts = [TextPart("Analyze these chat screenshots.")];
    for (var bytes in imageBytesList) {
      parts.add(DataPart('image/jpeg', bytes));
    }

    final content = [Content.multi(parts)];

    final response = await model.generateContent(content);
    final text = response.text;

    debugPrint("--- GEMINI LOG: Risposta ricevuta da $modelName ---");

    if (text == null) throw Exception("Empty response from Gemini");

    final cleanText =
        text.replaceAll('```json', '').replaceAll('```', '').trim();

    return jsonDecode(cleanText) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("DOCTOR LOVE"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.orbitron(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFBA68C8), // Pastel Purple
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFFBA68C8)),
            tooltip: 'Mostra istruzioni',
            onPressed: _resetAndShowInstructions,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF3E5F5), // Lavender
              Colors.white,
              Color(0xFFFCE4EC), // Light Pink
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
          child: Column(
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xFFE57373)), // Pastel Red
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFFFEBEE),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFC62828)),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_analysisResult == null && !_isLoading) ...[
                const SizedBox(height: 20),

                // Live Mode Button
                ElevatedButton.icon(
                  onPressed: _startLiveMode,
                  icon: const Icon(Icons.emergency_recording,
                      color: Colors.white),
                  label: const Text("ATTIVA SCANNER LIVE 👻",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF06292), // Pink
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ).animate().shimmer(duration: 3.seconds),

                const SizedBox(height: 30),

                if (_images.isEmpty)
                  _buildUploadButton()
                else
                  _buildImagePreviewList(),

                const SizedBox(height: 20),

                // Clear screenshots button
                if (_images.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearAllScreenshots,
                    icon: const Icon(Icons.delete_sweep, color: Colors.red),
                    label: const Text(
                      "Cancella tutti gli screenshot",
                      style: TextStyle(color: Colors.red),
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
            ],
          ),
        ),
      ),
    );
  }

  // ... (Rest of the widgets remain the same) ...
  Widget _buildUploadButton() {
    return GestureDetector(
      onTap: _pickImages,
      child: Animate(
        onPlay: (controller) => controller.repeat(reverse: true),
        effects: [
          BoxShadowEffect(
            begin: BoxShadow(
              color: const Color(0xFFBA68C8).withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 0,
            ),
            end: BoxShadow(
              color: const Color(0xFFBA68C8).withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
            duration: 1500.ms,
          ),
          ScaleEffect(
            begin: const Offset(1, 1),
            end: const Offset(1.05, 1.05),
            duration: 1500.ms,
          ),
        ],
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFFBA68C8), width: 4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFBA68C8).withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.upload_file, size: 50, color: Color(0xFFBA68C8)),
              const SizedBox(height: 10),
              Text(
                "UPLOAD\nCHAT",
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFBA68C8),
                ),
              ),
            ],
          ),
        ),
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
                      child:
                          Icon(Icons.add, color: Color(0xFFBA68C8), size: 40),
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
                      color: const Color(0xFFBA68C8).withValues(alpha: 0.3)),
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
                      child: Image.file(_images[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity),
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
                          child: const Icon(Icons.close,
                              size: 16, color: Color(0xFFBA68C8)),
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
          style: GoogleFonts.orbitron(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton() {
    return ElevatedButton(
      onPressed: _analyzeImages,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFBA68C8), // Pastel Purple
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 5,
        shadowColor: const Color(0xFFBA68C8).withValues(alpha: 0.4),
      ),
      child: Text(
        "ANALIZZA ORA",
        style: GoogleFonts.orbitron(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    ).animate().shimmer(
        duration: 2.seconds, color: Colors.white.withValues(alpha: 0.5));
  }

  Widget _buildLoadingView() {
    return Column(
      children: [
        Animate(
          onPlay: (controller) => controller.repeat(),
          effects: [
            RotateEffect(duration: 2.seconds, curve: Curves.easeInOut),
          ],
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFBA68C8).withValues(alpha: 0.5),
                width: 4,
              ),
            ),
            child: const Center(
              child: Icon(Icons.radar, size: 50, color: Color(0xFFBA68C8)),
            ),
          ),
        ),
        const SizedBox(height: 30),
        Text(
          _loadingMessage,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 16,
            color: const Color(0xFFBA68C8),
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn()
            .shimmer(duration: 2.seconds, color: const Color(0xFFBA68C8)),
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
                    "INTEREST",
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
        _buildSectionTitle("VERDETTO", color),
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
          _buildSectionTitle("ANALISI FRASI", const Color(0xFF4DD0E1)), // Cyan
          ...(_analysisResult!['line_rating'] as List).map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF4DD0E1).withValues(alpha: 0.2)),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        _buildSectionTitle("PROSSIMA MOSSA", const Color(0xFFFFB74D)), // Orange
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
                      ClipboardData(text: _analysisResult!['next_move']));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Copiato negli appunti!")),
                  );
                },
                icon: const Icon(Icons.copy, color: Colors.white),
                label: const Text("COPIA",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
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
          icon: const Icon(Icons.add_photo_alternate, color: Color(0xFFBA68C8)),
          label: const Text("AGGIUNGI ALTRI SCREEN",
              style: TextStyle(color: Color(0xFFBA68C8))),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFBA68C8)),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 20),

        Center(
          child: TextButton(
            onPressed: () async {
              await _clearAllScreenshots(showMessage: false);
            },
            child: const Text("ANALIZZA UN'ALTRA CHAT",
                style: TextStyle(color: Colors.grey)),
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
