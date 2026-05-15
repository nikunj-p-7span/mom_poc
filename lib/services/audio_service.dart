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

  /// Get a path for recording in the documents directory with a timestamp
  Future<String> getRecordingPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory(p.join(dir.path, 'recordings'));
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    
    final now = DateTime.now();
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final amPm = now.hour < 12 ? 'AM' : 'PM';
    
    final dateStr = "${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}";
    final timeStr = "${_twoDigits(hour12)}.${_twoDigits(now.minute)}.${_twoDigits(now.second)} $amPm";
    
    return p.join(recordingsDir.path, 'recording $dateStr $timeStr.wav');
  }

  String _twoDigits(int n) => n >= 10 ? "$n" : "0$n";

  /// Get all recorded files from the app's recording directory
  Future<List<File>> getRecordedFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory(p.join(dir.path, 'recordings'));
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
