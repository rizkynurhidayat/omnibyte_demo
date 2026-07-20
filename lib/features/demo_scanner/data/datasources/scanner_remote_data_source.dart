import 'dart:async';
import 'package:dio/dio.dart';
import '../models/verification_model.dart';

abstract class ScannerRemoteDataSource {
  Future<VerificationModel> submitSelfieWithKtp(String imagePath);
}

class ScannerRemoteDataSourceImpl implements ScannerRemoteDataSource {
  final Dio dio;

  ScannerRemoteDataSourceImpl(this.dio);

  @override
  Future<VerificationModel> submitSelfieWithKtp(String imagePath) async {
    // -------------------------------------------------------------
    // CONTOH KODE ASLI UNTUK INTEGRASI API DENGAN TUS
    // -------------------------------------------------------------
    /*
    try {
      final xFile = XFile(imagePath);
      final fileName = imagePath.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();
      final fileType = 'application/$extension';

      final client = TusClient(
        url: 'https://tus-upload.coworker.id/files/',
        file: xFile,
        chunkSize: 1024 * 1024,
        metadata: {
          'file_name': fileName,
          'filetype': fileType,
        },
      );

      final completer = Completer<String>();

      client.startUpload(
        onComplete: (response) {
          completer.complete(client.uploadUrl.toString());
        },
        onError: (e) {
          completer.completeError(e.message);
        },
      );

      final uploadUrl = await completer.future;

      final response = await dio.post(
        '/verify/selfie-ktp', // TODO: Sesuaikan path endpoint API
        data: {
          'image_url': uploadUrl,
        },
      );

      if (response.statusCode == 200) {
        return VerificationModel.fromJson(response.data);
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to submit image: $e');
    }
    */

    // -------------------------------------------------------------
    // DUMMY RESPONSE (Sesuai dengan permintaan)
    // -------------------------------------------------------------
    await Future.delayed(const Duration(seconds: 3)); // Simulasi loading jaringan

    final dummyJson = {
      "status": "success",
      "message": "Verifikasi KTP dan Wajah berhasil.",
      "data": {
        "nik": "3273123456780001",
        "nama": "Budi Santoso Dummy",
        "liveness_score": 98.5
      }
    };

    return VerificationModel.fromJson(dummyJson);
  }
}
