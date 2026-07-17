import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ekyc_bloc.dart';
import '../bloc/ekyc_event.dart';
import '../bloc/ekyc_state.dart';
import '../widgets/ktp_scanner_view.dart';
import '../widgets/selfie_ktp_scanner_view.dart';

class EkycPage extends StatefulWidget {
  const EkycPage({super.key});

  @override
  State<EkycPage> createState() => _EkycPageState();
}

class _EkycPageState extends State<EkycPage> {
  @override
  void initState() {
    super.initState();
    // Static orientation lock to portrait during E-KYC flow
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    
    // Start flow
    context.read<EkycBloc>().add(ResetEkyc());
  }

  @override
  void dispose() {
    // Restore normal rotation orientations upon exiting
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  int _getCurrentStep(EkycState state) {
    if (state is EkycInitial || state is EkycStepKtpActive || state is EkycStepKtpCompleted) {
      return 0;
    } else if (state is EkycStepSelfieKtpActive || state is EkycStepSelfieKtpCompleted) {
      return 1;
    } else {
      return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pendaftaran e-KYC',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: Colors.grey[50],
      body: BlocConsumer<EkycBloc, EkycState>(
        listener: (context, state) {
          if (state is EkycFailureState) {
            // Display standard error dialog
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text('Terjadi Masalah'),
                  ],
                ),
                content: Text(state.errorMessage),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      // Restore the fallback state safely via event
                      context.read<EkycBloc>().add(RestoreState(state.fallbackState));
                    },
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }
        },
        builder: (context, state) {
          final currentStep = _getCurrentStep(state);

          return Stack(
            children: [
              Column(
                children: [
                  // Step Indicator Header
                  _buildStepperHeader(currentStep),

                  // Main Wizard Step Body
                  Expanded(
                    child: _buildStepBody(context, state),
                  ),
                ],
              ),

              // Fullscreen Transparent Loading Overlay during API POST (Phase 5)
              if (state is EkycSubmittingState)
                Container(
                  color: Colors.black.withAlpha(150),
                  child: const Center(
                    child: Card(
                      color: Colors.white,
                      margin: EdgeInsets.all(32),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 20),
                            Text(
                              'Verifikasi Biometrik',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Mengunggah data & mencocokkan wajah...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStepperHeader(int currentStep) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          _buildStepNode(0, 'Pindai KTP', currentStep >= 0, currentStep == 0),
          _buildStepDivider(currentStep >= 1),
          _buildStepNode(1, 'Selfie + KTP', currentStep >= 1, currentStep == 1),
          _buildStepDivider(currentStep >= 2),
          _buildStepNode(2, 'Hasil Verifikasi', currentStep >= 2, currentStep == 2),
        ],
      ),
    );
  }

  Widget _buildStepNode(int index, String label, bool isDone, bool isActive) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDone ? Theme.of(context).colorScheme.primary : Colors.grey[300],
              shape: BoxShape.circle,
              border: isActive
                  ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2.5)
                  : null,
            ),
            child: Center(
              child: isDone && !isActive
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isDone ? Colors.white : Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider(bool isDone) {
    return Container(
      width: 40,
      height: 2,
      color: isDone ? Theme.of(context).colorScheme.primary : Colors.grey[300],
    );
  }

  Widget _buildStepBody(BuildContext context, EkycState state) {
    if (state is EkycStepKtpActive) {
      return KtpScannerView(
        onCaptured: (ktpPath, croppedFacePath, ocrJsonPath, nik, name) {
          context.read<EkycBloc>().add(KtpCaptured(
                ktpPath: ktpPath,
                croppedFacePath: croppedFacePath,
                ocrJsonPath: ocrJsonPath,
                nik: nik,
                name: name,
              ));
        },
      );
    }

    if (state is EkycStepKtpCompleted) {
      return _buildKtpReviewScreen(context, state);
    }

    if (state is EkycStepSelfieKtpActive) {
      return SelfieKtpScannerView(
        expectedNik: state.nik,
        expectedName: state.name,
        ktpPath: state.ktpPath,
        onCaptured: (selfiePath, croppedSelfieFacePath, croppedKtpFacePath) {
          context.read<EkycBloc>().add(SelfieKtpCaptured(
                selfiePath: selfiePath,
                croppedSelfieFacePath: croppedSelfieFacePath,
                croppedKtpFacePath: croppedKtpFacePath,
              ));
        },
      );
    }

    if (state is EkycStepSelfieKtpCompleted) {
      return _buildSelfieKtpReviewScreen(context, state);
    }

    if (state is EkycSuccessState) {
      return _buildSuccessScreen(context, state);
    }

    // Default fallback loading state
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildKtpReviewScreen(BuildContext context, EkycStepKtpCompleted state) {
    final isSimulated = state.ktpPath == 'simulated_ktp.jpg';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verifikasi Hasil Pemindaian KTP',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pastikan data teks teridentifikasi dengan benar dan potongan wajah terlihat jelas.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // KTP Photo Preview
          const Text(
            'Foto KTP Utuh',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 180,
              width: double.infinity,
              color: Colors.grey[200],
              child: isSimulated
                  ? const Icon(Icons.credit_card, size: 80, color: Colors.grey)
                  : Image.file(File(state.ktpPath), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 20),

          // Row with Face crop and Extracted text
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Face crop
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wajah KTP',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 100,
                      height: 120,
                      color: Colors.grey[200],
                      child: isSimulated
                          ? const Icon(Icons.person, size: 50, color: Colors.grey)
                          : Image.file(File(state.croppedFacePath), fit: BoxFit.cover),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),

              // Extracted Text Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detail Terdeteksi',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildExtractedField('NIK', state.nik),
                    const SizedBox(height: 12),
                    _buildExtractedField('Nama', state.name),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Controls
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(color: Theme.of(context).colorScheme.primary.withAlpha(100)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    context.read<EkycBloc>().add(ResetEkyc());
                  },
                  child: const Text('Foto Ulang KTP'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    context.read<EkycBloc>().add(StartSelfieKtpScan(
                      ktpPath: state.ktpPath,
                      croppedFacePath: state.croppedFacePath,
                      ocrJsonPath: state.ocrJsonPath,
                      nik: state.nik,
                      name: state.name,
                    ));
                  },
                  child: const Text('Lanjutkan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildSelfieKtpReviewScreen(BuildContext context, EkycStepSelfieKtpCompleted state) {
    final isSimulated = state.selfiePath == 'simulated_selfie.jpg';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pratinjau Selfie & KTP',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Harap tinjau foto selfie memegang KTP Anda sebelum melakukan verifikasi.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Selfie Preview and Cropped Face Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Selfie Preview
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Foto Selfie + KTP',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 240,
                        color: Colors.grey[200],
                        child: isSimulated
                            ? const Center(child: Icon(Icons.face, size: 80, color: Colors.grey))
                            : Image.file(File(state.selfiePath), fit: BoxFit.cover, width: double.infinity),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Cropped face cards side-by-side or stacked
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wajah Selfie',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 100,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: state.croppedSelfieFacePath == 'simulated_selfie_face.jpg'
                            ? const Center(child: Icon(Icons.person, size: 40, color: Colors.grey))
                            : Image.file(File(state.croppedSelfieFacePath), fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Wajah KTP (dari Selfie)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 100,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: state.croppedKtpFacePath == 'simulated_ktp_face.jpg'
                            ? const Center(child: Icon(Icons.person, size: 40, color: Colors.grey))
                            : Image.file(File(state.croppedKtpFacePath), fit: BoxFit.cover),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Controls
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(color: Theme.of(context).colorScheme.primary.withAlpha(100)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    // Retry Selfie Scan
                    context.read<EkycBloc>().add(StartSelfieKtpScan(
                      ktpPath: state.ktpPath,
                      croppedFacePath: state.croppedFacePath,
                      ocrJsonPath: state.ocrJsonPath,
                      nik: state.nik,
                      name: state.name,
                    ));
                  },
                  child: const Text('Ulangi Selfie'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    context.read<EkycBloc>().add(SubmitVerification());
                  },
                  child: const Text('Verifikasi Sekarang'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen(BuildContext context, EkycSuccessState state) {
    final result = state.verificationResult;
    final statusLower = result.status.toLowerCase();
    final verificationLower = result.verificationResult?.toLowerCase();
    
    // Status is 'pending' or 'processing' before the verification is actually done.
    final isPending = statusLower == 'pending' || statusLower == 'processing';

    // Once completed, we look at verificationResult to determine success.
    // Assuming backend returns 'Auto Approved' or 'Approved' on success.
    final isSuccess = statusLower == 'completed' && (verificationLower == 'auto approved' || verificationLower == 'approved');
    final isFailed = statusLower == 'failed' || (statusLower == 'completed' && verificationLower == 'rejected');

    if (isPending && result.tusUploadId != null) {
      return _buildPendingScreen(context, result.tusUploadId!);
    }

    // Determine colors based on status (green for completed, red for failed, etc.)
    final Color iconColor = isSuccess 
        ? Theme.of(context).colorScheme.secondary 
        : Theme.of(context).colorScheme.error;
    final IconData iconData = isSuccess 
        ? Icons.check_circle_rounded 
        : Icons.cancel_rounded;
    final String title = isSuccess ? 'Verifikasi Berhasil!' : 'Verifikasi Gagal';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  iconData,
                  color: iconColor,
                  size: 72,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  result.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 24),
                
                const Divider(),
                const SizedBox(height: 12),

                _buildResultItem('NIK', result.nik ?? '-'),
                _buildResultItem('Nama', result.nama ?? '-'),
                if (result.similarityScore != null)
                  _buildResultItem('Skor Kemiripan', '${result.similarityScore}%'),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                if (isSuccess)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        // Navigate back to Home
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text(
                        'Kembali ke Home',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            context.read<EkycBloc>().add(ResetEkyc());
                          },
                          child: const Text(
                            'Ulangi Verifikasi',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Theme.of(context).colorScheme.primary),
                            foregroundColor: Theme.of(context).colorScheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                          child: const Text(
                            'Kembali ke Home',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingScreen(BuildContext context, String tusUploadId) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hourglass_empty_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 72,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Verifikasi Sedang Diproses',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Data Anda telah berhasil diunggah. Silakan klik tombol di bawah untuk memeriksa status verifikasi secara manual.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Refresh Status',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: () {
                      context.read<EkycBloc>().add(RefreshVerificationStatus(tusUploadId));
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
