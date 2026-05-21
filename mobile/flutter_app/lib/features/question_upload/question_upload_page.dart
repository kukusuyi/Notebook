import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_exception.dart';
import '../../shared/models/common_models.dart';
import '../../shared/models/question_models.dart';
import '../../shared/utils/draft_navigation.dart';
import '../../shared/utils/platform_ui.dart';
import '../question_create/question_draft_controller.dart';
import 'file_repository.dart';
import 'question_image_crop_page.dart';
import '../question_review/question_flow_service.dart';

class QuestionUploadPage extends ConsumerStatefulWidget {
  const QuestionUploadPage({super.key});

  @override
  ConsumerState<QuestionUploadPage> createState() => _QuestionUploadPageState();
}

class _QuestionUploadPageState extends ConsumerState<QuestionUploadPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _submitting = false;
  bool _recoveringLostImage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recoverLostImage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('图片上传'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '丢弃草稿',
            onPressed: () => _confirmDiscard(),
          ),
        ],
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _submitting
                            ? null
                            : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('拍照'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _submitting
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('相册选择'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_selectedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(
                        File(_selectedImage!.path),
                        height: 280,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F1EC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text('请选择一张错题图片'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _uploadAndRecognize,
            child: Text(_submitting ? '上传并识别中...' : '上传并开始 OCR'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final draft = ref.read(questionDraftControllerProvider);
    if (hasActiveDraft(draft)) {
      final shouldReplace = await _confirmReplaceDraft(draft!);
      if (!shouldReplace) {
        return;
      }
      ref.read(questionDraftControllerProvider.notifier).clear();
    }

    final image = await _picker.pickImage(
      source: source,
      imageQuality: 92,
    );

    if (image == null) {
      return;
    }

    await _openCropper(image);
  }

  Future<void> _recoverLostImage() async {
    if (_recoveringLostImage) {
      return;
    }

    _recoveringLostImage = true;
    try {
      final response = await _picker.retrieveLostData();
      if (!mounted || response.isEmpty) {
        return;
      }

      final recoveredImage =
          response.files?.isNotEmpty == true ? response.files!.first : response.file;

      if (recoveredImage != null) {
        await _openCropper(recoveredImage);
        return;
      }

      if (response.exception != null) {
        _showMessage('拍照结果恢复失败，请重试');
      }
    } finally {
      _recoveringLostImage = false;
    }
  }

  Future<void> _openCropper(XFile image) async {
    if (!mounted) {
      return;
    }

    final croppedImage = await Navigator.of(context).push<XFile>(
      MaterialPageRoute(
        builder: (context) => QuestionImageCropPage(image: image),
      ),
    );

    if (croppedImage == null) {
      return;
    }

    setState(() {
      _selectedImage = croppedImage;
    });
  }

  Future<bool> _confirmReplaceDraft(QuestionDraft draft) async {
    final draftLabel = draft.flowMode == DraftFlowMode.upload ? '图片草稿' : '手动录入草稿';
    return showPlatformConfirmDialog(
      context: context,
      title: '替换当前草稿',
      message: '当前还有一份未完成的$draftLabel。继续拍照/选图会丢弃它，并开始新的图片草稿。',
      confirmLabel: '丢弃并继续',
      cancelLabel: '保留当前草稿',
      isDestructive: true,
    );
  }

  Future<void> _uploadAndRecognize() async {
    final selectedImage = _selectedImage;
    if (selectedImage == null) {
      _showMessage('请先选择图片');
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final uploaded = await ref
          .read(fileRepositoryProvider)
          .uploadImage(File(selectedImage.path));
      await ref
          .read(questionFlowServiceProvider)
          .recognizeUploadedImage(uploaded);

      if (mounted) {
        context.go('/questions/ocr-review');
      }
    } catch (error) {
      _showMessage(describeError(error));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _confirmDiscard() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('丢弃草稿'),
        content: const Text('确定要丢弃当前草稿吗？丢弃后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(questionDraftControllerProvider.notifier).clear();
              context.go('/dashboard');
            },
            child: const Text('确定丢弃'),
          ),
        ],
      ),
    );
  }
}
