import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const MarkdownToPdfApp());
}

class MarkdownToPdfApp extends StatelessWidget {
  const MarkdownToPdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Markdown to PDF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'NotoSansSC',
        // NotoSansSC variable font 默认字重偏细，统一加深正文颜色并加重字重
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            color: Color(0xFF1F1F1F),
            fontWeight: FontWeight.w500,
          ),
          bodyMedium: TextStyle(
            color: Color(0xFF1F1F1F),
            fontWeight: FontWeight.w500,
          ),
          bodySmall: TextStyle(
            color: Color(0xFF1F1F1F),
            fontWeight: FontWeight.w500,
          ),
          titleLarge: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w600,
          ),
          titleSmall: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w600,
          ),
          labelLarge: TextStyle(
            color: Color(0xFF1F1F1F),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}