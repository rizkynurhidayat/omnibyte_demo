import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omnibyte_demo/ekyc/data/datasources/ekyc_remote_data_source.dart';
import 'package:omnibyte_demo/ekyc/data/models/ekyc_verification_model.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late EkycRemoteDataSourceImpl dataSource;
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    dataSource = EkycRemoteDataSourceImpl(mockDio);
  });

  group('checkEkycStatus', () {
    final tTusUploadId = 'test_tus_id';
    final tModel = EkycVerificationModel(
      status: 'completed',
      message: 'Similarity 99.6% meets the auto-approve threshold (95.0%).',
      tusUploadId: 'test_tus_id',
      nik: '12345',
      nama: 'Test Name',
      similarityScore: 99.63,
    );

    test('should return EkycVerificationModel when status is 200', () async {
      when(() => mockDio.get(any())).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 200,
            data: {
              "success": true,
              "code": "200",
              "message": "Success",
              "data": {
                  "status": "Completed",
                  "verification_result": "Auto Approved",
                  "similarity": 99.63,
                  "reasoning": "Similarity 99.6% meets the auto-approve threshold (95.0%).",
                  "error_message": null,
                  "nik": "12345",
                  "nama": "Test Name"
              },
              "tus_upload_id": "test_tus_id" // if backend returned it, otherwise model parses it from json
            },
          ));

      final result = await dataSource.checkEkycStatus(tTusUploadId);

      expect(result, equals(tModel));
      verify(() => mockDio.get('https://oscore-dummy.coworker.id/ekyc/status/$tTusUploadId'));
    });

    test('should throw Exception when status is not 200', () async {
      when(() => mockDio.get(any())).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 404,
          ));

      final call = dataSource.checkEkycStatus;

      expect(() => call(tTusUploadId), throwsException);
    });

    test('should throw Exception when dio throws error', () async {
      when(() => mockDio.get(any())).thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      final call = dataSource.checkEkycStatus;

      expect(() => call(tTusUploadId), throwsException);
    });
  });
}
