import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mom_poc/services/audio_service.dart';
import 'package:mom_poc/screens/result_screen.dart';
import 'package:mom_poc/utils/constants.dart';
import 'package:mom_poc/utils/wav_splitter.dart';
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
  String _transcribingProgress = '';

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an OpenAI API Key.')),
      );
      return;
    }
    if (_selectedFile == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an audio file first.')),
      );
      return;
    }

    // Check file size (OpenAI Whisper limit is 25 MB = 26,214,400 bytes)
    int fileLength = 0;
    try {
      fileLength = await _selectedFile!.length();
    } catch (e) {
      // Proceed if we cannot read the file length for some reason
    }

    const int maxLimit = 25 * 1024 * 1024; // 26214400 bytes
    List<File> filesToTranscribe = [_selectedFile!];
    bool isSplit = false;

    if (fileLength > maxLimit) {
      final isWav = p.extension(_selectedFile!.path).toLowerCase() == '.wav';
      if (isWav) {
        setState(() {
          _isTranscribing = true;
          _transcribingProgress = "Splitting WAV file into smaller parts...";
        });
        try {
          filesToTranscribe = await WavSplitter.splitWavFile(_selectedFile!, maxChunkSizeBytes: 20 * 1024 * 1024);
          isSplit = filesToTranscribe.length > 1;
        } catch (e) {
          // If splitting fails, fall back to trying original file or showing error
          filesToTranscribe = [_selectedFile!];
        }
      } else {
        final double sizeInMb = fileLength / (1024 * 1024);
        if (mounted) {
          _showLargeFileBottomSheet(sizeInMb);
        }
        return;
      }
    }

    // Set transcribing state to show loading indicator
    setState(() {
      _isTranscribing = true;
    });

    try {
      // Set the API Key for dart_openai
      OpenAI.apiKey = _apiKey;
      OpenAI.requestsTimeOut = const Duration(minutes: 5);

      final List<String> transcriptions = [];

      for (int i = 0; i < filesToTranscribe.length; i++) {
        final File file = filesToTranscribe[i];
        
        if (filesToTranscribe.length > 1) {
          setState(() {
            _transcribingProgress = "Transcribing part ${i + 1} of ${filesToTranscribe.length}...";
          });
        } else {
          setState(() {
            _transcribingProgress = "Transcribing online with OpenAI...";
          });
        }

        // Translate multilingual audio -> English
        final translationText = await OpenAI.instance.audio.createTranslation(
          file: file,
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
        
        if (translationText.trim().isNotEmpty) {
          transcriptions.add(translationText.trim());
        }
      }

      // Merge results
      final transcriptionResult = transcriptions.join('\n\n');

      // Clean up temporary split WAV files if we generated them
      if (isSplit) {
        for (final File file in filesToTranscribe) {
          try {
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {}
        }
      }

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
        debugPrint('Transcription failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transcription failed: $e')));
      }
    } finally {
      // Revert loading state and reset progress
      if (mounted) {
        setState(() {
          _isTranscribing = false;
          _transcribingProgress = '';
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
        Text(
          _transcribingProgress.isNotEmpty ? _transcribingProgress : 'Transcribing online with OpenAI...',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  void _showLargeFileBottomSheet(double sizeInMb) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: Colors.amber.shade800,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'File Too Large',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Selected file is ${sizeInMb.toStringAsFixed(1)} MB, which exceeds the OpenAI Whisper 25 MB limit.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recommended Solutions:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildTipRow(
                context,
                icon: Icons.mic_none_rounded,
                title: 'Use App Audio Recorder',
                description: 'We have optimized the built-in recorder to compress files at 24 kbps. Recording directly in the app now allows over 2 hours of continuous audio under the 25 MB limit!',
              ),
              const SizedBox(height: 16),
              _buildTipRow(
                context,
                icon: Icons.compress_rounded,
                title: 'Compress Before Uploading',
                description: 'Use a free online audio compressor (e.g. compress mp3/m4a to 24-32kbps mono) or convert your file to MP3 format with standard compression settings.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTipRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
