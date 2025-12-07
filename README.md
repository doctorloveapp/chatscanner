# Doctor Love 💕

<p align="center">
  <img src="assets/icon.png" alt="Doctor Love Logo" width="120" height="120">
</p>

<p align="center">
  <strong>AI-Powered Chat Interest Analyzer</strong><br>
  Analyze your chat screenshots and get AI-driven insights about interest levels
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-3.1.8-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/platform-Android-green.svg" alt="Platform">
  <img src="https://img.shields.io/badge/Flutter-3.2+-02569B.svg?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/license-MIT-orange.svg" alt="License">
</p>

---

## 📖 Overview

**Doctor Love** is a Flutter application that leverages Google Gemini AI to analyze chat screenshots and evaluate interest levels. The app provides a score (0-100), phrase-by-phrase analysis, and actionable suggestions for your next message.

### Key Features

- 🔴 **Live Scanner Mode** - Floating overlay to capture screenshots from any app
- 🤖 **Multi-AI Cascade** - Gemini 2.5 Pro → Gemini 2.5 Flash → Groq Llama 4 Scout → Groq Llama 4 Maverick
- 📊 **Interest Score** - Get a 0-100 rating of conversation engagement
- 💬 **Phrase Rating** - Individual analysis of key messages
- 🎯 **Next Move Suggestion** - AI-generated response recommendations
- 🔄 **Smart Retry** - 3 attempts per model with exponential backoff
- 📅 **Daily Rate Limit** - 5 analyses per day (resets at midnight)
- 🖼️ **Unlimited Screenshots** - Auto-merges images to bypass API limits

---

## 📱 Screenshots

| Home Screen | Live Scanner | Analysis Results |
|:-----------:|:------------:|:----------------:|
| Upload or scan | Floating overlay | AI-powered insights |

---

## 🤖 AI Cascade System (v3.2.0)

The app uses a **4-tier AI fallback system** for maximum reliability:

| Priority | Model | Provider | Notes |
|:--------:|-------|----------|-------|
| 1️⃣ | Gemini 2.5 Pro | Google AI | Best quality, limited quota |
| 2️⃣ | Gemini 2.5 Flash | Google AI | Faster, higher quota |
| 3️⃣ | Llama 4 Scout 17B | Groq | Fast, free tier (500k tokens/day) |
| 4️⃣ | Llama 4 Maverick 17B | Groq | High quality, free tier |

**How it works:**

- Each model gets 3 retry attempts with exponential backoff (2s → 4s → 8s)
- If all 3 attempts fail, automatically falls back to the next model
- Users never notice the switch - completely transparent

**Image Merging:**

- Groq supports max 5 images per request
- If you upload 6+ screenshots, they're automatically stitched vertically
- Example: 15 screenshots → 5 composite images (3 screenshots each)

**Rate Limiting:**

- Daily limit: **5 analyses** (resets at midnight)
- Visual counter in AppBar: ❤️ X/5
- Color changes: 💜 Purple (4-5) → 🧡 Orange (1-3) → ❤️ Red (0)

**Android 14+ Optimization:**

- Uses `MediaProjectionConfig.createConfigForDefaultDisplay()`
- Reduces repeated screen capture permission prompts

---

## 🏗️ Architecture

The application implements a sophisticated architecture to handle screen capture from a floating overlay, solving the challenge of cross-process communication in Flutter.

### System Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                    DOCTOR LOVE ARCHITECTURE                      │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐         ┌────────────────────────────┐    │
│  │  Flutter Overlay  │         │  MediaProjectionService    │    │
│  │  (Isolated VM)    │         │  (Foreground Service)      │    │
│  └─────────┬────────┘         └─────────────┬──────────────┘    │
│            │                                 │                   │
│            │  1. Write request file          │  2. Poll (100ms)  │
│            ▼                                 ▼                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    ghost_comm/                            │   │
│  │  ├── capture_request   (trigger capture)                 │   │
│  │  ├── capture_result    (success:/path or error:msg)      │   │
│  │  └── reset_counter     (reset overlay badge)             │   │
│  └──────────────────────────────────────────────────────────┘   │
│            │                                 │                   │
│            │  4. Read result                 │  3. Capture &     │
│            │     (poll 100ms)                │     write result  │
│            ▼                                 ▼                   │
│  ┌──────────────────┐         ┌────────────────────────────┐    │
│  │  Update badge     │         │  Screenshot saved to       │    │
│  │  counter          │         │  screenshots/*.png         │    │
│  └──────────────────┘         └────────────────────────────┘    │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Core Components

| Component | Location | Description |
|-----------|----------|-------------|
| `main.dart` | `lib/` | Main app entry point and overlay widget |
| `MediaProjectionService.kt` | `packages/device_screenshot/` | Native Android foreground service for screen capture |
| `DeviceScreenshotPlugin.kt` | `packages/device_screenshot/` | Flutter-Android bridge via MethodChannel |

### Key Implementation Details

#### Overlay Entry Point

```dart
@pragma("vm:entry-point")
void overlayMain() {
  runApp(const MaterialApp(
    home: ScannerOverlayWidget(),
  ));
}
```

#### File-Based Communication

The overlay runs in an isolated Flutter VM, making MethodChannel communication impossible. The solution uses file-based IPC:

- **Request**: Overlay writes to `ghost_comm/capture_request`
- **Response**: Native service writes to `ghost_comm/capture_result`
- **Reset**: Main app writes to `ghost_comm/reset_counter`

---

## 📋 Requirements

### Minimum Requirements

- Android 8.0 (API level 26) or higher
- Flutter SDK 3.2.0 or higher
- Dart SDK 3.2.0 or higher

### Permissions Required

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />
```

---

## 🚀 Getting Started

### Prerequisites

1. Install [Flutter](https://flutter.dev/docs/get-started/install) (3.2.0+)
2. Set up an Android device or emulator (API 26+)
3. For developers: Configure your Gemini API key (see Developer Setup)

### Installation

```bash
# Clone the repository
git clone https://github.com/doctorloveapp/chatscanner.git
cd chatscanner

# Install dependencies
flutter pub get

# Generate launcher icons
flutter pub run flutter_launcher_icons

# Run in debug mode
flutter run
```

### Configuration

The API key is securely embedded and obfuscated at build time.

**For Developers:** If you're building from source, you need to configure your own API key:

1. Create a `.env` file in the project root:

   ```
   GEMINI_API_KEY=your_api_key_here
   ```

2. Run code generation:

   ```bash
   flutter pub run build_runner build
   ```

3. The `.env` file is gitignored for security

> **Security Note**: The API key is obfuscated using the `envied` package and further protected by Flutter's `--obfuscate` flag during release builds.

---

## 📦 Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_overlay_window` | ^0.5.0 | System overlay for floating scanner |
| `google_generative_ai` | ^0.4.0 | Google Gemini AI integration |
| `flutter_animate` | ^4.5.0 | UI animations |
| `google_fonts` | ^6.1.0 | Typography (Orbitron, JetBrains Mono) |
| `image_picker` | ^1.0.7 | Gallery image selection |
| `path_provider` | ^2.1.5 | File system access |
| `permission_handler` | ^11.3.1 | Runtime permission management |
| `envied` | ^0.5.4 | Secure API key management |
| `http` | ^1.2.0 | Groq API calls |
| `shared_preferences` | ^2.2.2 | Rate limiting storage |
| `image` | ^4.2.0 | Image merging for Groq |

---

## 🔧 Build

### Debug Build

```bash
flutter run
```

### Release APK

```bash
flutter build apk --release
```

### Release App Bundle (Play Store)

```bash
flutter build appbundle --release
```

Output locations:

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

### Release APK with Obfuscation (Recommended)

```bash
flutter build apk --release --obfuscate --split-debug-info=./debug-info
```

This command enables code obfuscation for enhanced API key protection.

---

## 📝 Android 14+ (API 34+) Notes

When running on Android 14 or higher:

1. **MediaProjection Permission**: Always select "Entire screen" (not "Single app")
2. **Overlay Permission**: Grant "Display over other apps" permission
3. **Foreground Service**: A persistent notification is shown during capture

---

## 🎨 Design System

| Element | Specification |
|---------|--------------|
| **Primary Color** | `#BA68C8` (Pastel Purple) |
| **Secondary Color** | `#F06292` (Pastel Pink) |
| **Title Font** | Orbitron (bold) |
| **Body Font** | JetBrains Mono |
| **Animations** | Shimmer, fade, scale via flutter_animate |

---

## 📁 Project Structure

```
doctor_love/
├── android/                    # Android native code
│   └── app/src/main/
│       ├── AndroidManifest.xml
│       └── res/                # Resources and launcher icons
├── assets/
│   └── icon.png               # App launcher icon
├── lib/
│   ├── main.dart              # Main app + overlay entry point
│   └── overlay_entry_point.dart
├── packages/
│   └── device_screenshot/     # Custom plugin for MediaProjection
│       └── android/src/main/kotlin/
│           └── MediaProjectionService.kt
├── pubspec.yaml
└── README.md
```

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author

**Sons of Art**

- GitHub: [@doctorloveapp](https://github.com/doctorloveapp)

---

## 🙏 Acknowledgments

- [Google Gemini](https://deepmind.google/technologies/gemini/) for AI capabilities
- [Flutter](https://flutter.dev/) for the cross-platform framework
- [flutter_overlay_window](https://pub.dev/packages/flutter_overlay_window) for overlay support

---

<p align="center">
  Made with ❤️ and Flutter
</p>
