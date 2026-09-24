import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_exception.dart';
import '../../features/question_review/ai_repository.dart';
import '../../features/question_upload/file_repository.dart';
import '../../features/question_upload/question_image_crop_page.dart';

/// Uses its own image and result: never replaces the question draft or source image.
class SolutionOcrButton extends StatelessWidget {
  const SolutionOcrButton(
      {super.key, required this.controller, this.onApplied});
  final TextEditingController controller;
  final VoidCallback? onApplied;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.document_scanner_outlined),
          label: const Text('拍照 / 图片识别答案步骤'),
          onPressed: () async {
            final result = await Navigator.of(context).push<_SolutionResult>(
              MaterialPageRoute(builder: (_) => const _SolutionOcrPage()),
            );
            if (result == null || !context.mounted) return;
            if (result.replace && controller.text.trim().isNotEmpty) {
              final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                        title: const Text('替换答案'),
                        content: const Text('将用核对后的识别文字替换当前标准答案。'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('取消')),
                          FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('替换'))
                        ],
                      ));
              if (confirmed != true || !context.mounted) return;
            }
            controller.text =
                !result.replace && controller.text.trim().isNotEmpty
                    ? '${controller.text.trim()}\n\n${result.text}'
                    : result.text;
            onApplied?.call();
          },
        ),
      );
}

class _SolutionResult {
  const _SolutionResult(this.text, this.replace);
  final String text;
  final bool replace;
}

class _SolutionOcrPage extends ConsumerStatefulWidget {
  const _SolutionOcrPage();
  @override
  ConsumerState<_SolutionOcrPage> createState() => _SolutionOcrPageState();
}

class _SolutionOcrPageState extends ConsumerState<_SolutionOcrPage> {
  final _result = TextEditingController();
  XFile? _image;
  bool _busy = false;
  String? _error;
  String? _warning;
  @override
  void dispose() {
    _result.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final image =
          await ImagePicker().pickImage(source: source, imageQuality: 92);
      if (image == null || !mounted) return;
      final cropped = await Navigator.of(context).push<XFile>(MaterialPageRoute(
          builder: (_) => QuestionImageCropPage(image: image)));
      if (cropped != null && mounted) {
        setState(() {
          _image = cropped;
          _result.clear();
          _warning = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = describeError(e, fallback: '无法读取照片，请检查相机或相册权限后重试。');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _recognize() async {
    if (_busy || _image == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final image = await ref
          .read(fileRepositoryProvider)
          .uploadImage(File(_image!.path));
      final response = await ref
          .read(aiRepositoryProvider)
          .recognizeWrongQuestion(
              imageUrl: image.imageUrl,
              imageId: image.imageId,
              purpose: 'solution');
      if (!mounted) return;
      setState(() {
        _result.text = response.questionJson.standardSolution;
        _warning = response.ocrContext.uncertainParts.isEmpty
            ? null
            : response.ocrContext.uncertainParts.join('；');
        if (_result.text.trim().isEmpty) _error = '未识别到答案文字，请裁剪答案区域后重试，或手动填写。';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = describeError(e, fallback: '答案识别失败，请重试或手动填写。');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(
              title: const Text('识别答案步骤'), automaticallyImplyLeading: !_busy),
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text('仅抄录图片中的答案与步骤，不解题、不改写题目。核对后再应用。'),
                          const SizedBox(height: 16),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _pick(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt_outlined),
                                label: const Text('拍照')),
                            OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _pick(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text('选择图片')),
                          ]),
                          if (_image != null)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Image.file(File(_image!.path),
                                    height: 220, fit: BoxFit.contain)),
                          FilledButton.tonal(
                              onPressed:
                                  _busy || _image == null ? null : _recognize,
                              child: Text(_busy ? '正在处理…' : '识别答案文字')),
                          if (_busy) const LinearProgressIndicator(),
                          if (_error != null)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text(_error!,
                                    semanticsLabel: '错误：$_error')),
                          if (_warning != null) Text(_warning!),
                          const SizedBox(height: 16),
                          TextField(
                              controller: _result,
                              minLines: 6,
                              maxLines: 16,
                              enabled: !_busy,
                              decoration:
                                  const InputDecoration(labelText: '核对答案识别结果'),
                              onChanged: (_) => setState(() {})),
                          const SizedBox(height: 16),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            OutlinedButton(
                                onPressed: _busy || _result.text.trim().isEmpty
                                    ? null
                                    : () => Navigator.pop(
                                        context,
                                        _SolutionResult(
                                            _result.text.trim(), true)),
                                child: const Text('替换原答案')),
                            FilledButton(
                                onPressed: _busy || _result.text.trim().isEmpty
                                    ? null
                                    : () => Navigator.pop(
                                        context,
                                        _SolutionResult(
                                            _result.text.trim(), false)),
                                child: const Text('追加 / 应用答案')),
                          ]),
                        ],
                      )))),
        ),
      );
}
