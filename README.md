# Chat Scanner App 📱

Un'applicazione Flutter che utilizza l'IA di Google Gemini per analizzare screenshot di chat e valutare il livello di interesse, fornendo un punteggio e consigli su come rispondere.

## 📱 Stato Attuale
- **Ultimo aggiornamento:** 1 Dicembre 2025
- **Versione:** 1.0.0+1
- **Stato:** ✅ **FUNZIONANTE AL 100%**

---

## ✅ Funzionalità Complete

### 🔴 Modalità Live (Overlay Scanner)
- Icona scanner (👻) trascinabile che fluttua sopra altre app
- **Tap singolo**: Cattura screenshot dell'app sottostante
- **Doppio tap / Pressione lunga**: Chiude l'overlay e torna all'app principale
- Badge numerico che mostra quanti screenshot sono stati catturati
- Gli screenshot vengono caricati automaticamente quando si ritorna all'app
- Counter si resetta quando si inizia una nuova analisi

### 📸 Cattura Screenshot
- Utilizzo di MediaProjection API per catturare qualsiasi schermata
- Servizio in foreground per mantenere la cattura attiva
- Comunicazione file-based tra overlay e servizio nativo

### 🤖 Analisi IA
- Integrazione con Google Gemini (2.5-pro con fallback a 1.5-pro)
- Analisi del livello di interesse (0-100)
- Rating delle singole frasi
- Suggerimento per la prossima mossa
- Messaggi di loading professionali

### 📂 Aggiunta Screenshot
- **Scanner Live**: Cattura in tempo reale da altre app
- **Da Dispositivo**: Seleziona immagini dalla galleria

---

## 🛠 Architettura Tecnica

### Problema Risolto: Overlay e Screenshot
Il problema principale era far comunicare l'overlay Flutter (che gira in un processo isolato) con il servizio MediaProjection nativo.

### Soluzione Implementata: Comunicazione File-Based

```
┌─────────────────────────────────────────────────────────────────┐
│                        ARCHITETTURA                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐         ┌─────────────────────────────┐   │
│  │  Flutter Overlay │         │  MediaProjectionService.kt  │   │
│  │  (ScannerOverlay)│         │  (Foreground Service)       │   │
│  └────────┬────────┘         └──────────────┬──────────────┘   │
│           │                                  │                  │
│           │  1. Scrive file                  │  2. Polling      │
│           │     "capture_request"            │     ogni 100ms   │
│           ▼                                  ▼                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              ghost_comm/                                 │   │
│  │  ├── capture_request  (trigger)                         │   │
│  │  ├── capture_result   (success:/path o error:msg)       │   │
│  │  └── reset_counter    (segnale reset contatore)         │   │
│  └─────────────────────────────────────────────────────────┘   │
│           │                                  │                  │
│           │  4. Legge risultato              │  3. Cattura e    │
│           │     (polling 100ms)              │     scrive       │
│           ▼                                  ▼                  │
│  ┌─────────────────┐         ┌─────────────────────────────┐   │
│  │  Overlay aggiorna│         │  Screenshot salvato in      │   │
│  │  badge contatore │         │  screenshots/*.png          │   │
│  └─────────────────┘         └─────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### File Chiave

#### 1. `lib/main.dart`
- **`overlayMain()`**: Entry point dell'overlay (annotato con `@pragma("vm:entry-point")`)
- **`ScannerOverlayWidget`**: Widget StatefulWidget per l'overlay
- **`_requestScreenshot()`**: Scrive file request e fa polling per il risultato
- **`_closeAndReturnToApp()`**: Chiama MethodChannel per tornare all'app principale
- **`_checkForReset()`**: Polling per rilevare reset del contatore

#### 2. `packages/device_screenshot/.../MediaProjectionService.kt`
- Servizio foreground con tipo `MEDIA_PROJECTION`
- **`setupFilePolling()`**: Polling ogni 100ms per file `capture_request`
- **`captureScreenshot()`**: Cattura via VirtualDisplay + ImageReader
- **`writeResultFile()`**: Scrive `capture_result` con path o errore

#### 3. `packages/device_screenshot/.../DeviceScreenshotPlugin.kt`
- **`requestMediaProjection`**: Avvia intent per permesso cattura schermo
- **`checkMediaProjectionService`**: Verifica se il servizio è attivo
- **`bringAppToForeground`**: Riporta l'app principale in primo piano

### Permessi Android Richiesti
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION"/>
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
```

### Configurazione Servizio
```xml
<service
    android:name=".src.MediaProjectionService"
    android:foregroundServiceType="mediaProjection"
    android:exported="false"/>
```

---

## 🔧 Problemi Risolti Durante lo Sviluppo

### 1. ❌ MethodChannel non funziona dall'overlay
**Problema**: L'overlay gira in un processo Flutter separato, i MethodChannel non comunicano con il servizio principale.
**Soluzione**: Comunicazione file-based tramite directory `ghost_comm/`.

### 2. ❌ FileObserver non rileva file creati dall'overlay
**Problema**: FileObserver nativo non vedeva i file scritti dall'overlay Flutter.
**Soluzione**: Sostituito con polling attivo ogni 100ms.

### 3. ❌ Overlay sparisce dopo il primo tap
**Problema**: L'overlay si chiudeva o si spostava fuori schermo.
**Soluzione**: 
- Cambiato da `StatelessWidget` a `StatefulWidget`
- Aggiunto `HitTestBehavior.opaque` al GestureDetector
- Rimosso flag problematico, usato `OverlayFlag.defaultFlag`

### 4. ❌ Doppio tap non torna all'app
**Problema**: `FlutterOverlayWindow.closeOverlay()` chiudeva l'overlay ma non riportava l'app in primo piano.
**Soluzione**: Aggiunto metodo `bringAppToForeground` via MethodChannel che usa `FLAG_ACTIVITY_REORDER_TO_FRONT`.

### 5. ❌ MediaProjection crash su Android 14+
**Problema**: Su API 34+ il servizio deve chiamare `startForeground()` immediatamente.
**Soluzione**: Chiamata `startForegroundWithNotification()` subito in `onStartCommand()` prima di inizializzare la proiezione.

### 6. ❌ Counter overlay non si resettava
**Problema**: Quando si cliccava "Analizza un'altra chat", il contatore dell'overlay rimaneva al valore precedente.
**Soluzione**: 
- L'app crea un file `reset_counter` quando si cancellano gli screenshot
- L'overlay fa polling ogni 500ms per questo file
- Quando lo trova, resetta il contatore a 0 e cancella il file

---

## 📦 Dipendenze

```yaml
dependencies:
  flutter_overlay_window: ^0.5.0
  google_generative_ai: ^0.4.3
  flutter_animate: ^4.5.2
  google_fonts: ^6.2.1
  image_picker: ^1.1.2
  path_provider: ^2.1.5
```

---

## 🚀 Come Eseguire

```bash
# Connetti dispositivo Android
adb devices

# Esegui in debug
flutter run

# Build APK release
flutter build apk --release
```

---

## 📝 Note per Android 14+ (API 34+)

1. **MediaProjection**: Selezionare sempre "Schermo intero" (non "Un'app singola")
2. **Overlay**: Concedere permesso "Mostra sopra altre app"
3. **Notifica**: Il servizio mostra una notifica persistente durante la cattura

---

## 🎨 UI/UX

- **Tema**: Colori pastello (viola/rosa)
- **Font**: Google Fonts (Orbitron per titoli, JetBrains Mono per testo)
- **Animazioni**: Flutter Animate per shimmer, fade, scale effects
- **Overlay**: Cerchio bianco 200x200dp con emoji 👻 e bordo viola
