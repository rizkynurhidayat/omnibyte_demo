import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/permission_helper.dart';
import '../../../core/utils/string_utils.dart';

import '../../domain/entities/document_type.dart';

class SelfieKtpScannerView extends StatefulWidget {
  final DocumentType documentType;
  final String expectedNik;
  final String expectedName;
  final String ktpPath;
  final String documentFacePath;
  final Function(String selfiePath, String croppedSelfieFacePath, String croppedKtpFacePath) onCaptured;

  const SelfieKtpScannerView({
    super.key,
    required this.documentType,
    required this.expectedNik,
    required this.expectedName,
    required this.ktpPath,
    required this.documentFacePath,
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
      enableClassification: true,
      enableLandmarks: false,
      enableTracking: false,
    ),
  );

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool _isFaceDetectedLive = false;
  String _livenessStatusText = "Posisikan wajah di dalam oval";

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
          final hasFace = faces.isNotEmpty;
          if (_isFaceDetectedLive != hasFace) {
            setState(() {
              _isFaceDetectedLive = hasFace;
              _livenessStatusText = hasFace ? "Wajah Terdeteksi" : "Posisikan wajah di dalam oval";
            });
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
      if (widget.documentType == DocumentType.ktp && targetNik.length == 16) {
         nikSimilarity = StringUtils.findBestMatch(normalizedNikText, targetNik.substring(0, 14));
      } else if (widget.documentType == DocumentType.sim && targetNik.length >= 12) {
         nikSimilarity = StringUtils.findBestMatch(normalizedNikText, targetNik.substring(0, 10));
      } else if (widget.documentType == DocumentType.passport && targetNik.length >= 7) {
         nikSimilarity = StringUtils.findBestMatch(rawText, targetNik);
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
        _showErrorAndReset("${widget.documentType.label} tidak terdeteksi atau data tidak cocok! Gunakan ${widget.documentType.label} yang sama.");
        return;
      }

      // Sort all detected faces by bounding box size descending
      // The largest face is the user's real face, and the second largest (if present) is the face on the KTP card.
      faces.sort((a, b) {
        final areaA = a.boundingBox.width * a.boundingBox.height;
        final areaB = b.boundingBox.width * b.boundingBox.height;
        return areaB.compareTo(areaA);
      });

      final userFace = faces[0];
      Face? ktpFaceOnSelfie;
      if (faces.length > 1) {
        ktpFaceOnSelfie = faces[1];
      }

      // Crop face area from selfie image for the user's face
      final userBbox = userFace.boundingBox;
      final croppedSelfieFaceFile = await ImageUtils.cropFace(
        file.path,
        userBbox.left.toInt(),
        userBbox.top.toInt(),
        userBbox.width.toInt(),
        userBbox.height.toInt(),
        suffix: '_selfieface',
      );

      // Crop face area from selfie image for the document face in step 2 if detected, otherwise fallback to Step 1 face
      File croppedKtpFaceFile;
      if (ktpFaceOnSelfie != null) {
        final ktpBbox = ktpFaceOnSelfie.boundingBox;
        croppedKtpFaceFile = await ImageUtils.cropFace(
          file.path,
          ktpBbox.left.toInt(),
          ktpBbox.top.toInt(),
          ktpBbox.width.toInt(),
          ktpBbox.height.toInt(),
          suffix: '_ktpface',
        );
      } else {
        croppedKtpFaceFile = File(widget.documentFacePath);
      }

      // Success - Callback with selfie path, cropped selfie face path, and cropped KTP face path
      widget.onCaptured(file.path, croppedSelfieFaceFile.path, croppedKtpFaceFile.path);
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



  // ignore: unused_element
  void _simulateSelfie() async {
    setState(() {
      _isCapturing = true;
    });
    await Future.delayed(const Duration(seconds: 1));
    widget.onCaptured('simulated_selfie.jpg', 'simulated_selfie_face.jpg', 'simulated_ktp_face.jpg');
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
            painter: SelfieKtpCutoutPainter(widget.documentType),
          ),
        ),

        // Status banner
        Positioned(
          top: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isFaceDetectedLive ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isFaceDetectedLive ? Icons.remove_red_eye : Icons.warning_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _livenessStatusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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

        // Shutter Button & Switch Camera Button
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
                    const SizedBox(width: 48),
                    const SizedBox(width: 32),
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
                            Icons.camera_alt,
                            color: Theme.of(context).colorScheme.primary,
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
              ],
            ),
          ),
      ],
    );
  }
}

class SelfieKtpCutoutPainter extends CustomPainter {
  final DocumentType documentType;

  SelfieKtpCutoutPainter(this.documentType);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withAlpha(160);

    // 1. Oval size & center at the top
    final ovalWidth = size.width * 0.45;
    final ovalHeight = size.height * 0.28;
    final ovalCenter = Offset(size.width / 2, size.height * 0.25);
    final ovalRect = Rect.fromCenter(
      center: ovalCenter,
      width: ovalWidth,
      height: ovalHeight,
    );

    // 2. Rectangle size & center for KTP at the bottom
    final ktpWidth = size.width * 0.65;
    final ktpHeight = size.height * 0.23;
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

    textPainter.text = TextSpan(
      text: "Pegang ${documentType.label} DI SINI",
      style: const TextStyle(
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
