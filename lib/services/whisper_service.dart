import 'package:whisper_kit/whisper_kit.dart';
import 'package:whisper_kit/download_model.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class WhisperService {
  static final WhisperService _instance = WhisperService._internal();
  factory WhisperService() => _instance;
  WhisperService._internal();

  Whisper? _whisper;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  WhisperModel? get currentModel => _whisper?.model;

  /// Check if a model is already downloaded
  Future<bool> isModelDownloaded(WhisperModel model) async {
    final directory = await getApplicationDocumentsDirectory();
    final modelDir = '${directory.path}/whisper_models';
    final modelFileName = getModelFileName(model);
    final modelFile = File('$modelDir/$modelFileName');
    return await modelFile.exists();
  }

  /// Initialize Whisper and download model if necessary
  Future<void> init({
    WhisperModel model = WhisperModel.base,
    Function(int, int)? onDownloadProgress,
  }) async {
    // If already initialized with the same model, skip
    if (_isInitialized && _whisper?.model == model) {
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final modelDir = '${directory.path}/whisper_models';

      await Directory(modelDir).create(recursive: true);

      final modelFileName = getModelFileName(model);
      final modelFile = File('$modelDir/$modelFileName');

      if (!await modelFile.exists()) {
        await downloadModel(
          model: model,
          destinationPath: modelDir,
          onDownloadProgress: onDownloadProgress,
        );
      }

      _whisper = Whisper(
        model: model,
        modelDir: modelDir,
      );

      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      _whisper = null;
      rethrow;
    }
  }

  /// Transcribe an audio file
  Future<String> transcribe(String audioPath, {String language = 'auto'}) async {
    if (_whisper == null) {
      throw Exception('Whisper not initialized. Call init() first.');
    }

    if (!File(audioPath).existsSync()) {
      throw Exception('Audio file not found at $audioPath');
    }

    try {
      final request = TranscribeRequest(
        audio: audioPath,
        language: language,
        isVerbose: true,
      );

      final response = await _whisper!.transcribe(
        transcribeRequest: request,
      );

      return response.text;
    } catch (e) {
      throw Exception('Transcription failed: $e');
    }
  }

  /// Helper to get the filename for the Whisper model
  String getModelFileName(WhisperModel model) {
    switch (model) {
      case WhisperModel.tiny:
        return 'ggml-tiny.bin';
      case WhisperModel.base:
        return 'ggml-base.bin';
      case WhisperModel.small:
        return 'ggml-small.bin';
      case WhisperModel.medium:
        return 'ggml-medium.bin';
      case WhisperModel.largeV1:
        return 'ggml-large-v1.bin';
      case WhisperModel.largeV2:
        return 'ggml-large-v2.bin';
      default:
        return 'ggml-base.bin';
    }
  }
}
