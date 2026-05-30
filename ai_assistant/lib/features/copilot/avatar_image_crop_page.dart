import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/storage/app_paths.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_controls.dart';

class AvatarImageCropPage extends StatefulWidget {
  final String imagePath;

  const AvatarImageCropPage({super.key, required this.imagePath});

  @override
  State<AvatarImageCropPage> createState() => _AvatarImageCropPageState();
}

class _AvatarImageCropPageState extends State<AvatarImageCropPage> {
  static const _outputSize = 512;
  ui.Image? _image;
  String? _error;
  bool _saving = false;

  double _scale = 1;
  double _minScale = 1;
  Offset _offset = Offset.zero;
  double _startScale = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;
  double _lastViewportSize = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final image = await _decodeImage(bytes);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _image = image;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '图片无法读取：$e');
    }
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  void _ensureTransform(double size) {
    final image = _image;
    if (image == null || size <= 0) return;
    if (_lastViewportSize == size) return;
    _lastViewportSize = size;
    _minScale = math.max(size / image.width, size / image.height);
    _scale = _minScale;
    _offset = Offset(
      (size - image.width * _scale) / 2,
      (size - image.height * _scale) / 2,
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startScale = _scale;
    _startOffset = _offset;
    _startFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double viewportSize) {
    final image = _image;
    if (image == null) return;
    final nextScale = (_startScale * details.scale).clamp(
      _minScale,
      _minScale * 5,
    );
    final focalDelta = details.localFocalPoint - _startFocal;
    final focal = _startFocal;
    final scaleRatio = nextScale / _startScale;
    final scaledOffset = focal - (focal - _startOffset) * scaleRatio;
    final nextOffset = scaledOffset + focalDelta;
    setState(() {
      _scale = nextScale;
      _offset = _clampOffset(
        nextOffset,
        viewportSize,
        image.width * _scale,
        image.height * _scale,
      );
    });
  }

  Offset _clampOffset(
    Offset value,
    double viewportSize,
    double imageWidth,
    double imageHeight,
  ) {
    final dx = imageWidth <= viewportSize
        ? (viewportSize - imageWidth) / 2
        : value.dx.clamp(viewportSize - imageWidth, 0.0);
    final dy = imageHeight <= viewportSize
        ? (viewportSize - imageHeight) / 2
        : value.dy.clamp(viewportSize - imageHeight, 0.0);
    return Offset(dx.toDouble(), dy.toDouble());
  }

  Future<void> _saveCropped() async {
    final image = _image;
    if (image == null || _saving) return;
    setState(() => _saving = true);
    try {
      final src = Rect.fromLTWH(
        _cropLeft(image),
        _cropTop(image),
        _cropSide(image),
        _cropSide(image),
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, _outputSize.toDouble(), _outputSize.toDouble()),
      );
      final paint = Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;
      canvas.drawColor(Colors.transparent, BlendMode.src);
      canvas.drawImageRect(
        image,
        src,
        Rect.fromLTWH(0, 0, _outputSize.toDouble(), _outputSize.toDouble()),
        paint,
      );
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(_outputSize, _outputSize);
      final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      cropped.dispose();
      if (byteData == null) throw StateError('裁剪图片生成失败');

      final support = await getAppSupportDirectory();
      final dir = Directory('${support.path}/avatars');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File(
        '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      Navigator.of(context).pop(file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('裁剪头像')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableSize = math.min(
              constraints.maxWidth - 40,
              constraints.maxHeight.isFinite
                  ? math.min(constraints.maxHeight * 0.58, 420)
                  : 420,
            );
            final viewportSize = availableSize.clamp(220.0, 420.0).toDouble();
            _ensureTransform(viewportSize);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Text(
                  '拖动或双指缩放图片，方框内内容会保存为方形头像。',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: _CropViewport(
                    size: viewportSize,
                    image: _image,
                    scale: _scale,
                    offset: _offset,
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: (details) =>
                        _onScaleUpdate(details, viewportSize),
                  ),
                ),
                const SizedBox(height: 18),
                if (_error != null) ...[
                  _ErrorBox(text: _error!),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    Expanded(
                      child: AppDialogActionButton(
                        label: '取消',
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        tone: AppActionButtonTone.neutral,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppDialogActionButton(
                        label: _saving ? '保存中' : '保存头像',
                        onPressed: _image == null || _saving
                            ? null
                            : _saveCropped,
                        icon: Icons.crop_square_rounded,
                        filled: true,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _cropSide(ui.Image image) {
    return (_lastViewportSize / _scale).clamp(
      1.0,
      math.min(image.width, image.height).toDouble(),
    );
  }

  double _cropLeft(ui.Image image) {
    final side = _cropSide(image);
    return (-_offset.dx / _scale).clamp(0.0, image.width - side);
  }

  double _cropTop(ui.Image image) {
    final side = _cropSide(image);
    return (-_offset.dy / _scale).clamp(0.0, image.height - side);
  }
}

class _CropViewport extends StatelessWidget {
  final double size;
  final ui.Image? image;
  final double scale;
  final Offset offset;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;

  const _CropViewport({
    required this.size,
    required this.image,
    required this.scale,
    required this.offset,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.52)),
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onScaleStart: onScaleStart,
              onScaleUpdate: onScaleUpdate,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _CropPainter(
                      image: image!,
                      scale: scale,
                      offset: offset,
                    ),
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.84),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _CropPainter extends CustomPainter {
  final ui.Image image;
  final double scale;
  final Offset offset;

  const _CropPainter({
    required this.image,
    required this.scale,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    canvas.drawImage(image, Offset.zero, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.scale != scale ||
        oldDelegate.offset != offset;
  }
}

class _ErrorBox extends StatelessWidget {
  final String text;

  const _ErrorBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.4,
          color: AppColors.danger,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
