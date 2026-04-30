import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/markdown_to_pdf_service.dart';
import 'pdf_preview_screen.dart';

const String _kSampleMarkdown = '''# Markdown to PDF 示例

这是一个把 **Markdown** 转换为 *PDF* 的演示工具。

## 功能特性

- 导入本地 `.md` 文件
- 实时预览渲染效果
- 一键转换为 PDF
- 支持中文字体

## 代码示例

```dart
void main() {
  print('Hello, Markdown!');
}
```

## 表格

| 名称 | 类型 | 说明 |
| --- | --- | --- |
| title | String | 标题 |
| count | int | 数量 |

> 引用：保持简单，专注核心功能。
''';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const String _kPrefsContentKey = 'last_markdown_content';
  static const String _kPrefsFileNameKey = 'last_file_name';

  late final TextEditingController _controller;
  late final TabController _tabController;
  String _currentFileName = 'untitled.md';
  bool _converting = false;
  bool _restored = false;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _tabController = TabController(length: 2, vsync: this);
    _controller.addListener(_scheduleSave);
    _restoreLastSession();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    // 退出前再保存一次，确保最新内容落盘
    _persistNow();
    _controller.removeListener(_scheduleSave);
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _restoreLastSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedContent = prefs.getString(_kPrefsContentKey);
      final savedName = prefs.getString(_kPrefsFileNameKey);
      if (!mounted) return;
      setState(() {
        _controller.text =
            (savedContent == null || savedContent.isEmpty)
                ? _kSampleMarkdown
                : savedContent;
        if (savedName != null && savedName.isNotEmpty) {
          _currentFileName = savedName;
        }
        _restored = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _controller.text = _kSampleMarkdown;
        _restored = true;
      });
    }
  }

  void _scheduleSave() {
    if (!_restored) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _persistNow);
  }

  Future<void> _persistNow() async {
    if (!_restored) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsContentKey, _controller.text);
      await prefs.setString(_kPrefsFileNameKey, _currentFileName);
    } catch (_) {
      // 忽略存储异常
    }
  }

  Future<void> _pickMarkdownFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'markdown', 'txt'],
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      if (picked.path == null) return;
      final file = File(picked.path!);
      final content = await file.readAsString();
      setState(() {
        _controller.text = content;
        _currentFileName = picked.name;
      });
      _persistNow();
      _showSnack('已导入：${picked.name}');
    } catch (e) {
      _showSnack('导入失败：$e');
    }
  }

  Future<void> _convertToPdf() async {
    if (_controller.text.trim().isEmpty) {
      _showSnack('内容为空，无法转换');
      return;
    }
    setState(() => _converting = true);
    try {
      final pdfBytes = await MarkdownToPdfService.convert(
        markdown: _controller.text,
        title: _baseName(_currentFileName),
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            pdfBytes: pdfBytes,
            suggestedFileName: '${_baseName(_currentFileName)}.pdf',
          ),
        ),
      );
    } catch (e) {
      _showSnack('转换失败：$e');
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  String _baseName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return name;
    return name.substring(0, dot);
  }

  Future<void> _editFileName() async {
    final controller = TextEditingController(text: _baseName(_currentFileName));
    final formKey = GlobalKey<FormState>();
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('重命名文件'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '文件名',
                hintText: '不需要输入 .md 后缀',
                suffixText: '.md',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return '文件名不能为空';
                final invalid = RegExp(r'[\\/:*?"<>|]');
                if (invalid.hasMatch(s)) return '不能包含 \\ / : * ? " < > |';
                if (s.length > 80) return '文件名过长';
                return null;
              },
              onFieldSubmitted: (_) {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(ctx).pop(controller.text.trim());
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(ctx).pop(controller.text.trim());
                }
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (newName == null || newName.isEmpty) return;
    setState(() {
      _currentFileName = newName.toLowerCase().endsWith('.md')
          ? newName
          : '$newName.md';
    });
    _persistNow();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _editFileName,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _currentFileName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.edit, size: 16),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: '导入 .md',
            icon: const Icon(Icons.file_open_outlined),
            onPressed: _pickMarkdownFile,
          ),
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() {
                _controller.clear();
                _currentFileName = 'untitled.md';
              });
              _persistNow();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note), text: '编辑'),
            Tab(icon: Icon(Icons.preview_outlined), text: '预览'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEditor(),
          _buildPreview(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _converting ? null : _convertToPdf,
        icon: _converting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.picture_as_pdf),
        label: Text(_converting ? '转换中…' : '转 PDF'),
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(fontSize: 14, height: 1.5),
        decoration: const InputDecoration(
          hintText: '在此输入或粘贴 Markdown 内容…',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final text = _controller.text;
        if (text.trim().isEmpty) {
          return const Center(child: Text('暂无预览内容'));
        }
        return Markdown(
          data: text,
          padding: const EdgeInsets.all(16),
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            code: const TextStyle(
              fontFamily: 'monospace',
              backgroundColor: Color(0xFFF1F3F4),
            ),
            codeblockDecoration: BoxDecoration(
              color: const Color(0xFFF1F3F4),
              borderRadius: BorderRadius.circular(6),
            ),
            blockquoteDecoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              border: const Border(
                left: BorderSide(color: Color(0xFFBDBDBD), width: 4),
              ),
            ),
          ),
        );
      },
    );
  }
}