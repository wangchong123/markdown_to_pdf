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
      ),
      home: const HomeScreen(),
    );
  }
}