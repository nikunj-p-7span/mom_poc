import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mom_poc/utils/constants.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ResultScreen extends StatefulWidget {
  final String transcript;

  const ResultScreen({super.key, required this.transcript});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _apiKey = dotenv.env['OPEN_AI_KEY'] ?? '';

  String? _generatedNotes;
  bool _isGenerating = false;

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
    _tabController.animateTo(1); // Switch to AI Notes tab immediately

    if (_apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter an OpenAI API Key.')),
        );
      }
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      OpenAI.apiKey = _apiKey;

      final prompt = """
You are an expert meeting assistant. Based on the following transcript, generate professional and concise meeting notes.
Format the output with Markdown and include the following sections:
1. **Executive Summary** (A brief overview of the meeting)
2. **Key Discussion Points** (Bulleted list of main topics discussed)
3. **Action Items & Next Steps** (Clear tasks assigned to individuals)
4. **Decisions Made** (Key outcomes or agreements)

Transcript:
${widget.transcript}
""";

      final chatCompletion = await OpenAI.instance.chat.create(
        model: "gpt-4o",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
            ],
            role: OpenAIChatMessageRole.user,
          ),
        ],
      );

      final notes = chatCompletion.choices.first.message.content?.first.text ?? 'No notes generated.';

      setState(() {
        _generatedNotes = notes;
      });
    } catch (e) {
      if (mounted) {
        debugPrint('${e.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating notes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
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
          if (_generatedNotes == null && !_isGenerating)
            ElevatedButton.icon(
              onPressed: _generateNotes,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Smart Notes'),
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
    if (_isGenerating) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text(
              'OpenAI is reading your transcript...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('This happens online.'),
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
