import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

final RegExp _rawLatexCommandPattern = RegExp(r'\\[a-zA-Z]+');
final RegExp _explicitLatexDelimiterPattern = RegExp(
  r'(\\\[[\s\S]+?\\\]|\\\([\s\S]+?\\\)|\$\$[\s\S]+?\$\$|\$[^$\n]+\$)',
);
final RegExp _optionPrefixPattern =
    RegExp(r'^([A-Za-z]\s*[.、)|]|[0-9]+\s*[.、)])\s+');
final RegExp _mathDominantPattern =
    RegExp(r"^[A-Za-z0-9\s\\{}[\]()_^|=+\-*/<>,.:;'`~!?%&]+$");
final RegExp _cjkPattern = RegExp(r'[\u3400-\u9fff]');
final RegExp _cjkSeparatorPattern =
    RegExp(r'([\u3400-\u9fff\u3000-\u303f\uff00-\uffef])');
final RegExp _mathSignalPattern = RegExp(
  r'\\[a-zA-Z]+|[_^=<>]|(?:\b[a-zA-Z]+\s*\([^)]*\))|(?:[A-Za-z0-9)][+\-*/][A-Za-z0-9(])',
);

class LatexBlock extends StatelessWidget {
  const LatexBlock(
    this.content, {
    super.key,
    this.allowHorizontalScroll = true,
    this.selectableText = true,
  });

  final String content;
  final bool allowHorizontalScroll;
  final bool selectableText;

  @override
  Widget build(BuildContext context) {
    final value = content.trim();
    if (value.isEmpty) {
      return const Text('暂无内容');
    }

    final normalizedValue = _normalizeLatexContent(value);
    final segments = _parseSegments(normalizedValue);
    final hasMath = segments.any((segment) => segment.isMath);
    if (!hasMath) {
      return selectableText
          ? SelectableText(normalizedValue)
          : Text(normalizedValue);
    }

    final lines = normalizedValue.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < lines.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          _LatexLine(
            content: lines[index],
            textStyle: Theme.of(context).textTheme.bodyLarge,
            allowHorizontalScroll: allowHorizontalScroll,
          ),
        ],
      ],
    );
  }
}

class _LatexLine extends StatelessWidget {
  const _LatexLine({
    required this.content,
    required this.textStyle,
    required this.allowHorizontalScroll,
  });

  final String content;
  final TextStyle? textStyle;
  final bool allowHorizontalScroll;

  @override
  Widget build(BuildContext context) {
    final segments = _parseSegments(content);
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }

    if (!allowHorizontalScroll) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Wrap(
            spacing: 4,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final segment in segments)
                if (segment.isMath)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Math.tex(
                        segment.value,
                        textStyle: textStyle,
                        onErrorFallback: (error) => Text(
                          segment.raw,
                          style: textStyle,
                        ),
                      ),
                    ),
                  )
                else if (segment.value.isNotEmpty)
                  Text(
                    segment.value,
                    style: textStyle,
                  ),
            ],
          );
        },
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: 4,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final segment in segments)
            if (segment.isMath)
              Math.tex(
                segment.value,
                textStyle: textStyle,
                onErrorFallback: (error) => Text(
                  segment.raw,
                  style: textStyle,
                ),
              )
            else if (segment.value.isNotEmpty)
              Text(
                segment.value,
                style: textStyle,
              ),
        ],
      ),
    );
  }
}

class _LatexSegment {
  const _LatexSegment({
    required this.value,
    required this.raw,
    required this.isMath,
  });

  final String value;
  final String raw;
  final bool isMath;
}

List<_LatexSegment> _parseSegments(String content) {
  final pattern = RegExp(
    r'(\\\[[\s\S]+?\\\]|\\\([\s\S]+?\\\)|\$\$[\s\S]+?\$\$|\$[^$\n]+\$)',
  );
  final matches = pattern.allMatches(content).toList();
  if (matches.isEmpty) {
    return [
      _LatexSegment(
        value: content,
        raw: content,
        isMath: false,
      ),
    ];
  }

  final segments = <_LatexSegment>[];
  var cursor = 0;

  for (final match in matches) {
    if (match.start > cursor) {
      final text = content.substring(cursor, match.start);
      segments.add(
        _LatexSegment(
          value: text,
          raw: text,
          isMath: false,
        ),
      );
    }

    final raw = match.group(0) ?? '';
    segments.add(
      _LatexSegment(
        value: _stripDelimiters(raw),
        raw: raw,
        isMath: true,
      ),
    );
    cursor = match.end;
  }

  if (cursor < content.length) {
    final text = content.substring(cursor);
    segments.add(
      _LatexSegment(
        value: text,
        raw: text,
        isMath: false,
      ),
    );
  }

  return segments;
}

String _stripDelimiters(String raw) {
  if (raw.startsWith(r'\[') && raw.endsWith(r'\]')) {
    return raw.substring(2, raw.length - 2).trim();
  }
  if (raw.startsWith(r'\(') && raw.endsWith(r'\)')) {
    return raw.substring(2, raw.length - 2).trim();
  }
  if (raw.startsWith(r'$$') && raw.endsWith(r'$$')) {
    return raw.substring(2, raw.length - 2).trim();
  }
  if (raw.startsWith(r'$') && raw.endsWith(r'$')) {
    return raw.substring(1, raw.length - 1).trim();
  }
  return raw;
}

String _normalizeLatexContent(String content) {
  return content.split('\n').map(_wrapRawLatexLine).join('\n');
}

String _wrapRawLatexLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return line;
  }

  final leadingWhitespace = RegExp(r'^\s*').firstMatch(line)?.group(0) ?? '';
  final optionPrefix = _optionPrefixPattern.firstMatch(trimmed)?.group(0) ?? '';
  final body = trimmed.substring(optionPrefix.length).trim();

  if (body.isNotEmpty &&
      !_containsExplicitLatexDelimiters(trimmed) &&
      _isMathDominantLine(body) &&
      (_rawLatexCommandPattern.hasMatch(body) ||
          _mathSignalPattern.hasMatch(body))) {
    return '$leadingWhitespace$optionPrefix\\($body\\)';
  }

  return _wrapInlineRawLatex(line);
}

String _wrapInlineRawLatex(String line) {
  final buffer = StringBuffer();
  var cursor = 0;

  for (final match in _explicitLatexDelimiterPattern.allMatches(line)) {
    final start = match.start;
    if (start > cursor) {
      buffer.write(_wrapPlainTextSegment(line.substring(cursor, start)));
    }
    buffer.write(match.group(0) ?? '');
    cursor = match.end;
  }

  if (cursor < line.length) {
    buffer.write(_wrapPlainTextSegment(line.substring(cursor)));
  }

  return buffer.toString();
}

String _wrapPlainTextSegment(String segment) {
  final pieces = <String>[];
  var cursor = 0;

  for (final match in _cjkSeparatorPattern.allMatches(segment)) {
    final start = match.start;
    if (start > cursor) {
      pieces.add(_wrapChunkIfNeeded(segment.substring(cursor, start)));
    }
    pieces.add(match.group(0) ?? '');
    cursor = match.end;
  }

  if (cursor < segment.length) {
    pieces.add(_wrapChunkIfNeeded(segment.substring(cursor)));
  }

  return pieces.join();
}

String _wrapChunkIfNeeded(String chunk) {
  if (!_shouldWrapRawMathChunk(chunk)) {
    return chunk;
  }

  final leadingWhitespace = RegExp(r'^\s*').firstMatch(chunk)?.group(0) ?? '';
  final trailingWhitespace = RegExp(r'\s*$').firstMatch(chunk)?.group(0) ?? '';
  final trimmed = chunk.trim();
  return '$leadingWhitespace\\($trimmed\\)$trailingWhitespace';
}

bool _shouldWrapRawMathChunk(String chunk) {
  final trimmed = chunk.trim();
  if (trimmed.isEmpty || _containsExplicitLatexDelimiters(trimmed)) {
    return false;
  }

  return _rawLatexCommandPattern.hasMatch(trimmed) ||
      _mathSignalPattern.hasMatch(trimmed);
}

bool _containsExplicitLatexDelimiters(String line) {
  return _explicitLatexDelimiterPattern.hasMatch(line);
}

bool _isMathDominantLine(String line) {
  return _mathDominantPattern.hasMatch(line) && !_cjkPattern.hasMatch(line);
}
