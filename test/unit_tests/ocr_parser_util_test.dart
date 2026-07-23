import 'package:flutter_test/flutter_test.dart';
import 'package:omnibyte_demo/core/utils/ocr_parser_util.dart';
import 'package:omnibyte_demo/ekyc/domain/entities/document_type.dart';

void main() {
  group('OcrParserUtil MRZ (Passport)', () {
    test('should parse valid TD3 MRZ correctly', () {
      final rawText = '''
PASPOR
PASSPORT
P<IDNHIDAYAT<<RIZKY<NUR<<<<<<<<<<<<<<<<<<<<<<
A1234567<7IDN8001014M2601019<<<<<<<<<<<<<<06
''';
      
      final result = OcrParserUtil.parse(rawText, hint: DocumentType.passport);
      
      expect(result.documentType, 'Passport');
      expect(result.documentNumber, 'A1234567');
      expect(result.fullName, 'Rizky Nur Hidayat');
      expect(result.nationality, 'IDN');
      expect(result.birthDate, '1980-01-01');
      expect(result.gender, 'M');
      expect(result.expiryDate, '2026-01-01');
      expect(result.mrzDetected, true);
    });
  });

  group('OcrParserUtil KTP', () {
    test('should parse NIK, Name, Birth, Gender, Address with OCR errors corrected', () {
      final rawText = '''
PROVINSI JAWA BARAT
KABUPATEN BANDUNG
NIK : 3273O123456789O1
Nama: RIZKY NUR HIDAYAT
Tempat/Tgl Lahir: BANDUNG, 17-O8-1995
Jenis Kelamin: LAKI-LAKI  Gol. Darah: O
Alamat: JL. RAYA BANDUNG NO. 123
RT/RW: OO5/OO2
Kel/Desa: DESA MAJU
Kecamatan: CIBIRU
Agama: ISLAM
Status Perkawinan: BELUM KAWIN
Pekerjaan: MAHASISWA
Kewarganegaraan: WNI
Berlaku Hingga: SEUMUR HIDUP
''';

      final result = OcrParserUtil.parse(rawText, hint: DocumentType.ktp);

      expect(result.documentType, 'KTP');
      expect(result.documentNumber, '3273012345678901'); // corrected O -> 0
      expect(result.fullName, 'Rizky Nur Hidayat');
      expect(result.birthPlace, 'Bandung');
      expect(result.birthDate, '1995-08-17'); // corrected O -> 0
      expect(result.gender, 'M');
      expect(result.address, 'Jl. Raya Bandung No. 123, Rt/rw: Oo5/oo2, Kel/desa: Desa Maju, Kecamatan: Cibiru');
      expect(result.expiryDate, 'Seumur Hidup');
      expect(result.mrzDetected, false);
    });
  });

  group('OcrParserUtil SIM', () {
    test('should parse SIM details', () {
      final rawText = '''
SURAT IZIN MENGEMUDI
POLDA METRO JAYA
A
1. NAMA: RIZKY NUR HIDAYAT
2. TEMPAT/TGL LAHIR: JAKARTA, 17/08/1995
3. GOL. DARAH: O - SEX: L
4. ALAMAT: JL. SUDIRMAN NO. 10
   JAKARTA PUSAT
5. BERLAKU HINGGA: 17/O8/2O3O
''';

      final result = OcrParserUtil.parse(rawText, hint: DocumentType.sim);

      expect(result.documentType, 'SIM');
      expect(result.fullName, 'Rizky Nur Hidayat');
      expect(result.birthPlace, 'Jakarta');
      expect(result.birthDate, '1995-08-17');
      expect(result.gender, 'M');
      expect(result.expiryDate, '2030-08-17'); // corrected O -> 0
      expect(result.mrzDetected, false);
    });
  });
}
