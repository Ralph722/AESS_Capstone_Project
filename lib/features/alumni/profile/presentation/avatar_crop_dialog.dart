import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Full interactive circular avatar crop modal (Facebook / Instagram style).
///
/// Lets the user pinch-to-zoom, pan, slide to zoom, and rotate their photo
/// before uploading so the circular avatar is framed exactly how they want.
class AvatarCropDialog extends StatefulWidget {
  const AvatarCropDialog({
    super.key,
    required this.imageBytes,
  });

  final Uint8List imageBytes;

  /// Convenience launcher that shows the modal and returns the cropped square JPEG bytes.
  static Future<Uint8List?> show(BuildContext context, Uint8List imageBytes) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => AvatarCropDialog(imageBytes: imageBytes),
    );
  }

  @override
  State<AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<AvatarCropDialog> {
  ui.Image? _decodedImage;
  bool _isLoading = true;
  bool _isCropping = false;
  String? _errorMessage;

  final TransformationController _transformController =
      TransformationController();

  int _quarterTurns = 0; // 0, 1, 2, 3 (each 90 degrees clockwise)
  double _currentScale = 1.0;
  static const double _minScale = 0.6;
  static const double _maxScale = 4.0;
  static const int _outputResolution = 768;

  Size _viewportSize = Size.zero;
  double _cropDiameter = 280.0;
  double _baseChildW = 0.0;
  double _baseChildH = 0.0;

  @override
  void initState() {
    super.initState();
    _decodeImage();
    _transformController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    _decodedImage?.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.01) {
      setState(() => _currentScale = scale.clamp(_minScale, _maxScale));
    }
  }

  Future<void> _decodeImage() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _decodedImage = frame.image;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load photo. Please choose another file.';
          _isLoading = false;
        });
      }
    }
  }

  void _setupInitialTransform(Size viewportSize) {
    if (_decodedImage == null || viewportSize.isEmpty) return;
    _viewportSize = viewportSize;

    final shortSide = math.min(viewportSize.width, viewportSize.height);
    _cropDiameter = (shortSide * 0.78).clamp(200.0, 360.0);

    final rawW = _decodedImage!.width.toDouble();
    final rawH = _decodedImage!.height.toDouble();
    final isFlipped = _quarterTurns % 2 == 1;
    final effW = isFlipped ? rawH : rawW;
    final effH = isFlipped ? rawW : rawH;

    // Scale child so the image fills the circular aperture at initial view
    if (effW / effH > 1.0) {
      // Landscape: height matches aperture diameter
      _baseChildH = _cropDiameter;
      _baseChildW = _cropDiameter * (effW / effH);
    } else {
      // Portrait / square: width matches aperture diameter
      _baseChildW = _cropDiameter;
      _baseChildH = _cropDiameter * (effH / effW);
    }

    final cropCenter = Offset(viewportSize.width / 2, viewportSize.height / 2);
    final initX = cropCenter.dx - (_baseChildW / 2);
    final initY = cropCenter.dy - (_baseChildH / 2);

    _transformController.value =
        Matrix4.translationValues(initX, initY, 0.0);
    _currentScale = 1.0;
  }

  void _rotateClockwise() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      if (_viewportSize != Size.zero) {
        _setupInitialTransform(_viewportSize);
      }
    });
  }

  void _resetTransform() {
    if (_viewportSize != Size.zero) {
      setState(() {
        _quarterTurns = 0;
        _setupInitialTransform(_viewportSize);
      });
    }
  }

  void _setScale(double newScale) {
    if (_viewportSize.isEmpty) return;
    final clamped = newScale.clamp(_minScale, _maxScale);
    final currentMatrix = _transformController.value;
    final oldScale = currentMatrix.getMaxScaleOnAxis();
    if (oldScale <= 0) return;

    final cropCenter = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final ratio = clamped / oldScale;

    // Scale around the center of the crop aperture
    final matrix = Matrix4.identity()
      ..multiply(Matrix4.translationValues(cropCenter.dx, cropCenter.dy, 0.0))
      ..multiply(Matrix4.diagonal3Values(ratio, ratio, 1.0))
      ..multiply(Matrix4.translationValues(-cropCenter.dx, -cropCenter.dy, 0.0))
      ..multiply(currentMatrix);

    _transformController.value = matrix;
    setState(() => _currentScale = clamped);
  }

  Future<void> _applyCrop() async {
    if (_decodedImage == null || _isCropping || _viewportSize.isEmpty) return;
    setState(() => _isCropping = true);

    try {
      final cropCenter = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
      final cropLeft = cropCenter.dx - (_cropDiameter / 2);
      final cropTop = cropCenter.dy - (_cropDiameter / 2);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Opaque white base so transparent PNGs or antialias don't create artifacts
      canvas.drawRect(
        Rect.fromLTWH(0, 0, _outputResolution.toDouble(), _outputResolution.toDouble()),
        Paint()..color = Colors.white,
      );

      // Map the screen aperture box to (0, 0, _outputResolution, _outputResolution)
      final scaleFactor = _outputResolution / _cropDiameter;
      canvas.scale(scaleFactor, scaleFactor);
      canvas.translate(-cropLeft, -cropTop);

      // Apply the user's interactive matrix transform
      canvas.transform(_transformController.value.storage);

      // Render the source image with the user's rotation and high filter quality
      final rawW = _decodedImage!.width.toDouble();
      final rawH = _decodedImage!.height.toDouble();
      final childW = _baseChildW;
      final childH = _baseChildH;

      canvas.save();
      if (_quarterTurns == 1) {
        canvas.translate(childW, 0);
        canvas.rotate(math.pi / 2);
        canvas.drawImageRect(
          _decodedImage!,
          Rect.fromLTWH(0, 0, rawW, rawH),
          Rect.fromLTWH(0, 0, childH, childW),
          Paint()..filterQuality = FilterQuality.high,
        );
      } else if (_quarterTurns == 2) {
        canvas.translate(childW, childH);
        canvas.rotate(math.pi);
        canvas.drawImageRect(
          _decodedImage!,
          Rect.fromLTWH(0, 0, rawW, rawH),
          Rect.fromLTWH(0, 0, childW, childH),
          Paint()..filterQuality = FilterQuality.high,
        );
      } else if (_quarterTurns == 3) {
        canvas.translate(0, childH);
        canvas.rotate(3 * math.pi / 2);
        canvas.drawImageRect(
          _decodedImage!,
          Rect.fromLTWH(0, 0, rawW, rawH),
          Rect.fromLTWH(0, 0, childH, childW),
          Paint()..filterQuality = FilterQuality.high,
        );
      } else {
        canvas.drawImageRect(
          _decodedImage!,
          Rect.fromLTWH(0, 0, rawW, rawH),
          Rect.fromLTWH(0, 0, childW, childH),
          Paint()..filterQuality = FilterQuality.high,
        );
      }
      canvas.restore();

      final picture = recorder.endRecording();
      final croppedUiImage = await picture.toImage(_outputResolution, _outputResolution);

      try {
        final byteData = await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          throw StateError('Could not render cropped image buffer.');
        }

        final pngBytes = byteData.buffer.asUint8List();
        final jpegBytes = await FlutterImageCompress.compressWithList(
          pngBytes,
          minWidth: _outputResolution,
          minHeight: _outputResolution,
          quality: 90,
          format: CompressFormat.jpeg,
        );

        Uint8List finalBytes;
        if (jpegBytes.isNotEmpty && ImageStorageService.isJpegBytes(jpegBytes)) {
          finalBytes = jpegBytes.length > ImageStorageService.maxUploadBytes
              ? await ImageStorageService.ensureJpegBytes(jpegBytes)
              : jpegBytes;
        } else {
          finalBytes = pngBytes;
        }

        if (mounted) {
          Navigator.of(context).pop(finalBytes);
        }
      } finally {
        croppedUiImage.dispose();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCropping = false;
          _errorMessage = 'Could not crop image. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep navy darkroom tone
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancel',
          onPressed: _isCropping ? null : () => Navigator.of(context).pop(null),
        ),
        title: const Text(
          'Crop profile photo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded),
            tooltip: 'Rotate 90°',
            onPressed: (_isLoading || _isCropping) ? null : _rotateClockwise,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Reset',
            onPressed: (_isLoading || _isCropping) ? null : _resetTransform,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: PortalTheme.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: PortalTheme.danger),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: PortalTheme.gold,
                        strokeWidth: 2.5,
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final size = Size(constraints.maxWidth, constraints.maxHeight);
                        if (_viewportSize != size) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              _setupInitialTransform(size);
                              setState(() {});
                            }
                          });
                        }

                        final cropCenter = Offset(size.width / 2, size.height / 2);
                        final apertureRect = Rect.fromCenter(
                          center: cropCenter,
                          width: _cropDiameter,
                          height: _cropDiameter,
                        );

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // Interactive image viewport (pan & pinch-zoom)
                            InteractiveViewer(
                              transformationController: _transformController,
                              minScale: _minScale,
                              maxScale: _maxScale,
                              boundaryMargin: EdgeInsets.all(_cropDiameter),
                              clipBehavior: Clip.none,
                              child: SizedBox(
                                width: _baseChildW,
                                height: _baseChildH,
                                child: _decodedImage == null
                                    ? const SizedBox.shrink()
                                    : RotatedBox(
                                        quarterTurns: _quarterTurns,
                                        child: RawImage(
                                          image: _decodedImage,
                                          fit: BoxFit.fill,
                                          filterQuality: FilterQuality.medium,
                                        ),
                                      ),
                              ),
                            ),
                            // Circular aperture vignette overlay
                            IgnorePointer(
                              child: CustomPaint(
                                size: size,
                                painter: _CropAperturePainter(
                                  apertureRect: apertureRect,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            // Helper instruction banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: Text(
                'Drag to reposition · Pinch or slide to zoom',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Zoom slider toolbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    color: Colors.white70,
                    tooltip: 'Zoom out',
                    onPressed: (_isLoading || _isCropping)
                        ? null
                        : () => _setScale(_currentScale - 0.2),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: PortalTheme.gold,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: PortalTheme.gold,
                        overlayColor: PortalTheme.gold.withValues(alpha: 0.2),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: _currentScale.clamp(_minScale, _maxScale),
                        min: _minScale,
                        max: _maxScale,
                        onChanged: (_isLoading || _isCropping)
                            ? null
                            : (v) => _setScale(v),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    color: Colors.white70,
                    tooltip: 'Zoom in',
                    onPressed: (_isLoading || _isCropping)
                        ? null
                        : () => _setScale(_currentScale + 0.2),
                  ),
                ],
              ),
            ),
            // Bottom action buttons
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF1E293B)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isCropping
                          ? null
                          : () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: (_isLoading || _isCropping) ? null : _applyCrop,
                      style: FilledButton.styleFrom(
                        backgroundColor: PortalTheme.navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: PortalTheme.gold, width: 1.5),
                        ),
                      ),
                      child: _isCropping
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Photo',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the darkened vignette around the circle and guideline rings.
class _CropAperturePainter extends CustomPainter {
  const _CropAperturePainter({required this.apertureRect});

  final Rect apertureRect;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark vignette scrim outside the circular aperture
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final circlePath = Path()..addOval(apertureRect);
    final overlayPath = Path.combine(PathOperation.difference, backgroundPath, circlePath);

    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.68)
      ..style = PaintingStyle.fill;
    canvas.drawPath(overlayPath, overlayPaint);

    // 2. Crisp circle border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawOval(apertureRect, borderPaint);

    // 3. Subtle inner rule-of-thirds grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final left = apertureRect.left;
    final top = apertureRect.top;
    final w = apertureRect.width;
    final h = apertureRect.height;

    // Clip grid lines to inside circle
    canvas.save();
    canvas.clipPath(circlePath);

    // Vertical third lines
    canvas.drawLine(Offset(left + w / 3, top), Offset(left + w / 3, top + h), gridPaint);
    canvas.drawLine(Offset(left + 2 * w / 3, top), Offset(left + 2 * w / 3, top + h), gridPaint);

    // Horizontal third lines
    canvas.drawLine(Offset(left, top + h / 3), Offset(left + w, top + h / 3), gridPaint);
    canvas.drawLine(Offset(left, top + 2 * h / 3), Offset(left + w, top + 2 * h / 3), gridPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CropAperturePainter oldDelegate) {
    return oldDelegate.apertureRect != apertureRect;
  }
}
