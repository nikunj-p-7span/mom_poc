import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  
  /// Check and request microphone permission
  Future<bool> checkPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Start recording with specific settings for Whisper (16kHz, 16-bit PCM WAV)
  Future<void> startRecording(String path) async {
    if (await _recorder.isRecording()) return;

    const config = RecordConfig(
      encoder: AudioEncoder.wav, // Using WAV container
      sampleRate: 16000,         // 16kHz
      numChannels: 1,            // Mono
      bitRate: 128000,
    );

    await _recorder.start(config, path: path);
  }

  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    return await _recorder.stop();
  }

  /// Helper to get the MOM Generator directory path with proper permissions
  Future<String> getMOMGeneratorDirectoryPath() async {
    if (Platform.isAndroid) {
      bool hasAccess = false;
      
      // Request manageExternalStorage if on Android 11+
      if (await Permission.manageExternalStorage.request().isGranted) {
        hasAccess = true;
      } else if (await Permission.storage.request().isGranted) {
        hasAccess = true;
      }
      
      if (hasAccess) {
        final publicDownloadDir = Directory('/storage/emulated/0/MOM Generator');
        try {
          if (!await publicDownloadDir.exists()) {
            await publicDownloadDir.create(recursive: true);
          }
          return publicDownloadDir.path;
        } catch (e) {
          // If public Download creation fails, fallback to app external storage
        }
      }
      
      // Fallback 1: App specific external storage
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final fallbackDir = Directory(p.join(externalDir.path, 'MOM Generator'));
        if (!await fallbackDir.exists()) {
          await fallbackDir.create(recursive: true);
        }
        return fallbackDir.path;
      }
    } else if (Platform.isIOS) {
      // iOS: Application Documents folder made visible via Info.plist UIFileSharingEnabled
      final documentsDir = await getApplicationDocumentsDirectory();
      final momDir = Directory(p.join(documentsDir.path, 'MOM Generator'));
      if (!await momDir.exists()) {
        await momDir.create(recursive: true);
      }
      return momDir.path;
    }
    
    // Fallback: App Documents folder
    final documentsDir = await getApplicationDocumentsDirectory();
    final momDir = Directory(p.join(documentsDir.path, 'MOM Generator'));
    if (!await momDir.exists()) {
      await momDir.create(recursive: true);
    }
    return momDir.path;
  }

  /// Get a path for recording in the MOM Generator directory with a timestamp
  Future<String> getRecordingPath() async {
    final dirPath = await getMOMGeneratorDirectoryPath();
    
    final now = DateTime.now();
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final amPm = now.hour < 12 ? 'AM' : 'PM';
    
    final dateStr = "${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}";
    final timeStr = "${_twoDigits(hour12)}.${_twoDigits(now.minute)}.${_twoDigits(now.second)} $amPm";
    
    return p.join(dirPath, 'recording $dateStr $timeStr.wav');
  }

  String _twoDigits(int n) => n >= 10 ? "$n" : "0$n";

  /// Get all recorded files from the MOM Generator directory
  Future<List<File>> getRecordedFiles() async {
    final dirPath = await getMOMGeneratorDirectoryPath();
    final recordingsDir = Directory(dirPath);
    if (!await recordingsDir.exists()) return [];
    
    final files = recordingsDir.listSync()
        .whereType<File>()
        .where((file) => p.extension(file.path) == '.wav')
        .toList();
    
    // Sort by date (newest first)
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// Pick an audio file from the device (system picker)
  Future<String?> pickAudioFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      return result.files.single.path;
    }
    return null;
  }

  void dispose() {
    _recorder.dispose();
  }
}
