import 'package:flutter/material.dart';

/// Renders the small Markdown subset returned by AHVI's text endpoints.
class BasicMarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const BasicMarkdownText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(style: style, children: _parseLines(text)),
    );
  }

  static List<InlineSpan> _parseLines(String raw) {
    final lines = raw.split('\n');
    final spans = <InlineSpan>[];
    for (var index = 0; index < lines.length; index++) {
      var line = lines[index];
      final bullet = RegExp(r'^\s*[-*]\s+').firstMatch(line);
      if (bullet != null) {
        spans.add(const TextSpan(text: '• '));
        line = line.substring(bullet.end);
      }
      spans.addAll(_parseInline(line));
      if (index < lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return spans;
  }

  static List<InlineSpan> _parseInline(String raw) {
    final spans = <InlineSpan>[];
    final markdown = RegExp(r'(\*\*[^*\n]+\*\*|\*[^*\n]+\*)');
    var cursor = 0;
    for (final match in markdown.allMatches(raw)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: raw.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      final bold = token.startsWith('**');
      spans.add(
        TextSpan(
          text: token.substring(bold ? 2 : 1, token.length - (bold ? 2 : 1)),
          style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : null,
            fontStyle: bold ? null : FontStyle.italic,
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < raw.length) spans.add(TextSpan(text: raw.substring(cursor)));
    return spans;
  }
}
