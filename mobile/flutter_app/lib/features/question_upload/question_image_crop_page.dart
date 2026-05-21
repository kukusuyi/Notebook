import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class QuestionImageCropPage extends StatefulWidget {
  const QuestionImageCropPage({
    super.key,
    required this.image,
  });

  final XFile image;

  @override
  State<QuestionImageCropPage> createState() => _QuestionImageCropPageState();
}

class _QuestionImageCropPageState extends State<QuestionImageCropPage> {
  static const double _minCropEdge = 72;
  static const double _handleTouchRadius = 24;

  Size? _imageSize;
  Rect? _cropRect;
  Rect? _viewportImageRect;
  _CropDragMode? _dragMode;
  Offset? _dragAnchor;
  Rect? _dragStartRect;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  Widget build(BuildContext context) {
    final imageSize = _imageSize;

    return Scaffold(
      appBar: AppBar(
        title: const Text('框选题目区域'),
      ),
      body: imageSize == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  children: [
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final imageRect = _computeImageRect(
                              containerSize: Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              ),
                              imageSize: imageSize,
                            );
                            _viewportImageRect = imageRect;
                            _initializeCropRectIfNeeded(imageRect);
                            final cropRect = _cropRect ?? imageRect.deflate(24);

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: (details) =>
                                  _handlePanStart(details.localPosition),
                              onPanUpdate: (details) => _handlePanUpdate(
                                details.localPosition,
                                imageRect,
                              ),
                              onPanEnd: (_) => _clearDragState(),
                              onPanCancel: _clearDragState,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(color: const Color(0xFF11161A)),
                                  Positioned.fromRect(
                                    rect: imageRect,
                                    child: Image.file(
                                      File(widget.image.path),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  CustomPaint(
                                    painter: _CropOverlayPainter(
                                      imageRect: imageRect,
                                      cropRect: cropRect,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '拖动方框或四角手柄，圈定需要 OCR 的题目区域。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _resetCropRect,
                            icon: const Icon(Icons.refresh_outlined),
                            label: const Text('重置框选'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _confirmCrop,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(_saving ? '裁剪中...' : '使用当前区域'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _loadImageSize() async {
    final bytes = await File(widget.image.path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    if (!mounted) {
      return;
    }

    setState(() {
      _imageSize = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    });
  }

  void _initializeCropRectIfNeeded(Rect imageRect) {
    if (_cropRect != null) {
      return;
    }

    final horizontalInset = imageRect.width * 0.08;
    final verticalInset = imageRect.height * 0.12;
    _cropRect = Rect.fromLTRB(
      imageRect.left + horizontalInset,
      imageRect.top + verticalInset,
      imageRect.right - horizontalInset,
      imageRect.bottom - verticalInset,
    );
  }

  void _resetCropRect() {
    final imageRect = _viewportImageRect;
    if (imageRect == null) {
      return;
    }

    setState(() {
      _cropRect = null;
      _initializeCropRectIfNeeded(imageRect);
    });
  }

  void _handlePanStart(Offset position) {
    final cropRect = _cropRect;
    if (cropRect == null) {
      return;
    }

    final mode = _resolveDragMode(position, cropRect);
    if (mode == null) {
      return;
    }

    _dragMode = mode;
    _dragAnchor = position;
    _dragStartRect = cropRect;
  }

  void _handlePanUpdate(Offset position, Rect imageRect) {
    final dragMode = _dragMode;
    final dragAnchor = _dragAnchor;
    final dragStartRect = _dragStartRect;
    if (dragMode == null || dragAnchor == null || dragStartRect == null) {
      return;
    }

    final delta = position - dragAnchor;
    final nextRect = switch (dragMode) {
      _CropDragMode.move => _moveRect(dragStartRect, delta, imageRect),
      _CropDragMode.topLeft => _resizeFromTopLeft(dragStartRect, delta, imageRect),
      _CropDragMode.topRight =>
        _resizeFromTopRight(dragStartRect, delta, imageRect),
      _CropDragMode.bottomLeft =>
        _resizeFromBottomLeft(dragStartRect, delta, imageRect),
      _CropDragMode.bottomRight =>
        _resizeFromBottomRight(dragStartRect, delta, imageRect),
    };

    setState(() {
      _cropRect = nextRect;
    });
  }

  void _clearDragState() {
    _dragMode = null;
    _dragAnchor = null;
    _dragStartRect = null;
  }

  _CropDragMode? _resolveDragMode(Offset position, Rect cropRect) {
    if (_isNear(position, cropRect.topLeft)) {
      return _CropDragMode.topLeft;
    }
    if (_isNear(position, cropRect.topRight)) {
      return _CropDragMode.topRight;
    }
    if (_isNear(position, cropRect.bottomLeft)) {
      return _CropDragMode.bottomLeft;
    }
    if (_isNear(position, cropRect.bottomRight)) {
      return _CropDragMode.bottomRight;
    }
    if (cropRect.contains(position)) {
      return _CropDragMode.move;
    }
    return null;
  }

  bool _isNear(Offset point, Offset target) {
    return (point - target).distance <= _handleTouchRadius;
  }

  Rect _moveRect(Rect rect, Offset delta, Rect bounds) {
    final maxDx = bounds.right - rect.right;
    final minDx = bounds.left - rect.left;
    final maxDy = bounds.bottom - rect.bottom;
    final minDy = bounds.top - rect.top;

    final clampedDelta = Offset(
      delta.dx.clamp(minDx, maxDx).toDouble(),
      delta.dy.clamp(minDy, maxDy).toDouble(),
    );

    return rect.shift(clampedDelta);
  }

  Rect _resizeFromTopLeft(Rect rect, Offset delta, Rect bounds) {
    final left = (rect.left + delta.dx)
        .clamp(bounds.left, rect.right - _minCropEdge)
        .toDouble();
    final top = (rect.top + delta.dy)
        .clamp(bounds.top, rect.bottom - _minCropEdge)
        .toDouble();
    return Rect.fromLTRB(left, top, rect.right, rect.bottom);
  }

  Rect _resizeFromTopRight(Rect rect, Offset delta, Rect bounds) {
    final right = (rect.right + delta.dx)
        .clamp(rect.left + _minCropEdge, bounds.right)
        .toDouble();
    final top = (rect.top + delta.dy)
        .clamp(bounds.top, rect.bottom - _minCropEdge)
        .toDouble();
    return Rect.fromLTRB(rect.left, top, right, rect.bottom);
  }

  Rect _resizeFromBottomLeft(Rect rect, Offset delta, Rect bounds) {
    final left = (rect.left + delta.dx)
        .clamp(bounds.left, rect.right - _minCropEdge)
        .toDouble();
    final bottom = (rect.bottom + delta.dy)
        .clamp(rect.top + _minCropEdge, bounds.bottom)
        .toDouble();
    return Rect.fromLTRB(left, rect.top, rect.right, bottom);
  }

  Rect _resizeFromBottomRight(Rect rect, Offset delta, Rect bounds) {
    final right = (rect.right + delta.dx)
        .clamp(rect.left + _minCropEdge, bounds.right)
        .toDouble();
    final bottom = (rect.bottom + delta.dy)
        .clamp(rect.top + _minCropEdge, bounds.bottom)
        .toDouble();
    return Rect.fromLTRB(rect.left, rect.top, right, bottom);
  }

  Size _computeFittedImageSize({
    required Size containerSize,
    required Size imageSize,
  }) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    final containerAspectRatio = containerSize.width / containerSize.height;

    if (imageAspectRatio > containerAspectRatio) {
      return Size(
        containerSize.width,
        containerSize.width / imageAspectRatio,
      );
    }

    return Size(
      containerSize.height * imageAspectRatio,
      containerSize.height,
    );
  }

  Rect _computeImageRect({
    required Size containerSize,
    required Size imageSize,
  }) {
    final fittedSize = _computeFittedImageSize(
      containerSize: containerSize,
      imageSize: imageSize,
    );
    final dx = (containerSize.width - fittedSize.width) / 2;
    final dy = (containerSize.height - fittedSize.height) / 2;
    return Rect.fromLTWH(dx, dy, fittedSize.width, fittedSize.height);
  }

  Future<void> _confirmCrop() async {
    final cropRect = _cropRect;
    final imageRect = _viewportImageRect;
    if (cropRect == null || imageRect == null) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final bytes = await File(widget.image.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final originalImage = frame.image;

      final normalizedRect = Rect.fromLTRB(
        ((cropRect.left - imageRect.left) / imageRect.width)
            .clamp(0.0, 1.0)
            .toDouble(),
        ((cropRect.top - imageRect.top) / imageRect.height)
            .clamp(0.0, 1.0)
            .toDouble(),
        ((cropRect.right - imageRect.left) / imageRect.width)
            .clamp(0.0, 1.0)
            .toDouble(),
        ((cropRect.bottom - imageRect.top) / imageRect.height)
            .clamp(0.0, 1.0)
            .toDouble(),
      );

      final srcRect = Rect.fromLTRB(
        normalizedRect.left * originalImage.width,
        normalizedRect.top * originalImage.height,
        normalizedRect.right * originalImage.width,
        normalizedRect.bottom * originalImage.height,
      );

      final cropWidth = srcRect.width.round().clamp(1, originalImage.width);
      final cropHeight =
          srcRect.height.round().clamp(1, originalImage.height);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.drawImageRect(
        originalImage,
        srcRect,
        Rect.fromLTWH(0, 0, cropWidth.toDouble(), cropHeight.toDouble()),
        Paint(),
      );

      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(cropWidth, cropHeight);
      final byteData = await croppedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw StateError('裁剪后的图片生成失败');
      }

      final croppedPath = await _writeCroppedFile(byteData);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(XFile(croppedPath));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('裁剪失败，请重试')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<String> _writeCroppedFile(ByteData byteData) async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/question_crop_${DateTime.now().millisecondsSinceEpoch}.png',
    );

    await file.writeAsBytes(
      Uint8List.view(byteData.buffer),
      flush: true,
    );
    return file.path;
  }
}

enum _CropDragMode {
  move,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({
    required this.imageRect,
    required this.cropRect,
  });

  final Rect imageRect;
  final Rect cropRect;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final clearPaint = Paint()..blendMode = BlendMode.clear;

    final layerBounds = Offset.zero & size;
    canvas.saveLayer(layerBounds, Paint());
    canvas.drawRect(imageRect, overlayPaint);
    canvas.drawRect(cropRect, clearPaint);
    canvas.restore();

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(cropRect, borderPaint);

    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1;
    final thirdWidth = cropRect.width / 3;
    final thirdHeight = cropRect.height / 3;

    for (var index = 1; index <= 2; index++) {
      final dx = cropRect.left + thirdWidth * index;
      final dy = cropRect.top + thirdHeight * index;
      canvas.drawLine(
        Offset(dx, cropRect.top),
        Offset(dx, cropRect.bottom),
        guidePaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, dy),
        Offset(cropRect.right, dy),
        guidePaint,
      );
    }

    const handleRadius = 8.0;
    final handlePaint = Paint()..color = Colors.white;
    for (final point in [
      cropRect.topLeft,
      cropRect.topRight,
      cropRect.bottomLeft,
      cropRect.bottomRight,
    ]) {
      canvas.drawCircle(point, handleRadius, handlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.imageRect != imageRect || oldDelegate.cropRect != cropRect;
  }
}
