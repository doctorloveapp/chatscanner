import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

// Entry point for the overlay
@pragma("vm:entry-point")
void overlayMain() {
  debugPrint("--- OVERLAY ENTRY POINT CALLED ---");
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GhostOverlay(),
  ));
}

class GhostOverlay extends StatefulWidget {
  const GhostOverlay({super.key});

  @override
  State<GhostOverlay> createState() => _GhostOverlayState();
}

class _GhostOverlayState extends State<GhostOverlay> {
  bool _isCapturing = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: GestureDetector(
          onTap: () async {
            debugPrint("Overlay Tapped");
            // Trigger screenshot in main app
            setState(() {
              _isCapturing = true;
            });
            await FlutterOverlayWindow.shareData("capture");
            await Future.delayed(const Duration(milliseconds: 500));
            setState(() {
              _isCapturing = false;
            });
          },
          onDoubleTap: () async {
            // Open main app
            await FlutterOverlayWindow.shareData("open");
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.9),
              border: Border.all(
                  color: const Color(0xFFBA68C8), width: 4), // Pastel Purple
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFBA68C8).withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _isCapturing
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFBA68C8),
                      strokeWidth: 3,
                    ),
                  )
                : const Center(
                    child: Text(
                      "👻",
                      style: TextStyle(fontSize: 40),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
