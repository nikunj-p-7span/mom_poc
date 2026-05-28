// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_gemma/flutter_gemma.dart';
// import 'package:mom_poc/utils/constants.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
//
// class GemmaService {
//   static final GemmaService _instance = GemmaService._internal();
//   factory GemmaService() => _instance;
//   GemmaService._internal();
//
//   bool _isInitialized = false;
//   bool _isModelLoaded = false;
//
//   bool get isInitialized => _isInitialized;
//   bool get isModelLoaded => _isModelLoaded;
//
//   /// Check if the Gemma model is already installed
//   Future<bool> isModelDownloaded() async {
//     // Note: FlutterGemma handles its own installation directory.
//     // Usually, we check if initialize() succeeds or if we can get the model.
//     // For simplicity, we can try to initialize and check if it throws or if we need to install.
//     return false; // We'll rely on the install flow if not sure
//   }
//
//   /// Download and Install the Gemma model using the user's preferred method
//   Future<void> downloadModel({
//     required Function(String) onProgressMessage,
//   }) async {
//     try {
//       await FlutterGemma.initialize();
//
//       onProgressMessage('Preparing download...');
//
//       final isDesktop = !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
//       final fileType = isDesktop ? ModelFileType.litertlm : ModelFileType.task;
//
//       // Use the URL and token provided by the user
//       const downloadUrl = AppConstants.gemmaModelUrl;
//       final hfToken = dotenv.env['HF_TOKEN'] ?? '';
//
//       final installer = FlutterGemma.installModel(
//         modelType: ModelType.gemmaIt,
//         fileType: fileType,
//       );
//
//       await installer
//           .fromNetwork(downloadUrl, token: hfToken)
//           .withProgress((progress) {
//             onProgressMessage('Downloading Gemma model...\n$progress% completed');
//           })
//           .install();
//
//       onProgressMessage('Loading model into memory...');
//
//       // Warm up model
//       await FlutterGemma.getActiveModel(
//         maxTokens: 1024,
//         preferredBackend: PreferredBackend.gpu,
//       );
//
//       _isModelLoaded = true;
//       _isInitialized = true;
//     } catch (e) {
//       debugPrint('[Gemma] Download/Install Error: $e');
//       rethrow;
//     }
//   }
//
//   /// Initialize the Gemma engine (without downloading)
//   Future<void> init() async {
//     if (_isInitialized && _isModelLoaded) return;
//
//     try {
//       await FlutterGemma.initialize();
//       await FlutterGemma.getActiveModel(
//         maxTokens: 1024,
//         preferredBackend: PreferredBackend.gpu,
//       );
//       _isInitialized = true;
//       _isModelLoaded = true;
//     } catch (e) {
//       _isInitialized = false;
//       _isModelLoaded = false;
//       debugPrint('[Gemma] Init failed: $e');
//       rethrow;
//     }
//   }
//
//   /// Generate meeting notes from a transcript
//   Future<String> generateMeetingNotes(String transcript) async {
//     if (!_isModelLoaded) {
//       await init();
//     }
//
//     final prompt = """
// You are an expert meeting assistant. Based on the following transcript, generate professional and concise meeting notes.
// Format the output with Markdown and include the following sections:
// 1. **Executive Summary** (A brief overview of the meeting)
// 2. **Key Discussion Points** (Bulleted list of main topics discussed)
// 3. **Action Items & Next Steps** (Clear tasks assigned to individuals)
// 4. **Decisions Made** (Key outcomes or agreements)
//
// Transcript:
// $transcript
//
// Notes:
// """;
//
//     try {
//       final model = await FlutterGemma.getActiveModel();
//       final chat = await model.createChat();
//
//       await chat.addQueryChunk(
//         Message.text(
//           text: prompt,
//           isUser: true,
//         ),
//       );
//
//       final response = await chat.generateChatResponse();
//       return (response is TextResponse)? response.token.toString() : response.toString();
//
//     } catch (e) {
//       debugPrint('[Gemma] Inference Error: $e');
//       return 'Error generating notes: $e';
//     }
//   }
// }
