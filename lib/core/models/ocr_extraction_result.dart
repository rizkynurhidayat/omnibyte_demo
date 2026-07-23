class OcrExtractionResult {
  final String documentType;
  final String documentNumber;
  final String fullName;
  final String birthPlace;
  final String birthDate;
  final String gender;
  final String address;
  final String nationality;
  final String expiryDate;
  final bool mrzDetected;
  final String rawMrzString;
  final String? nik;
  final String? simCategory;

  OcrExtractionResult({
    required this.documentType,
    required this.documentNumber,
    required this.fullName,
    required this.birthPlace,
    required this.birthDate,
    required this.gender,
    required this.address,
    required this.nationality,
    required this.expiryDate,
    required this.mrzDetected,
    required this.rawMrzString,
    this.nik,
    this.simCategory,
  });

  factory OcrExtractionResult.fromJson(Map<String, dynamic> json) {
    return OcrExtractionResult(
      documentType: json['document_type'] ?? 'Unknown',
      documentNumber: json['document_number'] ?? '',
      fullName: json['full_name'] ?? '',
      birthPlace: json['birth_place'] ?? '',
      birthDate: json['birth_date'] ?? '',
      gender: json['gender'] ?? '',
      address: json['address'] ?? '',
      nationality: json['nationality'] ?? '',
      expiryDate: json['expiry_date'] ?? '',
      mrzDetected: json['mrz_detected'] ?? false,
      rawMrzString: json['raw_mrz_string'] ?? '',
      nik: json['nik'],
      simCategory: json['sim_category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'document_type': documentType,
      'document_number': documentNumber,
      'full_name': fullName,
      'birth_place': birthPlace,
      'birth_date': birthDate,
      'gender': gender,
      'address': address,
      'nationality': nationality,
      'expiry_date': expiryDate,
      'mrz_detected': mrzDetected,
      'raw_mrz_string': rawMrzString,
      'nik': nik,
      'sim_category': simCategory,
    };
  }

  @override
  String toString() {
    return 'OcrExtractionResult(type: $documentType, number: $documentNumber, name: $fullName, nik: $nik, cat: $simCategory)';
  }
}
