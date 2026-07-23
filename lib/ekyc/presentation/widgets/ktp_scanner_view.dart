import 'dart:io';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/permission_helper.dart';
import '../../../core/utils/ocr_parser_util.dart';

import '../../domain/entities/document_type.dart';

class KtpScannerView extends StatefulWidget {
  final DocumentType documentType;
  final Function(String ktpPath, String croppedFacePath, String ocrJsonPath, String nik, String name) onCaptured;

  const KtpScannerView({
    super.key,
    required this.documentType,
    required this.onCaptured,
  });

  @override
  State<KtpScannerView> createState() => _KtpScannerViewState();
}

class _KtpScannerViewState extends State<KtpScannerView> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  CameraLensDirection _lensDirection = CameraLensDirection.back;

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
          final targetCamera = cameras.firstWhere(
            (c) => c.lensDirection == _lensDirection,
            orElse: () => cameras.first,
          );

          _cameraController = CameraController(
            targetCamera,
            ResolutionPreset.high,
            enableAudio: false,
          );

          await _cameraController!.initialize();
          // Lock capture orientation to portrait to keep UI consistent
          await _cameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);

          if (mounted) {
            setState(() {
              _isCameraInitialized = true;
            });
          }
        }
      } catch (e) {
        debugPrint('Error initializing camera: $e');
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameraController == null || !_isCameraInitialized) return;
    setState(() {
      _lensDirection = _lensDirection == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      _isCameraInitialized = false;
    });
    await _cameraController?.dispose();
    _cameraController = null;
    await _initCamera();
  }

  Future<void> _captureDocument() async {
    if (_isProcessing || _cameraController == null || !_isCameraInitialized) return;

    setState(() {
      _isProcessing = true;
    });

    final docLabel = widget.documentType.label;

    try {
      // 1. Take picture
      final XFile rawFile = await _cameraController!.takePicture();

      // 1.5 Crop the KTP card area from the full camera frame
      final croppedCardFile = await ImageUtils.cropKtpCard(rawFile.path);

      // 2. Perform brightness check (Too dark check) on the cropped card
      final isDark = await ImageUtils.isImageTooDark(croppedCardFile.path, threshold: 45.0);
      if (isDark) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gambar $docLabel terlalu gelap! Pastikan ruangan cukup terang.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // 3. Process OCR to find Document ID & Name on the cropped card
      final inputImage = InputImage.fromFilePath(croppedCardFile.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      final rawText = recognizedText.text;
      debugPrint("OCR RAW TEXT: $rawText");

      final ocrResult = OcrParserUtil.parse(
        rawText,
        recognizedText: recognizedText,
        hint: widget.documentType,
      );
      final finalDocId = ocrResult.documentNumber;
      final name = ocrResult.fullName;

      // 5. Crop face area from KTP image (now based on the cropped card)
      final isFaceOnLeft = widget.documentType != DocumentType.ktp;
      final croppedFaceFile = await ImageUtils.cropKtpFace(
        croppedCardFile.path,
        isFaceOnLeft: isFaceOnLeft,
      );

      // Save OCR details as ocr.json using OcrExtractionResult.toJson()
      final ocrJsonPath = croppedCardFile.path.replaceAll(RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false), '_ocr.json');
      await File(ocrJsonPath).writeAsString(jsonEncode(ocrResult.toJson()));

      // 6. Callback success
      widget.onCaptured(croppedCardFile.path, croppedFaceFile.path, ocrJsonPath, finalDocId, name);
    } catch (e) {
      debugPrint("$docLabel Capture error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saat memindai $docLabel: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }


  // ignore: unused_element
  void _simulateKtp() async {
    setState(() {
      _isProcessing = true;
    });
    await Future.delayed(const Duration(seconds: 1));
    
    // Setup dummy paths
    final dummyPath = 'simulated_ktp.jpg';
    final dummyFacePath = 'simulated_ktp_face.jpg';
    final dummyOcrJsonPath = 'simulated_ocr.json';
    
    widget.onCaptured(
      dummyPath,
      dummyFacePath,
      dummyOcrJsonPath,
      '3273012345678901',
      'RIZKY NURHIDAYAT',
    );
    
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera Preview or Loading
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
                    'Menyiapkan Kamera Belakang...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

        // Semi-transparent overlay with card cutout
        Positioned.fill(
          child: CustomPaint(
            painter: KtpCutoutPainter(documentType: widget.documentType),
          ),
        ),

        // Guidance HUD
        Positioned(
          top: 40,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(180),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              children: [
                Text(
                  'FOTO ${widget.documentType.label} ANDA',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Posisikan ${widget.documentType.label} pas di dalam bingkai.\nPastikan tulisan nomor identitas terlihat jelas dan tidak buram.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Processing indicator overlay
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Mengekstrak & Memvalidasi ${widget.documentType.label}...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Shutter Button & Simulator Button
        if (!_isProcessing)
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
                    
                    // Real Shutter Button
                    GestureDetector(
                      onTap: _isCameraInitialized ? _captureDocument : null,
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
                // Simulator button is hidden for production
              ],
            ),
          ),
      ],
    );
  }
}

class KtpCutoutPainter extends CustomPainter {
  final DocumentType documentType;

  KtpCutoutPainter({required this.documentType});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withAlpha(160);

    // KTP horizontal dimensions (standard aspect ratio 1.586)
    final width = size.width * 0.85;
    final height = width / 1.586;
    final left = (size.width - width) / 2;
    final top = (size.height - height) / 2 - 20;

    final rect = Rect.fromLTWH(left, top, width, height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // Combine outer bounds and inner cutout to draw mask
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect);

    canvas.drawPath(path, paint);

    // Draw border around cutout
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(rrect, borderPaint);

    // Draw photo frame indicator inside layout (Right side for KTP, Left side for SIM & Passport)
    final photoWidth = width * 0.30;
    final photoHeight = height * 0.65;
    final photoLeft = (documentType == DocumentType.ktp)
        ? rect.right - photoWidth - (width * 0.05)
        : rect.left + (width * 0.05);
    final photoTop = rect.top + (height * 0.15);

    final photoRect = Rect.fromLTWH(photoLeft, photoTop, photoWidth, photoHeight);
    final photoRRect = RRect.fromRectAndRadius(photoRect, const Radius.circular(8));

    final photoPaint = Paint()
      ..color = Colors.white.withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..setStrokePattern([4, 4]); // Dashed border effect in CustomPaint:
    
    canvas.drawRRect(photoRRect, photoPaint);
  }

  @override
  bool shouldRepaint(covariant KtpCutoutPainter oldDelegate) {
    return oldDelegate.documentType != documentType;
  }
}

// Simple extension to add dash effect to canvas strokes
extension DashPattern on Paint {
  void setStrokePattern(List<double> pattern) {
    // Simple custom dash paint behavior isn't natively supported,
    // but we can just draw solid line or use a basic dash calculation
  }
}
