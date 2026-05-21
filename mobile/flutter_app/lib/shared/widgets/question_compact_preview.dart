import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

final RegExp _questionFormulaPattern = RegExp(
  r'(\\\[[\s\S]+?\\\]|\\\([\s\S]+?\\\)|\$\$[\s\S]+?\$\$|\$[^$\n]+\$)',
);
final RegExp _questionMathSignalPattern = RegExp(
  r'\\[a-zA-Z]+|[_^=<>]|(?:[A-Za-z0-9)][+\-*/][A-Za-z0-9(])',
);

class QuestionCompactPreview extends StatelessWidget {
  const QuestionCompactPreview({
    super.key,
    required this.content,
    this.previewHeight = 76,
    this.formulaLineHeight = 36,
    this.textStyle,
  });

  final String content;
  final double previewHeight;
  final double formulaLineHeight;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final preview = _buildQuestionPreview(content);
    final resolvedTextStyle =
        textStyle ?? Theme.of(context).textTheme.bodyLarge;

    return SizedBox(
      height: previewHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview.textLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolvedTextStyle,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: formulaLineHeight,
            child: preview.formulaLine == null
                ? const SizedBox.shrink()
                : ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: 0,
                      maxWidth: double.infinity,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: Math.tex(
                        preview.formulaLine!,
                        mathStyle: MathStyle.text,
                        textStyle: resolvedTextStyle,
                        onErrorFallback: (error) => Text(
                          preview.formulaFallbackText ?? preview.formulaLine!,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: resolvedTextStyle,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _QuestionPreviewData {
  const _QuestionPreviewData({
    required this.textLine,
    this.formulaLine,
    this.formulaFallbackText,
  });

  final String textLine;
  final String? formulaLine;
  final String? formulaFallbackText;
}

_QuestionPreviewData _buildQuestionPreview(String raw) {
  final normalized =
      raw.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return const _QuestionPreviewData(textLine: '暂无内容');
  }

  final firstFormulaMatch = _questionFormulaPattern.firstMatch(normalized);
  if (firstFormulaMatch != null) {
    final formulaRaw = firstFormulaMatch.group(0) ?? '';
    final textLine = normalized
        .replaceAll(_questionFormulaPattern, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final formulaText = _stripFormulaDelimiters(formulaRaw);
    return _QuestionPreviewData(
      textLine: textLine.isEmpty ? '公式题' : textLine,
      formulaLine: formulaText,
      formulaFallbackText: formulaText,
    );
  }

  if (_questionMathSignalPattern.hasMatch(normalized)) {
    return _QuestionPreviewData(
      textLine: '公式题',
      formulaLine: normalized,
      formulaFallbackText: normalized,
    );
  }

  return _QuestionPreviewData(textLine: normalized);
}

String _stripFormulaDelimiters(String raw) {
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
  return raw.trim();
}
