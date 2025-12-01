# Script per installare Android SDK per Flutter
Write-Host "=== Installazione Android SDK ===" -ForegroundColor Green

$sdkPath = "C:\Android\sdk"
$cmdlineToolsUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
$zipFile = "$env:TEMP\cmdline-tools.zip"

# Crea la directory SDK
Write-Host "Creazione directory SDK in $sdkPath..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $sdkPath | Out-Null
New-Item -ItemType Directory -Force -Path "$sdkPath\cmdline-tools" | Out-Null

# Download Command Line Tools
Write-Host "Download Android Command Line Tools..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $cmdlineToolsUrl -OutFile $zipFile -UseBasicParsing
    Write-Host "Download completato!" -ForegroundColor Green
}
catch {
    Write-Host "Errore durante il download: $_" -ForegroundColor Red
    exit 1
}

# Estrai i file
Write-Host "Estrazione file..." -ForegroundColor Yellow
Expand-Archive -Path $zipFile -DestinationPath "$sdkPath\cmdline-tools" -Force

# Rinomina la cartella cmdline-tools in latest
if (Test-Path "$sdkPath\cmdline-tools\cmdline-tools") {
    Move-Item -Path "$sdkPath\cmdline-tools\cmdline-tools" -Destination "$sdkPath\cmdline-tools\latest" -Force
}

# Configura Flutter per usare questo SDK
Write-Host "Configurazione Flutter..." -ForegroundColor Yellow
flutter config --android-sdk $sdkPath

# Installa i componenti necessari
Write-Host "Installazione componenti Android (platform-tools, build-tools, platform)..." -ForegroundColor Yellow
$sdkmanager = "$sdkPath\cmdline-tools\latest\bin\sdkmanager.bat"

& $sdkmanager --licenses
& $sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# Pulizia
Remove-Item $zipFile -Force

Write-Host "`n=== Installazione completata! ===" -ForegroundColor Green
Write-Host "Esegui 'flutter doctor' per verificare." -ForegroundColor Cyan
