import 'package:dio/dio.dart';

class DioClient {
  final Dio dio;

  DioClient() : dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.dummy-domain.com/v1', // TODO: Ubah BaseURL di sini
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // 'Authorization': 'Bearer YOUR_TOKEN', // TODO: Tambahkan Token API
      },
    ),
  ) {
    // Interceptor untuk memunculkan log Request/Response API di console
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
    ));
  }
}
