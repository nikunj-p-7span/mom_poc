import 'package:flutter/material.dart';
import 'package:mom_poc/screens/home_screen.dart';
import 'package:mom_poc/screens/record_screen.dart';
import 'package:mom_poc/utils/constants.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const WhisperApp());
}

class WhisperApp extends StatelessWidget {
  const WhisperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primaryColor,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      // home: const HomeScreen(),
      home: const RecordScreen(),
    );
  }
}
