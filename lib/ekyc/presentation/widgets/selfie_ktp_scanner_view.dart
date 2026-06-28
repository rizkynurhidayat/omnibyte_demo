import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../core/utils/permission_helper.dart';
import '../../../core/utils/string_utils.dart';

class SelfieKtpScannerView extends StatefulWidget {
  final String expectedNik;
  final String expectedName;
  final Function(String selfiePath) onCaptured;

  const SelfieKtpScannerView({
    super.key,
    required this.expectedNik,
    required this.expectedName,
    required this.onCaptured,
  });

  @override
  State<SelfieKtpScannerView> createState() => _SelfieKtpScannerViewState();
}

class _SelfieKtpScannerViewState extends State<SelfieKtpScannerView> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  bool _isCapturing = false;
  CameraLensDirection _lensDirection = CameraLensDirection.front;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: false,
      enableLandmarks: false,
      enableTracking: false,
    ),
  );

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  String _validationStatus = "Posisikan wajah & KTP Anda, lalu tekan tombol foto.";


  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  bool _isDetectingFace = false;

  void _startLiveFaceDetection() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    _cameraController!.startImageStream((CameraImage image) async {
      if (_isDetectingFace || _isCapturing) return;
      _isDetectingFace = true;

      try {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage == null) {
          _isDetectingFace = false;
          return;
        }

        final faces = await _faceDetector.processImage(inputImage);
        
        if (mounted && !_isCapturing) {
          if (faces.isEmpty) {
            if (_validationStatus != "Wajah tidak terdeteksi. Posisikan wajah di dalam oval.") {
              setState(() {
                _validationStatus = "Wajah tidak terdeteksi. Posisikan wajah di dalam oval.";
              });
            }
          } else {
            if (_validationStatus != "Wajah terdeteksi. Silakan ambil foto KTP & Selfie.") {
              setState(() {
                _validationStatus = "Wajah terdeteksi. Silakan ambil foto KTP & Selfie.";
              });
            }
          }
        }
      } catch (e) {
        debugPrint("Error detecting face live: $e");
      } finally {
        _isDetectingFace = false;
      }
    });
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;
    
    InputImageRotation? rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || (Platform.isAndroid && format != InputImageFormat.nv21) || (Platform.isIOS && format != InputImageFormat.bgra8888)) {
       return null; 
    }
    if (image.planes.isEmpty) return null;

    // Concatenate bytes for Android NV21 to be safe, but usually plane 0 contains all data.
    // For flutter camera, plane 0 has the bytes.
    final bytes = image.planes[0].bytes;

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

  Future<void> _initCamera() async {
    final permission = await PermissionHelper.requestCameraPermission();
    if (!mounted) return;

    if (permission) {
      try {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) {
          final targetCamera = cameras.firstWhere(
            (c) => c.lensDirection == _lensDirection,
            orElse: () => cameras.first,
          );

          _cameraController = CameraController(
            targetCamera,
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
            _startLiveFaceDetection();
          }
        }
      } catch (e) {
        debugPrint('Error initializing camera: $e');
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameraController == null || !_isCameraInitialized) return;
    
    if (_cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }

    setState(() {
      _lensDirection = _lensDirection == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
      _isCameraInitialized = false;
    });

    await _cameraController?.dispose();
    _cameraController = null;
    await _initCamera();
  }

  Future<void> _captureSelfie() async {
    if (_isCapturing || _cameraController == null || !_isCameraInitialized) return;
    
    setState(() {
      _isCapturing = true;
    });

    try {
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      
      // Memberi sedikit jeda agar kamera selesai menutup stream sebelum mengambil foto
      await Future.delayed(const Duration(milliseconds: 300));
      
      final file = await _cameraController!.takePicture();
      
      final inputImage = InputImage.fromFilePath(file.path);
      
      // 1. Analyze Face (dilakukan kembali pada hasil foto untuk memastikan wajah ada)
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        _showErrorAndReset("Wajah tidak terdeteksi di hasil foto. Posisikan wajah di dalam oval.");
        return;
      }
      
      // 2. Analyze KTP Text
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final rawText = recognizedText.text.replaceAll(RegExp(r'\s+'), '').toLowerCase();
      final targetNik = widget.expectedNik.toLowerCase();
      
      final targetFullName = widget.expectedName.replaceAll(RegExp(r'\s+'), '').toLowerCase();

      // Normalisasi teks untuk pembacaan angka (mengatasi typo OCR)
      final normalizedNikText = rawText
          .replaceAll(RegExp(r'[o]'), '0')
          .replaceAll(RegExp(r'[l|i]'), '1')
          .replaceAll('b', '6')
          .replaceAll('s', '5');

      bool isMatched = false;
      
      // Menggunakan Fuzzy String Matching (Levenshtein Distance)
      // Membutuhkan kemiripan NIK (minimal 14 digit) > 85% ATAU Nama Lengkap > 85%
      double nikSimilarity = 0.0;
      if (targetNik.length == 16) {
         nikSimilarity = StringUtils.findBestMatch(normalizedNikText, targetNik.substring(0, 14));
      }
      
      double nameSimilarity = 0.0;
      if (targetFullName.length > 3) {
         nameSimilarity = StringUtils.findBestMatch(rawText, targetFullName);
      }

      // Ambang batas kemiripan (threshold) disetel ke 0.85 (85%)
      if (nikSimilarity > 0.85 || nameSimilarity > 0.85) {
        isMatched = true;
      }

      if (!isMatched) {
        _showErrorAndReset("KTP tidak terdeteksi atau data tidak cocok! Gunakan KTP yang sama.");
        return;
      }

      // Success
      widget.onCaptured(file.path);
    } catch (e) {
      debugPrint("Selfie capture error: $e");
      _showErrorAndReset('Error saat menganalisis gambar: $e');
    }
  }

  void _showErrorAndReset(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _isCapturing = false;
      });
      // Restart live face detection after an error
      _startLiveFaceDetection();
    }
  }



  void _simulateSelfie() async {
    setState(() {
      _isCapturing = true;
    });
    await Future.delayed(const Duration(seconds: 1));
    widget.onCaptured('simulated_selfie.jpg');
  }



  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera Preview
        if (_isCameraInitialized && _cameraController != null)
          Positioned.fill(
            child: _lensDirection == CameraLensDirection.front
                ? Transform.scale(
                    scaleX: -1,
                    alignment: Alignment.center,
                    child: CameraPreview(_cameraController!),
                  )
                : CameraPreview(_cameraController!),
          )
        else
          Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    _lensDirection == CameraLensDirection.front
                        ? 'Menyiapkan Kamera Depan...'
                        : 'Menyiapkan Kamera Belakang...',
                    style: const TextStyle(color: Colors.white70),
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
                color: Colors.white24,
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
                    'Menganalisis gambar...',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Placeholder to balance the switch camera button
                    const SizedBox(width: 48), 
                    const SizedBox(width: 32),
                    
                    // Shutter Button
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
                            color: _isCameraInitialized ? Colors.white : Colors.grey[300],
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
                            _lensDirection == CameraLensDirection.front ? Icons.camera_front : Icons.camera_alt,
                            color: _isCameraInitialized ? Theme.of(context).colorScheme.primary : Colors.grey[500],
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 32),
                    
                    // Switch Camera Button
                    CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.flip_camera_android, color: Colors.white),
                        onPressed: _switchCamera,
                      ),
                    ),
                  ],
                ),
                // Simulator button hidden
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
    final ovalCenter = Offset(size.width / 2, size.height * 0.25);
    final ovalRect = Rect.fromCenter(
      center: ovalCenter,
      width: ovalWidth,
      height: ovalHeight,
    );

    // 2. Rectangle size & center for KTP at the bottom
    final ktpWidth = size.width * 0.55;
    final ktpHeight = size.height * 0.18;
    final ktpCenter = Offset(size.width / 2, size.height * 0.65);
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
      text: "Pegang KTP DI SINI",
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
