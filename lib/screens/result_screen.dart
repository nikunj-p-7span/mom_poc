import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mom_poc/services/gemma_service.dart';
import 'package:mom_poc/utils/constants.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ResultScreen extends StatefulWidget {
  final String transcript;

  const ResultScreen({super.key, required this.transcript});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GemmaService _gemmaService = GemmaService();

  String? _generatedNotes;
  bool _isGenerating = false;
  bool _isDownloading = false;
  String _statusMessage = 'Preparing...';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  void _share(String text) {
    Share.share(text);
  }

  Future<void> _generateNotes() async {
    // Check if model needs installation/loading
    if (!_gemmaService.isModelLoaded) {
      setState(() {
        _isDownloading = true;
        _statusMessage = 'Checking model status...';
      });

      try {
        await _gemmaService.downloadModel(
          onProgressMessage: (message) {
            setState(() => _statusMessage = message);
          },
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error preparing Gemma model: $e')),
          );
        }
        setState(() => _isDownloading = false);
        return;
      }
      setState(() => _isDownloading = false);
    }

    setState(() {
      _isGenerating = true;
      _tabController.animateTo(1); // Switch to AI Notes tab
    });

    try {
      final notes = await _gemmaService.generateMeetingNotes(widget.transcript);
      setState(() {
        _generatedNotes = notes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating notes: $e')),
        );
      }
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Transcript', icon: Icon(Icons.description_outlined)),
            Tab(text: 'AI Notes', icon: Icon(Icons.auto_awesome_outlined)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _share(_tabController.index == 0 ? widget.transcript : (_generatedNotes ?? '')),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTranscriptTab(),
          _buildNotesTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0 && _generatedNotes == null && !_isGenerating && !_isDownloading
          ? FloatingActionButton.extended(
              onPressed: _generateNotes,
              label: const Text('Generate AI Notes'),
              icon: const Icon(Icons.auto_awesome),
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildTranscriptTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                widget.transcript.isEmpty ? 'No text detected.' : widget.transcript,
                style: const TextStyle(fontSize: 18, height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _copyToClipboard(widget.transcript),
            icon: const Icon(Icons.copy),
            label: const Text('Copy Transcript'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          if (_generatedNotes == null && !_isGenerating && !_isDownloading)
            ElevatedButton.icon(
              onPressed: _generateNotes,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Smart Notes (Gemma 1B)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    if (_isDownloading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.download, size: 64, color: AppConstants.primaryColor),
              const SizedBox(height: 24),
              const Text(
                'AI Model Preparation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Gemma 1B is required for offline note generation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 32),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.primaryColor),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    if (_isGenerating) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text(
              'Gemma is reading your transcript...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('This happens completely offline.'),
          ],
        ),
      );
    }

    if (_generatedNotes == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No notes generated yet.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _generateNotes,
              child: const Text('Generate Now'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Markdown(
            data: _generatedNotes!,
            padding: const EdgeInsets.all(24.0),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyToClipboard(_generatedNotes!),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Notes'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.refresh),
                  label: const Text('New Record'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
