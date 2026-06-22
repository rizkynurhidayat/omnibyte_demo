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
    // CONTOH KODE ASLI UNTUK INTEGRASI API (Commented out untuk saat ini)
    // -------------------------------------------------------------
    /*
    try {
      final fileName = imagePath.split('/').last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(imagePath, filename: fileName),
        // 'other_param': 'value', // TODO: Sesuaikan dengan kebutuhan body request API
      });

      final response = await dio.post(
        '/verify/selfie-ktp', // TODO: Sesuaikan path endpoint API
        data: formData,
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
