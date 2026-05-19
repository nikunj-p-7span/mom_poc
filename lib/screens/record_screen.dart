import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mom_poc/services/audio_service.dart';
import 'package:mom_poc/screens/result_screen.dart';
import 'package:mom_poc/utils/constants.dart';
import 'package:path/path.dart' as p;
import 'package:dart_openai/dart_openai.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final AudioService _audioService = AudioService();

  bool _isRecording = false;
  bool _isTranscribing = false;
  Timer? _timer;
  int _recordDuration = 0;

  final String _apiKey = dotenv.env['OPEN_AI_KEY'] ?? '';
  File? _selectedFile;

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
        setState(() {
          _selectedFile = File(path);
        });
        _transcribeAudio();
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

      final path = await _audioService.getRecordingPath();
      await _audioService.startRecording(path);
      _startTimer();
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _pickFile() async {
    final List<File> files = await _audioService.getRecordedFiles();

    if (!mounted) return;

    if (files.isEmpty) {
      final path = await _audioService.pickAudioFile();
      if (path != null) {
        setState(() {
          _selectedFile = File(path);
        });
        _transcribeAudio();
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pick a Recording',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final fileName = p.basename(file.path);
                    final fileSize = (file.lengthSync() / 1024).toStringAsFixed(1);

                    return ListTile(
                      leading: const Icon(Icons.audio_file, color: AppConstants.primaryColor),
                      title: Text(fileName),
                      subtitle: Text('$fileSize KB'),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedFile = file;
                        });
                        _transcribeAudio();
                      },
                    );
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Other audio files...'),
                onTap: () async {
                  Navigator.pop(context);
                  final path = await _audioService.pickAudioFile();
                  if (path != null) {
                    setState(() {
                      _selectedFile = File(path);
                    });
                    _transcribeAudio();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _transcribeAudio() async {
    // Validate state
    if (_apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an OpenAI API Key.')));
      return;
    }
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an audio file first.')));
      return;
    }

    // Set transcribing state to show loading indicator
    setState(() {
      _isTranscribing = true;
    });

    try {
      // Set the API Key for dart_openai
      OpenAI.apiKey = _apiKey;

      // Translate multilingual audio -> English
      final translation = await OpenAI.instance.audio.createTranslation(
        file: _selectedFile!,
        model: "whisper-1",
        responseFormat: OpenAIAudioResponseFormat.json,
        prompt: """
The audio contains an internal office meeting conversation.

The speakers may talk in:
- English
- Hindi
- Gujarati
- Mixed multilingual sentences

Your task:
- Translate the entire conversation into clear professional English.
- Preserve the original meaning and context accurately.
- Keep technical terms, project names, APIs, code references, and business terminology unchanged where appropriate.
- Maintain discussion flow between team members.
- Convert informal spoken sentences into readable professional English.
- Remove filler words, repeated words, unnecessary pauses, and background noise expressions.
- Keep action items, decisions, blockers, deadlines, suggestions, and important discussion points accurate.
- Preserve names of people, technologies, frameworks, libraries, and tools exactly as spoken.
- If multiple speakers are talking, separate statements logically.

Important:
- Return ONLY clean English text.
- Do NOT summarize.
- Do NOT generate MOM notes.
- Do NOT omit important discussion points.
- Do NOT add extra explanations.
""",
      );

      final transcriptionResult = translation;

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(transcript: transcriptionResult),
          ),
        );
      }
    } catch (e) {
      // Handle transcription error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transcription failed: $e')));
      }
    } finally {
      // Revert loading state
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record & Transcribe (Online)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Spacer(),
            Center(
              child: _isTranscribing ? _buildProcessingUI() : _buildRecordingUI(),
            ),
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
        _buildMicButton(),
        const SizedBox(height: 24),
        Text(
          _isRecording ? 'Tap to Stop' : 'Tap to Start Recording',
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

  Widget _buildProcessingUI() {
    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        const Text(
          'Transcribing online with OpenAI...',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
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
