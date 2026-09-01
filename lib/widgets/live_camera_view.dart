import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/kiosk_theme.dart';
import '../services/face_detector_service.dart';
import 'radar_scan_overlay.dart';

typedef FaceDetectedCallback = void Function(DetectedFaceInfo faceInfo);

/// Widget hiển thị luồng Camera thực tế trên thiết bị
/// - Tự động xin quyền Camera (Runtime Permission Request).
/// - Tự động mở Camera trước (Front Camera) với ImageFormatGroup.nv21.
/// - Nhận diện khuôn mặt tự động thời gian thực qua Google ML Kit.
/// - Trích xuất đặc trưng MobileFaceNet 192-d và kích hoạt cấp giấy không cần chạm.
class LiveCameraView extends StatefulWidget {
  final bool isFaceDetected;
  final String statusText;
  final Color activeColor;
  final FaceDetectedCallback? onRealFaceDetected;
  final void Function(DetectedFaceInfo faceInfo)? onFaceTrackingUpdate;

  const LiveCameraView({
    super.key,
    required this.isFaceDetected,
    required this.statusText,
    required this.activeColor,
    this.onRealFaceDetected,
    this.onFaceTrackingUpdate,
  });

  @override
  State<LiveCameraView> createState() => _LiveCameraViewState();
}

class _LiveCameraViewState extends State<LiveCameraView>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  CameraDescription? _activeCamera;
  FaceDetectorService? _faceDetectorService;

  bool _isCameraInitialized = false;
  bool _hasPermission = false;
  String? _permissionError;
  bool _isProcessingFrame = false;
  DateTime _lastProcessedTime = DateTime.now();
  Rect? _detectedFaceRect;
  DetectedFaceInfo? _detectedFaceInfo;
  Size? _cameraPreviewSize;
  String _mlStatus = 'AI Google ML Kit: Đang quét...';
  int _consecutiveFaceHits = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _faceDetectorService = FaceDetectorService();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _pulseController.repeat(reverse: true);
    }

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initCameraFlow();
  }

  Future<void> _initCameraFlow() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      // 1. Xin quyền Camera
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _hasPermission = false;
            _permissionError = 'Chưa cấp quyền truy cập Camera';
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _hasPermission = true;
          _permissionError = null;
        });
      }

      // 2. Tìm camera trước
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _isCameraInitialized = false);
        return;
      }

      _activeCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        _activeCamera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: (!kIsWeb && Platform.isAndroid)
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      final preview = _cameraController!.value.previewSize;
      if (preview != null) {
        if (!kIsWeb && Platform.isAndroid) {
          _cameraPreviewSize = Size(preview.height, preview.width);
        } else {
          _cameraPreviewSize = Size(preview.width, preview.height);
        }
      }

      // 3. Khởi chạy luồng phân tích hình ảnh AI theo thời gian thực
      await _cameraController!.startImageStream(_handleCameraFrame);

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _mlStatus = 'AI Google ML Kit: Đang tìm khuôn mặt...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _permissionError = e.toString();
        });
      }
    }
  }

  /// Phân tích từng frame hình ảnh từ Camera
  void _handleCameraFrame(CameraImage image) async {
    if (_isProcessingFrame || _activeCamera == null || !mounted) return;

    // Giới hạn chu kỳ phân tích 180ms để đảm bảo mượt mà 60 FPS
    final now = DateTime.now();
    if (now.difference(_lastProcessedTime).inMilliseconds < 180) return;
    _lastProcessedTime = now;
    _isProcessingFrame = true;

    try {
      final faceInfo = await _faceDetectorService?.processCameraImage(
        image: image,
        camera: _activeCamera!,
      );

      if (mounted) {
        if (faceInfo != null) {
          _detectedFaceInfo = faceInfo;
          if (widget.onFaceTrackingUpdate != null) {
            widget.onFaceTrackingUpdate!(faceInfo);
          }

          final isSameLocation = _detectedFaceRect == null ||
              (faceInfo.boundingBox.center - _detectedFaceRect!.center).distance < 120.0;

          if (isSameLocation) {
            _consecutiveFaceHits++;
          } else {
            _consecutiveFaceHits = 1; // Nhảy vị trí đột ngột, bắt đầu tính lại chu kỳ ổn định
          }

          if (_consecutiveFaceHits >= 2) {
            _consecutiveFaceHits = 0; // Reset bộ đếm chu kỳ để tránh kích hoạt dồn dập
            setState(() {
              _detectedFaceRect = faceInfo.boundingBox;
              _mlStatus = '🟢 ĐÃ XÁC THỰC NGƯỜI THẬT!';
            });

            // Tự động kích hoạt cấp giấy hoặc kiểm tra Cooldown khi đã xác nhận ổn định
            if (widget.onRealFaceDetected != null) {
              widget.onRealFaceDetected!(faceInfo);
            }
          } else {
            setState(() {
              _detectedFaceRect = faceInfo.boundingBox;
              _mlStatus = 'AI Google ML Kit: Đang xác thực (Frame 1/2)...';
            });
          }
        } else {
          _consecutiveFaceHits = 0;
          final dropReason = _faceDetectorService?.lastDropReason ?? '';
          setState(() {
            _detectedFaceRect = null;
            _detectedFaceInfo = null;
            _mlStatus = dropReason.isNotEmpty
                ? 'AI: $dropReason'
                : 'AI Google ML Kit: Đang tìm khuôn mặt...';
          });
        }
      }
    } catch (_) {
      // Ignored
    } finally {
      _isProcessingFrame = false;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraController?.stopImageStream().catchError((_) {});
    _cameraController?.dispose();
    _faceDetectorService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final boxSize = (size * 0.76).clamp(240.0, 420.0);

        return Stack(
          alignment: Alignment.center,
          children: [
              // 1. Khung Viewfinder Camera phát sáng
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  final isDetected = widget.isFaceDetected || _detectedFaceRect != null;
                  return Container(
                    width: boxSize * (isDetected ? _pulseAnimation.value : 1.0),
                    height: boxSize * (isDetected ? _pulseAnimation.value : 1.0),
                    decoration: BoxDecoration(
                      color: KioskTheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: (isDetected ? KioskTheme.accentGreen : widget.activeColor)
                            .withValues(alpha: isDetected ? 0.9 : 0.4),
                        width: isDetected ? 3.5 : 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isDetected ? KioskTheme.accentGreen : widget.activeColor)
                              .withValues(alpha: isDetected ? 0.45 : 0.15),
                          blurRadius: 28,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    alignment: Alignment.center,
                    fit: StackFit.expand,
                    children: [
                      // Hiển thị Live Camera Feed nếu khởi tạo thành công
                      if (_isCameraInitialized && _cameraController != null)
                        FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize?.height ?? boxSize,
                            height: _cameraController!.value.previewSize?.width ?? boxSize,
                            child: CameraPreview(_cameraController!),
                          ),
                        )
                      else
                        // Chế độ mô phỏng AI / Đợi cấp quyền
                        _buildFallbackView(boxSize),

                      // Tia quét radar laser & trạng thái
                      RadarScanOverlay(
                        isFaceDetected: widget.isFaceDetected || _detectedFaceRect != null,
                        statusText: widget.statusText,
                        activeColor: (_detectedFaceRect != null || widget.isFaceDetected)
                            ? KioskTheme.accentGreen
                            : widget.activeColor,
                      ),

                      // Bounding box AI nhận diện bám dính thời gian thực
                      if (_detectedFaceRect != null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _FaceBoundingBoxPainter(
                              faceRect: _detectedFaceRect!,
                              previewSize: _cameraPreviewSize,
                              color: KioskTheme.accentGreen,
                              trackingId: _detectedFaceInfo?.trackingId,
                              isFrontCamera: _activeCamera?.lensDirection == CameraLensDirection.front,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 2. Nhãn trạng thái AI nhỏ ở trên đầu
              Positioned(
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_detectedFaceRect != null)
                          ? KioskTheme.accentGreen.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    _mlStatus,
                    style: TextStyle(
                      color: (_detectedFaceRect != null)
                          ? KioskTheme.accentGreen
                          : KioskTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
  }

  Widget _buildFallbackView(double boxSize) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: Size(boxSize, boxSize),
          painter: _CameraGridPainter(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        if (!_hasPermission && _permissionError != null)
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_outlined, color: KioskTheme.warningAmber, size: 42),
              const SizedBox(height: 10),
              const Text(
                'Cần cấp quyền Camera',
                style: TextStyle(color: KioskTheme.warningAmber, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _initCameraFlow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KioskTheme.primaryCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('CẤP QUYỀN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          )
        else
          Icon(
            widget.isFaceDetected ? Icons.face_retouching_natural_rounded : Icons.face_rounded,
            size: boxSize * 0.42,
            color: widget.activeColor.withValues(alpha: widget.isFaceDetected ? 0.7 : 0.25),
          ),
      ],
    );
  }
}

class _FaceBoundingBoxPainter extends CustomPainter {
  final Rect faceRect;
  final Size? previewSize;
  final Color color;
  final int? trackingId;
  final bool isFrontCamera;

  _FaceBoundingBoxPainter({
    required this.faceRect,
    this.previewSize,
    required this.color,
    this.trackingId,
    this.isFrontCamera = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Rect mappedRect;

    if (previewSize != null && previewSize!.width > 0 && previewSize!.height > 0) {
      final double scaleX = size.width / previewSize!.width;
      final double scaleY = size.height / previewSize!.height;
      final double scale = max(scaleX, scaleY);

      final double offsetX = (size.width - previewSize!.width * scale) / 2.0;
      final double offsetY = (size.height - previewSize!.height * scale) / 2.0;

      double left, right;
      if (isFrontCamera) {
        // Gương lật ngang đối với Camera trước trên Android/iOS
        left = size.width - (faceRect.right * scale + offsetX);
        right = size.width - (faceRect.left * scale + offsetX);
      } else {
        left = faceRect.left * scale + offsetX;
        right = faceRect.right * scale + offsetX;
      }

      final double top = faceRect.top * scale + offsetY;
      final double bottom = faceRect.bottom * scale + offsetY;

      mappedRect = Rect.fromLTRB(
        left.clamp(0.0, size.width),
        top.clamp(0.0, size.height),
        right.clamp(0.0, size.width),
        bottom.clamp(0.0, size.height),
      );
    } else {
      mappedRect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.65,
        height: size.height * 0.75,
      );
    }

    // 1. Nền mờ nhẹ bên trong khuôn mặt
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final rrect = RRect.fromRectAndRadius(mappedRect, const Radius.circular(16));
    canvas.drawRRect(rrect, fillPaint);

    // 2. Viền mỏng toàn khung
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rrect, borderPaint);

    // 3. Bốn góc định vị HUD Cyberpunk nổi bật (Corner Brackets)
    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    final cornerLen = (min(mappedRect.width, mappedRect.height) * 0.22).clamp(14.0, 32.0);

    // Góc trên bên trái
    canvas.drawLine(Offset(mappedRect.left, mappedRect.top + cornerLen), Offset(mappedRect.left, mappedRect.top), cornerPaint);
    canvas.drawLine(Offset(mappedRect.left, mappedRect.top), Offset(mappedRect.left + cornerLen, mappedRect.top), cornerPaint);

    // Góc trên bên phải
    canvas.drawLine(Offset(mappedRect.right - cornerLen, mappedRect.top), Offset(mappedRect.right, mappedRect.top), cornerPaint);
    canvas.drawLine(Offset(mappedRect.right, mappedRect.top), Offset(mappedRect.right, mappedRect.top + cornerLen), cornerPaint);

    // Góc dưới bên trái
    canvas.drawLine(Offset(mappedRect.left, mappedRect.bottom - cornerLen), Offset(mappedRect.left, mappedRect.bottom), cornerPaint);
    canvas.drawLine(Offset(mappedRect.left, mappedRect.bottom), Offset(mappedRect.left + cornerLen, mappedRect.bottom), cornerPaint);

    // Góc dưới bên phải
    canvas.drawLine(Offset(mappedRect.right - cornerLen, mappedRect.bottom), Offset(mappedRect.right, mappedRect.bottom), cornerPaint);
    canvas.drawLine(Offset(mappedRect.right, mappedRect.bottom), Offset(mappedRect.right, mappedRect.bottom - cornerLen), cornerPaint);

    // 4. Tâm ngắm chữ thập ở giữa khuôn mặt
    final center = mappedRect.center;
    const crossLen = 6.0;
    final crossPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(center.dx - crossLen, center.dy), Offset(center.dx + crossLen, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - crossLen), Offset(center.dx, center.dy + crossLen), crossPaint);

    // 5. Thẻ Tag Tracking ID bám sát trên đầu khuôn mặt
    final trackText = trackingId != null ? '🟢 TRACK #$trackingId' : '🟢 FACE LOCKED';
    final textPainter = TextPainter(
      text: TextSpan(
        text: ' $trackText ',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = Rect.fromLTWH(
      mappedRect.left + 4,
      max(2.0, mappedRect.top - 18),
      textPainter.width + 6,
      textPainter.height + 4,
    );
    final badgePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(6)), badgePaint);

    final badgeBorder = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(6)), badgeBorder);

    textPainter.paint(canvas, Offset(badgeRect.left + 3, badgeRect.top + 2));
  }

  @override
  bool shouldRepaint(covariant _FaceBoundingBoxPainter oldDelegate) {
    return oldDelegate.faceRect != faceRect ||
        oldDelegate.trackingId != trackingId ||
        oldDelegate.previewSize != previewSize ||
        oldDelegate.color != color;
  }
}

class _CameraGridPainter extends CustomPainter {
  final Color color;
  _CameraGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    final stepX = size.width / 3;
    final stepY = size.height / 3;

    canvas.drawLine(Offset(stepX, 0), Offset(stepX, size.height), paint);
    canvas.drawLine(Offset(stepX * 2, 0), Offset(stepX * 2, size.height), paint);
    canvas.drawLine(Offset(0, stepY), Offset(size.width, stepY), paint);
    canvas.drawLine(Offset(0, stepY * 2), Offset(size.width, stepY * 2), paint);
  }

  @override
  bool shouldRepaint(covariant _CameraGridPainter oldDelegate) => false;
}
