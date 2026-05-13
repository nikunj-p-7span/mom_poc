import 'package:flutter/material.dart';
import 'package:mom_poc/services/audio_service.dart';
import 'package:mom_poc/services/whisper_service.dart';
import 'package:mom_poc/screens/result_screen.dart';
import 'package:mom_poc/utils/constants.dart';
import 'dart:async';

import 'package:whisper_kit/download_model.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final AudioService _audioService = AudioService();
  final WhisperService _whisperService = WhisperService();

  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isDownloadingModel = false;
  double _downloadProgress = 0;
  String _selectedLanguage = 'en';
  Timer? _timer;
  int _recordDuration = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  void _startTimer() {
    _recordDuration = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioService.stopRecording();
      _stopTimer();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        _startTranscription(path);
      }
    } else {
      final hasPermission = await _audioService.checkPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
        return;
      }

      final path = await _audioService.getTempPath();
      await _audioService.startRecording(path);
      _startTimer();
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _pickFile() async {
    final path = await _audioService.pickAudioFile();
    if (path != null) {
      _startTranscription(path);
    }
  }

  Future<void> _startTranscription(String path) async {
    setState(() {
      _isTranscribing = true;
    });

    try {
      // Initialize if not done
      if (!_whisperService.isInitialized) {
        debugPrint('[Whisper] Model not initialized — starting download...');
        setState(() {
          _isDownloadingModel = true;
          _downloadProgress = 0;
        });

        await _whisperService.init(
          model: WhisperModel.medium,
          onDownloadProgress: (received, total) {
            final progress = received / total;
            final receivedMB = (received / 1024 / 1024).toStringAsFixed(2);
            final totalMB = (total / 1024 / 1024).toStringAsFixed(2);
            final percent = (progress * 100).toStringAsFixed(1);

            debugPrint(
              '[Whisper] Downloading model: $receivedMB MB / $totalMB MB ($percent%)',
            );

            setState(() {
              _downloadProgress = progress;
            });
          },
        );

        debugPrint('[Whisper] Model download complete ✓');
        setState(() => _isDownloadingModel = false);
      } else {
        debugPrint('[Whisper] Model already initialized — skipping download.');
      }

      debugPrint('[Whisper] Starting transcription for: $path');
      debugPrint('[Whisper] Selected language: $_selectedLanguage');

      final text = await _whisperService.transcribe(
        path,
        language: _selectedLanguage,
      );

      debugPrint('[Whisper] Transcription complete. Length: ${text.length} chars');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(transcript: text),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[Whisper] ERROR: ${e.toString()}');
      debugPrint('[Whisper] StackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
          _isDownloadingModel = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record & Transcribe'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildLanguageSelector(),
            const Spacer(),
            if (_isTranscribing)
              _buildProcessingUI()
            else
              _buildRecordingUI(),
            const Spacer(),
            if (!_isRecording && !_isTranscribing)
              TextButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.file_upload),
                label: const Text('Pick audio file from device'),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            const Icon(Icons.language, color: AppConstants.primaryColor),
            const SizedBox(width: 12),
            const Text('Language: ', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            DropdownButton<String>(
              value: _selectedLanguage,
              underline: const SizedBox(),
              items: AppConstants.languages.entries.map((e) {
                return DropdownMenuItem(
                  value: e.value,
                  child: Text(e.key),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedLanguage = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingUI() {
    return Column(
      children: [
        if (_isRecording) ...[
          Text(
            _formatDuration(_recordDuration),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recording...',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
        const SizedBox(height: 48),
        GestureDetector(
          onTap: _toggleRecording,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _isRecording ? Colors.red : AppConstants.primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_isRecording ? Colors.red : AppConstants.primaryColor).withValues(alpha: 0.3),
                  spreadRadius: 8,
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _isRecording ? 'Tap to Stop' : 'Tap to Start Recording',
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildProcessingUI() {
    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          _isDownloadingModel ? 'Downloading Model...' : 'Transcribing...',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (_isDownloadingModel) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _downloadProgress),
          const SizedBox(height: 8),
          Text('${(_downloadProgress * 100).toStringAsFixed(1)}%'),
        ],
        const SizedBox(height: 16),
        const Text(
          'This may take a few moments depending on audio length.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}
