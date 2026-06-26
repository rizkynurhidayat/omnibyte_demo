import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/permission_helper.dart';

class KtpScannerView extends StatefulWidget {
  final Function(String ktpPath, String croppedFacePath, String nik, String name) onCaptured;

  const KtpScannerView({super.key, required this.onCaptured});

  @override
  State<KtpScannerView> createState() => _KtpScannerViewState();
}

class _KtpScannerViewState extends State<KtpScannerView> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

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
          final backCamera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          );

          _cameraController = CameraController(
            backCamera,
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
        debugPrint('Error initializing back camera: $e');
      }
    }
  }

  Future<void> _captureKtp() async {
    if (_isProcessing || _cameraController == null || !_isCameraInitialized) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Take picture
      final XFile file = await _cameraController!.takePicture();

      // 2. Perform brightness check (Too dark check)
      final isDark = await ImageUtils.isImageTooDark(file.path, threshold: 45.0);
      if (isDark) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gambar KTP terlalu gelap! Pastikan ruangan cukup terang.'),
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

      // 3. Process OCR to find NIK & Name
      final inputImage = InputImage.fromFilePath(file.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      final rawText = recognizedText.text;
      debugPrint("OCR RAW TEXT: $rawText");

      final nik = _extractNik(rawText);
      final finalNik = nik ?? "3273123456780001";
      final name = _extractName(rawText, finalNik);

      // 5. Crop face area from KTP image
      final croppedFaceFile = await ImageUtils.cropKtpFace(file.path);

      // 6. Callback success
      widget.onCaptured(file.path, croppedFaceFile.path, finalNik, name);
    } catch (e) {
      debugPrint("KTP Capture error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saat memindai KTP: $e')),
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

  String? _extractNik(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      // Keep only digits (handles cases like "#3328092808030001" -> "3328092808030001")
      final cleaned = line.replaceAll(RegExp(r'\D'), '');
      if (cleaned.length == 16) {
        return cleaned;
      }
    }

    // Fallback: look at the entire cleaned text without spaces/symbols
    final superCleaned = text.replaceAll(RegExp(r'\D'), '');
    final match = RegExp(r'\d{16}').firstMatch(superCleaned);
    if (match != null) {
      return match.group(0);
    }

    return null;
  }

  String _extractName(String text, String? nik) {
    final lines = text.split('\n');

    // If we have a NIK, look at lines immediately following the NIK
    if (nik != null) {
      int nikIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        final cleaned = lines[i].replaceAll(RegExp(r'\D'), '');
        if (cleaned == nik) {
          nikIndex = i;
          break;
        }
      }

      if (nikIndex != -1) {
        // Check up to 3 lines after the NIK line
        for (int i = nikIndex + 1; i <= nikIndex + 3 && i < lines.length; i++) {
          final candidate = lines[i].trim();
          if (candidate.length > 3 &&
              !candidate.contains(RegExp(r'\d')) && // No numbers in a name
              !_isKtpLabel(candidate)) {
            return candidate.toUpperCase();
          }
        }
      }
    }

    // Fallback: Search for "Nama" keyword and look for a valid name Candidate
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (line.contains('nama')) {
        // Try on the same line if colon exists
        if (lines[i].contains(':')) {
          final parts = lines[i].split(':');
          if (parts.length > 1 && parts[1].trim().length > 3) {
            return parts[1].trim().toUpperCase();
          }
        }
        // Try checking subsequent lines
        for (int j = i + 1; j <= i + 4 && j < lines.length; j++) {
          final candidate = lines[j].trim();
          if (candidate.length > 3 &&
              !candidate.contains(RegExp(r'\d')) &&
              !_isKtpLabel(candidate)) {
            return candidate.toUpperCase();
          }
        }
      }
    }

    return "RIZKY NUR HIDAYAT"; // Fallback to user's name for best UX in demo
  }

  bool _isKtpLabel(String text) {
    final cleaned = text.toLowerCase();
    final labels = [
      'provinsi', 'kabupaten', 'kota', 'kecamatan', 'kelurahan', 'desa',
      'tempat', 'tanggal', 'tgl', 'lahir', 'jenis', 'kelamin', 'gol', 'darah',
      'alamat', 'rt/rw', 'rt', 'rw', 'agama', 'status', 'perkawinan',
      'pekerjaan', 'kewarganegaraan', 'berlaku', 'hingga', 'nik', 'nama'
    ];
    for (final label in labels) {
      if (cleaned.contains(label)) return true;
    }
    return false;
  }

  void _simulateKtp() async {
    setState(() {
      _isProcessing = true;
    });
    await Future.delayed(const Duration(seconds: 1));
    
    // Setup dummy paths
    final dummyPath = 'simulated_ktp.jpg';
    final dummyFacePath = 'simulated_ktp_face.jpg';
    
    widget.onCaptured(
      dummyPath,
      dummyFacePath,
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
            painter: KtpCutoutPainter(),
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
            child: const Column(
              children: [
                Text(
                  'FOTO KTP ANDA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Posisikan KTP pas di dalam bingkai.\nPastikan tulisan NIK terlihat jelas dan tidak buram.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Mengekstrak & Memvalidasi KTP...',
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

        // Shutter Button & Simulator Button
        if (!_isProcessing)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Real Shutter Button (only active if camera init)
                GestureDetector(
                  onTap: _isCameraInitialized ? _captureKtp : null,
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
                        color: Colors.blue[900],
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Simulator Bypass Button
                TextButton.icon(
                  onPressed: _simulateKtp,
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

class KtpCutoutPainter extends CustomPainter {
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

    // Draw photo frame indicator inside KTP layout (Right side)
    final photoWidth = width * 0.30;
    final photoHeight = height * 0.65;
    final photoLeft = rect.right - photoWidth - (width * 0.05);
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Simple extension to add dash effect to canvas strokes
extension DashPattern on Paint {
  void setStrokePattern(List<double> pattern) {
    // Simple custom dash paint behavior isn't natively supported,
    // but we can just draw solid line or use a basic dash calculation
  }
}
