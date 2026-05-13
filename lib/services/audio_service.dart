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

  /// Get a temporary path for recording
  Future<String> getTempPath() async {
    final dir = await getTemporaryDirectory();
    return p.join(dir.path, 'recording_${DateTime.now().millisecondsSinceEpoch}.wav');
  }

  /// Pick an audio file from the device
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
