$url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.38.3-stable.zip"
$zipPath = "$env:TEMP\flutter.zip"
$destination = "C:\"

Write-Host "Downloading Flutter SDK from $url..."
# Use Start-BitsTransfer for better progress/reliability if available, else Invoke-WebRequest
if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
    Start-BitsTransfer -Source $url -Destination $zipPath
} else {
    Invoke-WebRequest -Uri $url -OutFile $zipPath
}

Write-Host "Extracting Flutter SDK to $destination..."
if (Test-Path "C:\flutter") {
    Write-Host "C:\flutter already exists. Skipping extraction to avoid overwriting."
} else {
    Expand-Archive -Path $zipPath -DestinationPath $destination -Force
}

Write-Host "Adding Flutter to PATH..."
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*C:\flutter\bin*") {
    $newPath = "$currentPath;C:\flutter\bin"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Flutter added to User PATH. Please restart your terminal and IDE."
} else {
    Write-Host "Flutter is already in User PATH."
}

Write-Host "Cleaning up..."
if (Test-Path $zipPath) {
    Remove-Item $zipPath
}

Write-Host "Installation complete! Run 'flutter doctor' in a new terminal to verify."
