import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../core/utils/permission_helper.dart';

enum LivenessChallenge {
  smile('Tersenyum', 'Silakan tersenyum lebar!'),
  lookLeft('Menoleh Kiri', 'Silakan menoleh ke kiri Anda!'),
  lookRight('Menoleh Kanan', 'Silakan menoleh ke kanan Anda!');

  final String title;
  final String instruction;
  const LivenessChallenge(this.title, this.instruction);
}

class LivenessScannerView extends StatefulWidget {
  final Function(String selfiePath) onCaptured;
  final VoidCallback onTimeout;

  const LivenessScannerView({
    super.key,
    required this.onCaptured,
    required this.onTimeout,
  });

  @override
  State<LivenessScannerView> createState() => _LivenessScannerViewState();
}

class _LivenessScannerViewState extends State<LivenessScannerView> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessingImage = false;
  bool _isCapturing = false;
  bool _isTimeout = false;

  int _secondsLeft = 10;
  Timer? _countdownTimer;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // For smiling probability
      enableLandmarks: false,
      enableTracking: false,
    ),
  );

  LivenessChallenge _currentChallenge = LivenessChallenge.smile;
  String _validationStatus = "Mencari wajah...";
  bool _isFaceValid = false;
  double _challengeProgress = 0.0;

  final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    // Choose a random challenge
    final challenges = LivenessChallenge.values;
    _currentChallenge = challenges[DateTime.now().millisecond % challenges.length];
    
    _initCameraAndStartTimer();
  }

  Future<void> _initCameraAndStartTimer() async {
    final permission = await PermissionHelper.requestCameraPermission();
    if (!mounted) return;

    if (permission) {
      try {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) {
          final frontCamera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first,
          );

          _cameraController = CameraController(
            frontCamera,
            ResolutionPreset.high,
            enableAudio: false,
            imageFormatGroup: Platform.isAndroid
                ? ImageFormatGroup.nv21
                : ImageFormatGroup.bgra8888,
          );

          await _cameraController!.initialize();
          if (mounted) {
            setState(() {
              _isCameraInitialized = true;
            });
            _startImageStream();
            _startTimeoutCountdown();
          }
        }
      } catch (e) {
        debugPrint('Error initializing front camera: $e');
      }
    }
  }

  void _startTimeoutCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft--;
        } else {
          _secondsLeft = 0;
          _isTimeout = true;
          _countdownTimer?.cancel();
          _stopCameraAndTriggerTimeout();
        }
      });
    });
  }

  void _stopCameraAndTriggerTimeout() async {
    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}
    widget.onTimeout();
  }

  void _startImageStream() {
    if (_cameraController == null || !_isCameraInitialized) return;

    _cameraController!.startImageStream((CameraImage image) async {
      if (_isProcessingImage || _isCapturing || _isTimeout) return;
      _isProcessingImage = true;

      try {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage != null) {
          final faces = await _faceDetector.processImage(inputImage);
          if (faces.isEmpty) {
            _updateFaceStatus("Wajah tidak terdeteksi", false, 0.0);
          } else {
            final face = faces.first;
            _validateFaceAndChallenge(face, image.width.toDouble(), image.height.toDouble());
          }
        }
      } catch (e) {
        debugPrint('Error processing liveness face detection: $e');
      } finally {
        _isProcessingImage = false;
      }
    });
  }

  void _updateFaceStatus(String status, bool isValid, double progress) {
    if (!mounted) return;
    setState(() {
      _validationStatus = status;
      _isFaceValid = isValid;
      _challengeProgress = progress.clamp(0.0, 1.0);
    });
  }

  void _validateFaceAndChallenge(Face face, double imageWidth, double imageHeight) {
    final boundingBox = face.boundingBox;

    // 1. Distance check (Too far check)
    // We expect the face to occupy a significant portion of the image.
    // Standard relative size: boundingBox height vs image height
    final relativeHeight = boundingBox.height / imageHeight;
    if (relativeHeight < 0.20) {
      _updateFaceStatus("Dekatkan wajah Anda ke layar", false, 0.0);
      return;
    }

    // 2. Truncation check (Edge cutoff check)
    // Make sure face is fully in frame and not cut off by edges
    final margin = 10.0;
    if (boundingBox.left < margin ||
        boundingBox.top < margin ||
        boundingBox.right > (imageWidth - margin) ||
        boundingBox.bottom > (imageHeight - margin)) {
      _updateFaceStatus("Posisikan wajah utuh di dalam oval", false, 0.0);
      return;
    }

    // 3. Challenge check
    switch (_currentChallenge) {
      case LivenessChallenge.smile:
        final smileProb = face.smilingProbability ?? 0.0;
        if (smileProb > 0.70) {
          _updateFaceStatus("Tantangan Sukses! Mengambil foto...", true, 1.0);
          _autoCaptureSelfie();
        } else {
          // Progress mapping (0 to 1 based on smile prob)
          _updateFaceStatus("Silakan tersenyum lebar", true, smileProb / 0.70);
        }
        break;

      case LivenessChallenge.lookLeft:
        final eulerY = face.headEulerAngleY ?? 0.0;
        // In mirrored front camera, Euler Y value positive/negative determines direction.
        // Let's accept head rotation absolute degrees > 18° as turned left/right.
        // Usually Euler Y > 18 implies look left, Euler Y < -18 look right depending on mirroring.
        if (eulerY > 18) {
          _updateFaceStatus("Tantangan Sukses! Mengambil foto...", true, 1.0);
          _autoCaptureSelfie();
        } else {
          // Map progress up to 18 degrees
          _updateFaceStatus("Silakan menoleh ke kiri Anda", true, eulerY.clamp(0.0, 18.0) / 18.0);
        }
        break;

      case LivenessChallenge.lookRight:
        final eulerY = face.headEulerAngleY ?? 0.0;
        if (eulerY < -18) {
          _updateFaceStatus("Tantangan Sukses! Mengambil foto...", true, 1.0);
          _autoCaptureSelfie();
        } else {
          _updateFaceStatus("Silakan menoleh ke kanan Anda", true, eulerY.abs().clamp(0.0, 18.0) / 18.0);
        }
        break;
    }
  }

  Future<void> _autoCaptureSelfie() async {
    if (_isCapturing || _isTimeout) return;
    _isCapturing = true;
    _countdownTimer?.cancel();

    try {
      // Give a tiny delay for visual satisfaction
      await Future.delayed(const Duration(milliseconds: 300));
      
      try {
        await _cameraController?.stopImageStream();
      } catch (_) {}

      final file = await _cameraController!.takePicture();
      widget.onCaptured(file.path);
    } catch (e) {
      debugPrint("Selfie auto-capture error: $e");
    }
  }

  void _simulateLivenessSuccess() async {
    _countdownTimer?.cancel();
    setState(() {
      _isCapturing = true;
      _validationStatus = "Tantangan Sukses (Simulator)!";
      _challengeProgress = 1.0;
    });

    await Future.delayed(const Duration(seconds: 1));
    widget.onCaptured('simulated_selfie.jpg');
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.planes.length != 1 && image.planes.length != 3) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    try {
      _cameraController?.stopImageStream();
    } catch (_) {}
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera feed preview
        if (_isCameraInitialized && _cameraController != null)
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          )
        else
          Container(
            color: Colors.black,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Menyiapkan Kamera Depan...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

        // Oval shape cutout overlay
        Positioned.fill(
          child: CustomPaint(
            painter: LivenessCutoutPainter(isValid: _isFaceValid),
          ),
        ),

        // Countdown Timer HUD (Phase 5)
        Positioned(
          top: 30,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _secondsLeft <= 3 ? Colors.redAccent.withAlpha(220) : Colors.black87,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${_secondsLeft}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Core instructions overlay
        Positioned(
          bottom: 120,
          left: 30,
          right: 30,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(200),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isFaceValid ? Colors.green.withAlpha(120) : Colors.white24,
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Display current instruction
                Text(
                  _currentChallenge.instruction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Progress Bar of the Challenge
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _challengeProgress,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _challengeProgress >= 1.0 ? Colors.greenAccent : Colors.blueAccent,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Sub-status text
                Text(
                  _validationStatus,
                  style: TextStyle(
                    color: _challengeProgress >= 1.0
                        ? Colors.greenAccent
                        : (_isFaceValid ? Colors.white70 : Colors.redAccent),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Simulator button in case camera stream isn't doable
        Positioned(
          bottom: 40,
          left: 40,
          right: 40,
          child: TextButton.icon(
            onPressed: _simulateLivenessSuccess,
            style: TextButton.styleFrom(
              backgroundColor: Colors.orange[800]?.withAlpha(200),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            icon: const Icon(Icons.bolt),
            label: const Text(
              'Simulasikan Liveness Lolos',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class LivenessCutoutPainter extends CustomPainter {
  final bool isValid;

  LivenessCutoutPainter({required this.isValid});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withAlpha(160);

    // Oval dimension in center of the screen
    final ovalWidth = size.width * 0.65;
    final ovalHeight = ovalWidth * 1.35;
    final center = Offset(size.width / 2, size.height / 2 - 40);

    final rect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    // Bounding mask path
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(rect);

    canvas.drawPath(path, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = isValid ? Colors.green : Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawOval(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
