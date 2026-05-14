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
  bool _isModelDownloaded = false;
  double _downloadProgress = 0;
  String _selectedLanguage = 'en';
  WhisperModel _selectedModel = WhisperModel.base;
  Timer? _timer;
  int _recordDuration = 0;

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
  }

  Future<void> _checkModelStatus() async {
    final isDownloaded = await _whisperService.isModelDownloaded(_selectedModel);
    setState(() {
      _isModelDownloaded = isDownloaded;
    });
  }

  Future<void> _downloadModel() async {
    setState(() {
      _isDownloadingModel = true;
      _downloadProgress = 0;
    });

    try {
      await _whisperService.init(
        model: _selectedModel,
        onDownloadProgress: (received, total) {
          if (mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _isModelDownloaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading model: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingModel = false;
        });
      }
    }
  }

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
      debugPrint('[Whisper] Ensuring model is initialized: $_selectedModel');
      
      // If model not initialized in service, initialize it (it should already be downloaded)
      if (!_whisperService.isInitialized || (_whisperService.currentModel != _selectedModel)) {
        await _whisperService.init(
          model: _selectedModel,
          onDownloadProgress: (received, total) {
            if (mounted) {
              setState(() {
                _isDownloadingModel = true;
                _downloadProgress = received / total;
              });
            }
          },
        );
      }

      debugPrint('[Whisper] Model initialized ✓');
      setState(() => _isDownloadingModel = false);

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
            const SizedBox(height: 10),
            _buildLanguageSelector(),
            const SizedBox(height: 12),
            _buildModelSelector(),
            const Spacer(),
            if (_isTranscribing)
              _buildProcessingUI()
            else
              _buildRecordingUI(),
            const Spacer(),
            if (!_isRecording && !_isTranscribing && _isModelDownloaded)
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

  Widget _buildModelSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.speed, color: AppConstants.primaryColor),
                SizedBox(width: 12),
                Text('Transcription Quality:', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<WhisperModel>(
                segments: const [
                  ButtonSegment(
                    value: WhisperModel.tiny,
                    label: Text('Fast'),
                    icon: Icon(Icons.bolt, size: 16),
                  ),
                  ButtonSegment(
                    value: WhisperModel.base,
                    label: Text('Balanced'),
                    icon: Icon(Icons.balance, size: 16),
                  ),
                  ButtonSegment(
                    value: WhisperModel.medium,
                    label: Text('Accurate'),
                    icon: Icon(Icons.high_quality, size: 16),
                  ),
                ],
                selected: {_selectedModel},
                onSelectionChanged: (Set<WhisperModel> newSelection) {
                  setState(() {
                    _selectedModel = newSelection.first;
                    _checkModelStatus();
                  });
                },
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getModelDescription(_selectedModel),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  String _getModelDescription(WhisperModel model) {
    switch (model) {
      case WhisperModel.tiny:
        return 'Very fast, lowest accuracy (approx. 39MB)';
      case WhisperModel.base:
        return 'Fast, good accuracy (approx. 145MB)';
      case WhisperModel.medium:
        return 'Slow, highest accuracy (approx. 1.5GB)';
      default:
        return '';
    }
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
        if (!_isModelDownloaded || _isDownloadingModel)
          _buildDownloadUI()
        else
          _buildMicButton(),
        const SizedBox(height: 24),
        Text(
          _isDownloadingModel
              ? 'Downloading Model...'
              : _isModelDownloaded
                  ? (_isRecording ? 'Tap to Stop' : 'Tap to Start Recording')
                  : 'Download model to start',
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
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
    );
  }

  Widget _buildDownloadUI() {
    return Column(
      children: [
        if (_isDownloadingModel) ...[
          SizedBox(
            width: 200,
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _downloadProgress,
                  backgroundColor: AppConstants.primaryColor.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ] else
          ElevatedButton.icon(
            onPressed: _downloadModel,
            icon: const Icon(Icons.download),
            label: const Text('Download Model'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
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
