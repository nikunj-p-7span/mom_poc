import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Offline STT POC';

  // Model options
  static const String modelTiny = 'tiny';
  static const String modelBase = 'base';

  // Colors
  static const Color primaryColor = Color(0xFF6750A4);
  static const Color secondaryColor = Color(0xFF625B71);

  // Gemma LLM
  static const String gemmaModelUrl = 'https://huggingface.co/AfiOne/gemma3-1b-it-int4.task/resolve/main/gemma3-1b-it-int4.task';
  static const String gemmaModelFileName = 'gemma3-1b-it-int4.task';
}
