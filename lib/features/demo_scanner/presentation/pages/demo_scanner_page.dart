import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../data/datasources/scanner_remote_data_source.dart';
import '../../data/repositories/scanner_repository_impl.dart';
import '../../domain/usecases/submit_selfie_with_ktp_usecase.dart';

class DemoScannerPage extends StatefulWidget {
  const DemoScannerPage({super.key});

  @override
  State<DemoScannerPage> createState() => _DemoScannerPageState();
}

class _DemoScannerPageState extends State<DemoScannerPage> {
  CameraController? _cameraController;
  bool _isPermissionGranted = false;
  bool _isCameraInitialized = false;
  bool _isUploading = false;

  // Inisialisasi UseCase secara langsung (Untuk di-refactor ke Dependency Injection/BLoC nanti)
  late final SubmitSelfieWithKtpUseCase _submitUseCase;

  @override
  void initState() {
    super.initState();
    // Setup manual dependency untuk demo
    final dio = Dio();
    final remoteDataSource = ScannerRemoteDataSourceImpl(dio);
    final repository = ScannerRepositoryImpl(remoteDataSource);
    _submitUseCase = SubmitSelfieWithKtpUseCase(repository);

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
          // Gunakan kamera depan karena ini selfie sambil pegang KTP
          final camera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          );

          _cameraController = CameraController(
            camera,
            ResolutionPreset.high,
            enableAudio: false,
          );

          await _cameraController!.initialize();
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

  Future<void> _captureAndUploadImage() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
      String imagePath = "simulated_path.jpg"; // Path fallback

      if (_isCameraInitialized && _cameraController != null) {
        // Ambil gambar beneran menggunakan package camera
        final XFile file = await _cameraController!.takePicture();
        imagePath = file.path;
      } else {
        // Jika pakai emulator / fallback (Tanpa kamera fisik)
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Panggil API (Akan mengembalikan Dummy Response sesuai setup)
      final result = await _submitUseCase(imagePath);

      if (!mounted) return;

      result.fold(
        (failure) {
          setState(() {
            _isUploading = false;
          });
          _showResultDialog('Error', failure.message);
        },
        (entity) {
          setState(() {
            _isUploading = false;
          });
          _showResultDialog(
            'SUKSES!',
            'Status: ${entity.status}\nNama: ${entity.nama}\nNIK: ${entity.nik}\nSkor Liveness: ${entity.livenessScore}%',
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
      });
      _showResultDialog('Error', 'Terjadi kesalahan sistem.');
    }
  }

  void _showResultDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
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
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,

      body: Container(
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
                  SizedBox(width: 85),
                  Text(
                    "Demo Scanner",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Spacer(),
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
                      // aspectRatio: 9 / 16,
                      aspectRatio: 3 / 4,
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
                            // Pratinjau Kamera
                            _isCameraInitialized && _cameraController != null
                                ? CameraPreview(_cameraController!)
                                : _buildMockCameraPreview(),

                            // Overlay Selfie + KTP 1 Frame
                            CustomPaint(
                              size: Size.infinite,
                              painter: SelfieKtpOverlayPainter(),
                            ),

                            // Loading Indicator saat upload
                            if (_isUploading)
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
                                        'Mengunggah Gambar ke API...',
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
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _captureAndUploadImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text(
                          'Ambil & Kirim',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
    final faceCenterY = size.height * 0.35; // agak ke atas
    final faceRect = Rect.fromCenter(
      center: Offset(size.width / 2, faceCenterY),
      width: size.width * 0.55,
      height: size.height * 0.40,
    );
    canvas.drawOval(faceRect, paint);

    // 2. Gambar Persegi Panjang untuk KTP di posisi bawah/dada
    final ktpCenterY = size.height * 0.75;
    final ktpRect = Rect.fromCenter(
      center: Offset(size.width / 2, ktpCenterY),
      width: size.width * 0.70,
      height: size.height * 0.25,
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
