import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Markdown -> PDF 转换服务
///
/// 实现思路：
/// 1) 使用 `markdown` 包将 Markdown 文本解析为 AST 节点；
/// 2) 遍历 AST 将块级节点（标题、段落、列表、引用、代码块、表格、分割线）
///    映射为 `pdf` 包的 widgets；
/// 3) 行内文本通过递归构建 `pw.RichText` 的 spans，支持加粗/斜体/行内代码/链接。
class MarkdownToPdfService {
  MarkdownToPdfService._();

  static pw.Font? _regular;
  static pw.Font? _bold;
  static pw.Font? _mono;

  static Future<void> _ensureFonts() async {
    if (_regular != null && _bold != null && _mono != null) return;
    try {
      final reg = await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');
      _regular = pw.Font.ttf(reg);
    } catch (_) {
      _regular = pw.Font.helvetica();
    }
    try {
      final bold = await rootBundle.load('assets/fonts/NotoSansSC-Bold.ttf');
      _bold = pw.Font.ttf(bold);
    } catch (_) {
      _bold = pw.Font.helveticaBold();
    }
    _mono = pw.Font.courier();
  }

  /// 替换无法被字体渲染的字符为占位符，避免 pdf 包抛出
  /// "Invalid argument (string): Contains invalid characters"。
  ///
  /// 完整的 NotoSansSC variable font 已覆盖几乎所有 CJK 常用字符，
  /// 这里仅过滤极少见的不可渲染控制字符 / 私用区字符做为兜底。
  static String _sanitize(String s) {
    final buf = StringBuffer();
    for (final rune in s.runes) {
      // 制表 / 换行 / 回车 直接保留
      if (rune == 0x09 || rune == 0x0A || rune == 0x0D) {
        buf.writeCharCode(rune);
        continue;
      }
      // 过滤其他 C0/C1 控制字符
      if (rune < 0x20 || (rune >= 0x7F && rune <= 0x9F)) {
        continue;
      }
      // 过滤 Unicode 私用区（PUA）：常见来源是某些字体的图标占位
      if ((rune >= 0xE000 && rune <= 0xF8FF) ||
          (rune >= 0xF0000 && rune <= 0xFFFFD) ||
          (rune >= 0x100000 && rune <= 0x10FFFD)) {
        buf.write('\u25A1');
        continue;
      }
      buf.writeCharCode(rune);
    }
    return buf.toString();
  }

  /// 将 [markdown] 文本转换为 PDF 字节流
  static Future<Uint8List> convert({
    required String markdown,
    String title = 'Document',
  }) async {
    await _ensureFonts();

    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubWeb,
      encodeHtml: false,
    );
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final nodes = document.parseLines(lines);

    final pdf = pw.Document(
      title: title,
      theme: pw.ThemeData.withFont(
        base: _regular!,
        bold: _bold!,
        italic: _regular!,
        boldItalic: _bold!,
      ),
    );

    final widgets = <pw.Widget>[];
    for (final node in nodes) {
      _renderBlock(node, widgets);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => widgets,
      ),
    );

    return pdf.save();
  }

  // ---------------- 块级节点渲染 ----------------

  static void _renderBlock(md.Node node, List<pw.Widget> out) {
    if (node is md.Text) {
      out.add(pw.Paragraph(text: _sanitize(node.text)));
      return;
    }
    if (node is! md.Element) return;

    switch (node.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        out.add(_heading(node));
        break;
      case 'p':
        out.add(pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.RichText(text: _inlineSpan(node.children ?? [])),
        ));
        break;
      case 'ul':
        out.add(_list(node, ordered: false));
        break;
      case 'ol':
        out.add(_list(node, ordered: true));
        break;
      case 'blockquote':
        out.add(_blockquote(node));
        break;
      case 'pre':
        out.add(_codeBlock(node));
        break;
      case 'hr':
        out.add(pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Divider(thickness: 0.6, color: PdfColors.grey400),
        ));
        break;
      case 'table':
        out.add(_table(node));
        break;
      default:
        // 其他容器：递归处理子节点
        for (final c in node.children ?? const <md.Node>[]) {
          _renderBlock(c, out);
        }
    }
  }

  static pw.Widget _heading(md.Element el) {
    final level = int.tryParse(el.tag.substring(1)) ?? 1;
    const sizes = [22.0, 19.0, 17.0, 15.0, 13.0, 12.0];
    final size = sizes[(level - 1).clamp(0, 5)];
    return pw.Padding(
      padding: pw.EdgeInsets.only(top: level <= 2 ? 14 : 10, bottom: 6),
      child: pw.RichText(
        text: _inlineSpan(
          el.children ?? [],
          base: pw.TextStyle(
            font: _bold,
            fontSize: size,
            color: PdfColors.black,
          ),
        ),
      ),
    );
  }

  static pw.Widget _list(md.Element el, {required bool ordered}) {
    final items = <pw.Widget>[];
    int idx = 1;
    for (final child in el.children ?? const <md.Node>[]) {
      if (child is! md.Element || child.tag != 'li') continue;
      final marker = ordered ? '${idx++}. ' : '• ';
      items.add(pw.Padding(
        padding: const pw.EdgeInsets.only(left: 8, top: 2, bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: ordered ? 22 : 14,
              child: pw.Text(marker),
            ),
            pw.Expanded(child: _liContent(child)),
          ],
        ),
      ));
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: items,
      ),
    );
  }

  static pw.Widget _liContent(md.Element li) {
    // li 内可能直接是 inline，也可能包含 p / 嵌套列表 / 代码块等
    final blocks = <pw.Widget>[];
    final inline = <md.Node>[];

    void flushInline() {
      if (inline.isEmpty) return;
      blocks.add(pw.RichText(text: _inlineSpan(List.of(inline))));
      inline.clear();
    }

    for (final n in li.children ?? const <md.Node>[]) {
      if (n is md.Text) {
        inline.add(n);
      } else if (n is md.Element) {
        if (_isInline(n.tag)) {
          inline.add(n);
        } else {
          flushInline();
          _renderBlock(n, blocks);
        }
      }
    }
    flushInline();

    if (blocks.length == 1) return blocks.first;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: blocks,
    );
  }

  static pw.Widget _blockquote(md.Element el) {
    final inner = <pw.Widget>[];
    for (final c in el.children ?? const <md.Node>[]) {
      _renderBlock(c, inner);
    }
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      padding: const pw.EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border(
          left: pw.BorderSide(color: PdfColors.grey400, width: 3),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: inner,
      ),
    );
  }

  static pw.Widget _codeBlock(md.Element pre) {
    String code = '';
    final code0 = (pre.children ?? const <md.Node>[]).whereType<md.Element>().firstWhere(
          (e) => e.tag == 'code',
          orElse: () => md.Element('code', []),
        );
    code = code0.textContent;
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        _sanitize(code),
        style: pw.TextStyle(font: _mono, fontSize: 10, lineSpacing: 2),
      ),
    );
  }

  static pw.Widget _table(md.Element el) {
    final rows = <List<pw.Widget>>[];
    bool isHeader = true;
    for (final section in el.children ?? const <md.Node>[]) {
      if (section is! md.Element) continue;
      for (final tr in section.children ?? const <md.Node>[]) {
        if (tr is! md.Element || tr.tag != 'tr') continue;
        final cells = <pw.Widget>[];
        for (final cell in tr.children ?? const <md.Node>[]) {
          if (cell is! md.Element) continue;
          cells.add(pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.RichText(
              text: _inlineSpan(
                cell.children ?? [],
                base: pw.TextStyle(
                  font: isHeader ? _bold : _regular,
                  fontSize: 11,
                ),
              ),
            ),
          ));
        }
        rows.add(cells);
      }
      isHeader = false;
    }
    if (rows.isEmpty) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        children: rows
            .asMap()
            .entries
            .map((e) => pw.TableRow(
                  decoration: e.key == 0
                      ? const pw.BoxDecoration(color: PdfColors.grey200)
                      : null,
                  children: e.value,
                ))
            .toList(),
      ),
    );
  }

  // ---------------- 行内节点渲染 ----------------

  static bool _isInline(String tag) {
    return tag == 'em' ||
        tag == 'strong' ||
        tag == 'code' ||
        tag == 'a' ||
        tag == 'del' ||
        tag == 'br' ||
        tag == 'img' ||
        tag == 'span';
  }

  static pw.TextSpan _inlineSpan(
    List<md.Node> nodes, {
    pw.TextStyle? base,
  }) {
    final children = <pw.InlineSpan>[];
    for (final n in nodes) {
      children.add(_nodeToSpan(n, base));
    }
    return pw.TextSpan(style: base, children: children);
  }

  static pw.InlineSpan _nodeToSpan(md.Node node, pw.TextStyle? base) {
    if (node is md.Text) {
      return pw.TextSpan(text: _sanitize(_decode(node.text)), style: base);
    }
    if (node is md.Element) {
      switch (node.tag) {
        case 'strong':
          return _inlineSpan(
            node.children ?? [],
            base: (base ?? const pw.TextStyle()).copyWith(
              font: _bold,
              fontWeight: pw.FontWeight.bold,
            ),
          );
        case 'em':
          return _inlineSpan(
            node.children ?? [],
            base: (base ?? const pw.TextStyle()).copyWith(
              fontStyle: pw.FontStyle.italic,
            ),
          );
        case 'code':
          return pw.TextSpan(
            text: _sanitize(node.textContent),
            style: (base ?? const pw.TextStyle()).copyWith(
              font: _mono,
              fontSize: 10.5,
              background: const pw.BoxDecoration(color: PdfColors.grey100),
            ),
          );
        case 'a':
          final href = node.attributes['href'] ?? '';
          final inner = _inlineSpan(
            node.children ?? [],
            base: (base ?? const pw.TextStyle()).copyWith(
              color: PdfColors.blue700,
              decoration: pw.TextDecoration.underline,
            ),
          );
          return pw.TextSpan(
            children: [inner],
            annotation: href.isEmpty ? null : pw.AnnotationUrl(href),
          );
        case 'del':
          return _inlineSpan(
            node.children ?? [],
            base: (base ?? const pw.TextStyle()).copyWith(
              decoration: pw.TextDecoration.lineThrough,
            ),
          );
        case 'br':
          return const pw.TextSpan(text: '\n');
        case 'img':
          final alt = node.attributes['alt'] ?? '图片';
          return pw.TextSpan(
            text: _sanitize('[$alt]'),
            style: (base ?? const pw.TextStyle()).copyWith(
              color: PdfColors.grey700,
              fontStyle: pw.FontStyle.italic,
            ),
          );
        default:
          return _inlineSpan(node.children ?? [], base: base);
      }
    }
    return const pw.TextSpan(text: '');
  }

  static String _decode(String s) {
    // 将常见 HTML 实体反解码（markdown 包默认不会编码，但保险起见处理一下）
    final amp = String.fromCharCode(38); // &
    final lt = String.fromCharCode(60); // <
    final gt = String.fromCharCode(62); // >
    final quot = String.fromCharCode(34); // "
    final apos = String.fromCharCode(39); // '
    return s
        .replaceAll(amp + 'lt;', lt)
        .replaceAll(amp + 'gt;', gt)
        .replaceAll(amp + 'quot;', quot)
        .replaceAll(amp + '#39;', apos)
        .replaceAll(amp + 'amp;', amp);
  }
}