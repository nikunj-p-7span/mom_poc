import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Offline STT POC';

  // Language options
  static const Map<String, String> languages = {
    'English': 'en',
    'Hindi': 'hi',
    'Gujarati': 'gu',
  };

  // Model options
  static const String modelTiny = 'tiny';
  static const String modelBase = 'base';

  // Colors
  static const Color primaryColor = Color(0xFF6750A4);
  static const Color secondaryColor = Color(0xFF625B71);
}
