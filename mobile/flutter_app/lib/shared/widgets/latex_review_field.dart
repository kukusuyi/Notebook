import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'latex_block.dart';

class LatexReviewField extends StatefulWidget {
  const LatexReviewField({
    super.key,
    required this.title,
    required this.controller,
    required this.onChanged,
    this.placeholder = '',
    this.emptyPreviewText = '暂无内容',
    this.minLines = 3,
    this.maxLines = 6,
  });

  final String title;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final String emptyPreviewText;
  final int minLines;
  final int maxLines;

  @override
  State<LatexReviewField> createState() => _LatexReviewFieldState();
}

class _LatexReviewFieldState extends State<LatexReviewField> {
  _LatexFieldMode _mode = _LatexFieldMode.preview;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant LatexReviewField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }

    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.controller.text.trim();
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            IconButton(
              tooltip: '复制源码',
              onPressed: content.isEmpty ? null : () => _copySource(context),
              icon: const Icon(Icons.copy_all_outlined),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<_LatexFieldMode>(
          segments: const [
            ButtonSegment(
              value: _LatexFieldMode.preview,
              icon: Icon(Icons.visibility_outlined),
              label: Text('原题预览'),
            ),
            ButtonSegment(
              value: _LatexFieldMode.source,
              icon: Icon(Icons.code_outlined),
              label: Text('源码编辑'),
            ),
          ],
          selected: <_LatexFieldMode>{_mode},
          onSelectionChanged: (value) {
            setState(() {
              _mode = value.first;
            });
          },
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _mode == _LatexFieldMode.source
              ? TextFormField(
                  key: const ValueKey('source'),
                  controller: widget.controller,
                  minLines: widget.minLines,
                  maxLines: widget.maxLines,
                  decoration: InputDecoration(
                    hintText: widget.placeholder,
                    alignLabelWithHint: true,
                  ),
                  onChanged: widget.onChanged,
                )
              : Container(
                  key: const ValueKey('preview'),
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 120),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: content.isEmpty
                      ? Text(
                          widget.emptyPreviewText,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: onSurfaceVariant,
                              ),
                        )
                      : LatexBlock(content),
                ),
        ),
      ],
    );
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _copySource(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.controller.text));
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('源码已复制')),
    );
  }
}

enum _LatexFieldMode {
  preview,
  source,
}
