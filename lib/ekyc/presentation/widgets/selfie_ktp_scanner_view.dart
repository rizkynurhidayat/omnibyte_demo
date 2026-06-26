import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../core/utils/permission_helper.dart';

class SelfieKtpScannerView extends StatefulWidget {
  final Function(String selfiePath) onCaptured;

  const SelfieKtpScannerView({
    super.key,
    required this.onCaptured,
  });

  @override
  State<SelfieKtpScannerView> createState() => _SelfieKtpScannerViewState();
}

class _SelfieKtpScannerViewState extends State<SelfieKtpScannerView> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessingImage = false;
  bool _isCapturing = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: false,
      enableLandmarks: false,
      enableTracking: false,
    ),
  );

  String _validationStatus = "Posisikan wajah Anda di dalam oval...";
  bool _isFaceDetected = false;

  final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
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
          await _cameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);
          
          if (mounted) {
            setState(() {
              _isCameraInitialized = true;
            });
            _startImageStream();
          }
        }
      } catch (e) {
        debugPrint('Error initializing front camera: $e');
      }
    }
  }

  void _startImageStream() {
    if (_cameraController == null || !_isCameraInitialized) return;

    _cameraController!.startImageStream((CameraImage image) async {
      if (_isProcessingImage || _isCapturing) return;
      _isProcessingImage = true;

      try {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage != null) {
          final faces = await _faceDetector.processImage(inputImage);
          _validateFacePresence(faces);
        }
      } catch (e) {
        debugPrint('Error processing front camera face detection: $e');
      } finally {
        _isProcessingImage = false;
      }
    });
  }

  void _validateFacePresence(List<Face> faces) {
    if (!mounted) return;

    if (faces.isEmpty) {
      setState(() {
        _validationStatus = "Wajah tidak terdeteksi. Posisikan wajah di dalam oval.";
        _isFaceDetected = false;
      });
    } else {
      final face = faces.first;
      final boundingBox = face.boundingBox;
      // Simple validation: make sure the face is relatively centered/not cut off
      if (boundingBox.width < 80) {
        setState(() {
          _validationStatus = "Dekatkan wajah Anda ke kamera.";
          _isFaceDetected = false;
        });
      } else {
        setState(() {
          _validationStatus = "Wajah terdeteksi! Silakan pegang KTP dan ambil foto.";
          _isFaceDetected = true;
        });
      }
    }
  }

  Future<void> _captureSelfie() async {
    if (_isCapturing || _cameraController == null || !_isCameraInitialized) return;
    
    setState(() {
      _isCapturing = true;
    });

    try {
      try {
        await _cameraController?.stopImageStream();
      } catch (_) {}

      final file = await _cameraController!.takePicture();
      widget.onCaptured(file.path);
    } catch (e) {
      debugPrint("Selfie capture error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saat mengambil gambar: $e')),
        );
      }
      setState(() {
        _isCapturing = false;
      });
      _startImageStream();
    }
  }

  void _simulateSelfie() async {
    setState(() {
      _isCapturing = true;
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
        // Camera Preview
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

        // Dual cutout overlay (Oval face + Rect KTP)
        Positioned.fill(
          child: CustomPaint(
            painter: SelfieKtpCutoutPainter(),
          ),
        ),

        // Status banner
        Positioned(
          top: 30,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(180),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFaceDetected ? Colors.green.withAlpha(120) : Colors.white24,
                width: 1.5,
              ),
            ),
            child: Text(
              _validationStatus,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Processing / Capturing overlay
        if (_isCapturing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Mengambil gambar...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Controls (Shutter + Simulator)
        if (!_isCapturing)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _isCameraInitialized ? _captureSelfie : null,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _isCameraInitialized ? Colors.white : Colors.grey,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          )
                        ],
                      ),
                      child: Icon(
                        Icons.camera_front,
                        color: Colors.blue[900],
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _simulateSelfie,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.blue[900]?.withAlpha(200),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text(
                    'Gunakan Simulator (Bypass Kamera)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class SelfieKtpCutoutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withAlpha(160);

    // 1. Oval size & center at the top
    final ovalWidth = size.width * 0.55;
    final ovalHeight = size.height * 0.33;
    final ovalCenter = Offset(size.width / 2, size.height * 0.35);
    final ovalRect = Rect.fromCenter(
      center: ovalCenter,
      width: ovalWidth,
      height: ovalHeight,
    );

    // 2. Rectangle size & center for KTP at the bottom
    final ktpWidth = size.width * 0.55;
    final ktpHeight = size.height * 0.16;
    final ktpCenter = Offset(size.width / 2, size.height * 0.72);
    final ktpRect = Rect.fromCenter(
      center: ktpCenter,
      width: ktpWidth,
      height: ktpHeight,
    );
    final ktpRRect = RRect.fromRectAndRadius(ktpRect, const Radius.circular(10));

    // Combine outer bounds and cutouts
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..addRRect(ktpRRect);

    canvas.drawPath(path, paint);

    // Draw borders around cutouts
    final borderPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawOval(ovalRect, borderPaint);
    canvas.drawRRect(ktpRRect, borderPaint);

    // Add labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.text = const TextSpan(
      text: "POSISI WAJAH",
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        backgroundColor: Colors.black54,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(ovalCenter.dx - (textPainter.width / 2), ovalCenter.dy + (ovalHeight / 2) + 8),
    );

    textPainter.text = const TextSpan(
      text: "PEgang KTP DI SINI",
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        backgroundColor: Colors.black54,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(ktpCenter.dx - (textPainter.width / 2), ktpCenter.dy + (ktpHeight / 2) + 8),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
