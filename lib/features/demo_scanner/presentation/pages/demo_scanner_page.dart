import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/scanner_cubit.dart';
import '../cubit/scanner_state.dart';
import '../../../../core/utils/permission_helper.dart';

// =========================================================================
// KONFIGURASI UKURAN OVERLAY KAMERA
// Silakan ubah angka-angka di bawah ini untuk menyesuaikan ukuran bingkai
// (Angka merupakan rasio persentase dari layar kamera, contoh: 0.55 = 55%)
// =========================================================================
const double kFaceOverlayWidthRatio = 0.55;
const double kFaceOverlayHeightRatio = 0.35;
const double kFaceOverlayCenterYRatio =
    0.35; // Posisi vertikal Wajah (semakin kecil semakin ke atas)

const double kKtpOverlayWidthRatio = 0.50;
const double kKtpOverlayHeightRatio = 0.15;
const double kKtpOverlayCenterYRatio =
    0.75; // Posisi vertikal KTP (semakin besar semakin ke bawah)

class DemoScannerPage extends StatefulWidget {
  const DemoScannerPage({super.key});

  @override
  State<DemoScannerPage> createState() => _DemoScannerPageState();
}

class _DemoScannerPageState extends State<DemoScannerPage> {
  CameraController? _cameraController;
  bool _isPermissionGranted = false;
  bool _isCameraInitialized = false;
  CameraLensDirection _currentLensDirection = CameraLensDirection.back;
  String? _capturedImagePath;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
      enableTracking: false,
    ),
  );
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool _isFaceDetected = false;
  bool _isKtpDetected = false;
  bool _isProcessingImage = false;
  bool _isCapturing = false;

  final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _checkPermissionAndInitCamera();
  }

  Future<void> _checkPermissionAndInitCamera() async {
    final hasPermission = await PermissionHelper.requestCameraPermission();
    if (!mounted) return;
    setState(() {
      _isPermissionGranted = hasPermission;
    });

    if (hasPermission) {
      try {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) {
          // Gunakan kamera sesuai state yang terpilih
          final camera = cameras.firstWhere(
            (c) => c.lensDirection == _currentLensDirection,
            orElse: () => cameras.first,
          );

          _cameraController = CameraController(
            camera,
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
          }
        }
      } catch (e) {
        debugPrint('Error initializing camera: $e');
      }
    }
  }

  Future<void> _switchCamera() async {
    if (context.read<ScannerCubit>().state is ScannerLoading) return;
    setState(() {
      _currentLensDirection = _currentLensDirection == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      _isCameraInitialized = false;
      _isFaceDetected = false;
      _isKtpDetected = false;
    });

    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}
    await _cameraController?.dispose();
    _cameraController = null;

    await _checkPermissionAndInitCamera();
  }

  bool _checkIfKtp(RecognizedText recognizedText) {
    final text = recognizedText.text.toLowerCase();
    return text.contains('nik') ||
        text.contains('provinsi') ||
        text.contains('kartu tanda') ||
        text.contains('kewarganegaraan');
  }

  Future<void> _autoCapture() async {
    if (_isCapturing || _capturedImagePath != null) return;
    _isCapturing = true;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wajah dan KTP terdeteksi! Mengambil foto...'),
          duration: Duration(milliseconds: 1000),
        ),
      );
    }

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted && _capturedImagePath == null) {
      await _captureImage();
    }
    _isCapturing = false;
  }

  void _startImageStream() {
    if (_cameraController == null || !_isCameraInitialized) return;

    _cameraController!.startImageStream((CameraImage image) async {
      if (_isProcessingImage || _capturedImagePath != null || _isCapturing) return;
      _isProcessingImage = true;

      try {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage != null) {
          final faces = await _faceDetector.processImage(inputImage);
          final faceDetected = faces.isNotEmpty;

          bool ktpDetected = false;
          if (faceDetected) {
            final recognizedText = await _textRecognizer.processImage(inputImage);
            ktpDetected = _checkIfKtp(recognizedText);
          }

          if (mounted) {
            setState(() {
              _isFaceDetected = faceDetected;
              _isKtpDetected = ktpDetected;
            });

            if (faceDetected && ktpDetected) {
              _autoCapture();
            }
          }
        }
      } catch (e) {
        debugPrint('Error processing image for face and KTP detection: $e');
      } finally {
        _isProcessingImage = false;
      }
    });
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
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

  Future<void> _captureImage() async {
    if (context.read<ScannerCubit>().state is ScannerLoading) return;

    try {
      String imagePath = "simulated_path.jpg"; // Path fallback

      if (_isCameraInitialized && _cameraController != null) {
        try {
          await _cameraController!.stopImageStream();
        } catch (_) {}
        // Ambil gambar beneran menggunakan package camera
        final XFile file = await _cameraController!.takePicture();
        imagePath = file.path;
      } else {
        // Jika pakai emulator / fallback (Tanpa kamera fisik)
        await Future.delayed(const Duration(milliseconds: 500));
      }

      setState(() {
        _capturedImagePath = imagePath;
      });
    } catch (e) {
      debugPrint('Error capturing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil gambar')),
        );
      }
    }
  }

  void _retakeImage() {
    setState(() {
      _capturedImagePath = null;
      _isFaceDetected = false;
      _isKtpDetected = false;
    });
    _startImageStream();
  }

  void _uploadImage() {
    if (_capturedImagePath == null) return;
    context.read<ScannerCubit>().uploadSelfieWithKtp(_capturedImagePath!);
  }

  Widget _buildCapturedPreview() {
    if (_capturedImagePath == "simulated_path.jpg") {
      return Container(
        color: Colors.grey[850],
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.greenAccent),
            SizedBox(height: 16),
            Text(
              'Pratinjau Hasil Foto (Simulator)',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Gambar berhasil disimulasikan.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    } else {
      return Image.file(
        File(_capturedImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
  }

  void _showResultDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                // Tutup popup lalu kembali ke Home Page
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    try {
      _cameraController?.stopImageStream();
    } catch (_) {}
    _cameraController?.dispose();
    _faceDetector.close();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,

      body: BlocConsumer<ScannerCubit, ScannerState>(
        listener: (context, state) {
          if (state is ScannerSuccess) {
            final entity = state.verificationResult;
            setState(() {
              _capturedImagePath = null;
            });
            _showResultDialog(
              'SUKSES!',
              'Status: ${entity.status}\nNama: ${entity.nama}\nNIK: ${entity.nik}\nSkor Liveness: ${entity.livenessScore}%',
            );
          } else if (state is ScannerFailure) {
            _showResultDialog('Error', state.errorMessage);
          }
        },
        builder: (context, state) {
          final isUploading = state is ScannerLoading;

          return Container(
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withAlpha(26), // soft primary tint
                  theme.colorScheme.surface,
                  theme.colorScheme.secondary.withAlpha(13), // soft secondary tint
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(width: 15),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: Icon(Icons.arrow_back_rounded),
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.15),
                      Text(
                        "Demo Scanner",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        onPressed: _capturedImagePath != null || isUploading ? null : _switchCamera,
                        icon: Icon(
                          Icons.flip_camera_android,
                          color: _capturedImagePath != null || isUploading ? Colors.grey : null,
                        ),
                      ),
                      SizedBox(width: 15),
                    ],
                  ),
                  // Petunjuk
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      'Posisikan Wajah dan KTP Anda pada bingkai',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),

                  // Area Kamera
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: AspectRatio(
                          aspectRatio: 9 / 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white24, width: 1),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Pratinjau Kamera / Foto Hasil
                                _capturedImagePath != null
                                    ? _buildCapturedPreview()
                                    : (_isCameraInitialized && _cameraController != null
                                        ? CameraPreview(_cameraController!)
                                        : _buildMockCameraPreview()),

                                // Overlay Selfie + KTP 1 Frame (Hanya tampil saat mode kamera)
                                if (_capturedImagePath == null)
                                  CustomPaint(
                                    size: Size.infinite,
                                    painter: SelfieKtpOverlayPainter(),
                                  ),

                                // Notifikasi Deteksi Wajah & KTP (Hanya tampil saat mode kamera)
                                if (_isCameraInitialized && _capturedImagePath == null)
                                  Positioned(
                                    top: 16,
                                    left: 16,
                                    right: 16,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: (_isFaceDetected && _isKtpDetected)
                                                ? Colors.green.withAlpha(204)
                                                : Colors.orange.withAlpha(204),
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                (_isFaceDetected && _isKtpDetected)
                                                    ? Icons.check_circle
                                                    : Icons.info_outline,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                (_isFaceDetected && _isKtpDetected)
                                                    ? 'Siap! Mengambil gambar...'
                                                    : 'Posisikan Wajah & KTP Anda',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            _buildStatusBadge(
                                              label: 'Wajah',
                                              isDetected: _isFaceDetected,
                                            ),
                                            const SizedBox(width: 8),
                                            _buildStatusBadge(
                                              label: 'KTP',
                                              isDetected: _isKtpDetected,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                // Loading Indicator saat upload
                                if (isUploading)
                                  Container(
                                    color: Colors.black54,
                                    child: const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'Mengunggah Gambar...',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Panel Hasil & Tombol Eksekusi
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        if (_capturedImagePath == null)
                          // SizedBox(
                          //   width: double.infinity,
                          //   height: 56,
                          //   child: ElevatedButton.icon(
                          //     onPressed: isUploading ? null : _captureImage,
                          //     style: ElevatedButton.styleFrom(
                          //       backgroundColor: theme.colorScheme.primary,
                          //       foregroundColor: Colors.white,
                          //       shape: RoundedRectangleBorder(
                          //         borderRadius: BorderRadius.circular(16),
                          //       ),
                          //     ),
                          //     icon: const Icon(Icons.camera_alt),
                          //     label: const Text(
                          //       'Ambil Foto',
                          //       style: TextStyle(
                          //         fontSize: 16,
                          //         fontWeight: FontWeight.bold,
                          //       ),
                          //     ),
                          //   ),
                          // )
                          SizedBox()
                        else
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 56,
                                  child: OutlinedButton.icon(
                                    onPressed: isUploading ? null : _retakeImage,
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: theme.colorScheme.primary, width: 2),
                                      foregroundColor: theme.colorScheme.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text(
                                      'Ulangi',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SizedBox(
                                  height: 56,
                                  child: ElevatedButton.icon(
                                    onPressed: isUploading ? null : _uploadImage,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    icon: const Icon(Icons.cloud_upload),
                                    label: const Text(
                                      'Kirim Foto',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge({required String label, required bool isDetected}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDetected ? Colors.green.withAlpha(204) : Colors.red.withAlpha(204),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDetected ? Icons.check : Icons.close,
            color: Colors.white,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            '$label: ${isDetected ? 'OK' : 'Belum'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockCameraPreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.camera_alt, size: 80, color: Colors.white24),
        const SizedBox(height: 16),
        const Text(
          'Pratinjau Kamera Simulator',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          _isPermissionGranted
              ? 'Kamera fisik tidak terdeteksi'
              : 'Membutuhkan izin kamera',
          style: const TextStyle(color: Colors.white30, fontSize: 12),
        ),
      ],
    );
  }
}

class SelfieKtpOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // 1. Gambar Oval untuk Wajah di posisi atas
    final faceCenterY = size.height * kFaceOverlayCenterYRatio;
    final faceRect = Rect.fromCenter(
      center: Offset(size.width / 2, faceCenterY),
      width: size.width * kFaceOverlayWidthRatio,
      height: size.height * kFaceOverlayHeightRatio,
    );
    canvas.drawOval(faceRect, paint);

    // 2. Gambar Persegi Panjang untuk KTP di posisi bawah/dada
    final ktpCenterY = size.height * kKtpOverlayCenterYRatio;
    final ktpRect = Rect.fromCenter(
      center: Offset(size.width / 2, ktpCenterY),
      width: size.width * kKtpOverlayWidthRatio,
      height: size.height * kKtpOverlayHeightRatio,
    );
    final ktpRRect = RRect.fromRectAndRadius(
      ktpRect,
      const Radius.circular(12),
    );
    canvas.drawRRect(ktpRRect, paint);

    // Opsional: Tambahkan teks panduan
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Teks Wajah
    textPainter.text = const TextSpan(
      text: "WAJAH",
      style: TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, faceRect.bottom + 8),
    );

    // Teks KTP
    textPainter.text = const TextSpan(
      text: "KTP",
      style: TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, ktpRect.bottom + 8),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
