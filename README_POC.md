# Offline Speech-to-Text POC (WhisperKit)

A Flutter Proof of Concept for offline speech-to-text conversion using the `whisper_kit` package.

## Features
- **Offline Transcription**: Uses OpenAI Whisper models locally on the device.
- **Languages Support**: English, Hindi, and Gujarati.
- **Audio Recording**: Built-in recorder configured for Whisper's required format (16kHz, 16-bit PCM WAV).
- **File Picker**: Upload existing audio files for transcription.
- **Modern UI**: Material 3 design with a clean, premium aesthetic.
- **Copy & Share**: Easily copy transcripts or share them via other apps.

## Prerequisites
- Flutter SDK (3.x recommended)
- Android Studio / Xcode
- Physical device recommended for testing microphone and performance.

## Setup Instructions

### 1. Dependencies
Run the following command to ensure all packages are installed:
```bash
flutter pub get
```

### 2. Android Configuration
Ensure the following permissions are in `android/app/src/main/AndroidManifest.xml`:
- `RECORD_AUDIO`
- `INTERNET` (Required only for the initial model download)
- `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE`

### 3. iOS Configuration
Ensure the following keys are in `ios/Runner/Info.plist`:
- `NSMicrophoneUsageDescription`
- `NSPhotoLibraryUsageDescription`

### 4. Running the App
```bash
flutter run
```

## How it Works
1. **Initial Run**: When you first try to transcribe, the app will download the `base` Whisper model (~142MB) from HuggingFace. This requires an internet connection.
2. **Subsequent Runs**: Once the model is downloaded, you can turn off the internet and the transcription will work fully offline.
3. **Recording**: The app records in 16kHz Mono WAV format, which is the optimal format for `whisper_kit`.
4. **Performance**: Transcription speed depends on the device's CPU/RAM and the length of the audio.

## Project Structure
- `lib/services/whisper_service.dart`: Manages the Whisper engine and transcription.
- `lib/services/audio_service.dart`: Handles microphone recording and file picking.
- `lib/screens/`: Contains the UI screens (Home, Record, Result).
- `lib/utils/constants.dart`: App-wide constants and configurations.

## Troubleshooting
- **WAV Format**: If uploading an external file, ensure it is a 16kHz, 16-bit PCM WAV file. Other formats might fail in the current version of the native core.
- **Permissions**: Ensure you grant microphone access when prompted.
- **Device RAM**: Whisper models can be memory-intensive. 4GB+ RAM is recommended.
