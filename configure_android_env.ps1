# Script per configurare le variabili d'ambiente per Android
Write-Host "=== Configurazione Variabili d'Ambiente ===" -ForegroundColor Green

$javaHome = "C:\Program Files\Microsoft\jdk-17.0.9.8-hotspot"
$androidHome = "C:\Android\sdk"

# Imposta JAVA_HOME per l'utente corrente
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, [System.EnvironmentVariableTarget]::User)
Write-Host "JAVA_HOME impostato a: $javaHome" -ForegroundColor Yellow

# Imposta ANDROID_HOME per l'utente corrente
[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidHome, [System.EnvironmentVariableTarget]::User)
Write-Host "ANDROID_HOME impostato a: $androidHome" -ForegroundColor Yellow

# Aggiorna PATH per includere platform-tools
$currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
$platformTools = "$androidHome\platform-tools"
$cmdlineTools = "$androidHome\cmdline-tools\latest\bin"

if ($currentPath -notlike "*$platformTools*") {
    $newPath = "$currentPath;$platformTools;$cmdlineTools"
    [System.Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::User)
    Write-Host "PATH aggiornato con Android tools" -ForegroundColor Yellow
}

Write-Host "`n=== Configurazione completata! ===" -ForegroundColor Green
Write-Host "RIAVVIA VS Code per applicare le modifiche." -ForegroundColor Cyan
Write-Host "Poi esegui: flutter doctor --android-licenses" -ForegroundColor Cyan
