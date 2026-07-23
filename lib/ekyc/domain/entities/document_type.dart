enum DocumentType { ktp, sim, passport }

extension DocumentTypeExtension on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.ktp:
        return 'KTP';
      case DocumentType.sim:
        return 'SIM';
      case DocumentType.passport:
        return 'Passport';
    }
  }

  String get filePrefix {
    switch (this) {
      case DocumentType.ktp:
        return 'ktp';
      case DocumentType.sim:
        return 'sim';
      case DocumentType.passport:
        return 'pasport'; // requested name: pasport
    }
  }
}
