# PowerShell Script to fix Firebase C++ SDK issues on Windows for Flutter

# --- Configuration ---
$ProjectDirectory = $PSScriptRoot
$SdkUrl = "https://dl.google.com/firebase/sdk/cpp/firebase_cpp_sdk_12.1.0.zip"
$SdkZipFile = "$env:TEMP\firebase_cpp_sdk.zip"
$ExtractTarget = "$ProjectDirectory\build\windows\x64\extracted"
$FinalSdkPath = "$ExtractTarget\firebase_cpp_sdk_windows"

# --- Script ---

Write-Host "Starting Firebase C++ SDK setup for Flutter..."

# 1. Clean up old build artifacts
Write-Host "[1/4] Cleaning project directories..."
if (Test-Path "$ProjectDirectory\build") { Remove-Item -Recurse -Force "$ProjectDirectory\build" -ErrorAction SilentlyContinue }
if (Test-Path "$ProjectDirectory\.dart_tool") { Remove-Item -Recurse -Force "$ProjectDirectory\.dart_tool" -ErrorAction SilentlyContinue }
if (Test-Path "$ProjectDirectory\windows\flutter\ephemeral") { Remove-Item -Recurse -Force "$ProjectDirectory\windows\flutter\ephemeral" -ErrorAction SilentlyContinue }
Write-Host "Cleanup complete."

# 2. Download the Firebase C++ SDK
Write-Host "[2/4] Downloading Firebase C++ SDK from $SdkUrl..."
try {
    Invoke-WebRequest -Uri $SdkUrl -OutFile $SdkZipFile -ErrorAction Stop
} catch {
    Write-Error "Failed to download the Firebase C++ SDK. Please check your internet connection and the URL in the script: $SdkUrl"
    exit 1
}
Write-Host "Download complete."

# 3. Extract the SDK
Write-Host "[3/4] Extracting SDK to $FinalSdkPath..."
New-Item -ItemType Directory -Force -Path $ExtractTarget
Expand-Archive -Path $SdkZipFile -DestinationPath $ExtractTarget -Force

# The extracted folder has a version number, rename it to what Flutter expects.
$ExtractedFolderName = (Get-ChildItem -Path $ExtractTarget -Directory | Where-Object { $_.Name -like 'firebase_cpp_sdk*' }).Name
if ($ExtractedFolderName) {
    Rename-Item -Path "$ExtractTarget\$ExtractedFolderName" -NewName "firebase_cpp_sdk_windows" -Force
    Write-Host "Extraction and renaming successful."
} else {
    Write-Error "Could not find extracted SDK folder to rename."
    exit 1
}

# 4. Clean up downloaded file
Write-Host "[4/4] Cleaning up downloaded files..."
Remove-Item $SdkZipFile -Force
Write-Host "Cleanup complete."

Write-Host "✅ Firebase C++ SDK setup is complete!"
Write-Host "You can now run your Flutter application."
