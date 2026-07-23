import 'package:equatable/equatable.dart';
import '../../domain/entities/ekyc_verification_entity.dart';
import '../../domain/entities/document_type.dart';

abstract class EkycState extends Equatable {
  const EkycState();

  @override
  List<Object?> get props => [];
}

class EkycInitial extends EkycState {}

class EkycStepKtpActive extends EkycState {
  final DocumentType documentType;

  const EkycStepKtpActive(this.documentType);

  @override
  List<Object?> get props => [documentType];
}

class EkycStepKtpCompleted extends EkycState {
  final DocumentType documentType;
  final String ktpPath;
  final String croppedFacePath;
  final String ocrJsonPath;
  final String nik;
  final String name;

  const EkycStepKtpCompleted({
    required this.documentType,
    required this.ktpPath,
    required this.croppedFacePath,
    required this.ocrJsonPath,
    required this.nik,
    required this.name,
  });

  @override
  List<Object?> get props => [documentType, ktpPath, croppedFacePath, ocrJsonPath, nik, name];
}

class EkycStepSelfieKtpActive extends EkycState {
  final DocumentType documentType;
  final String ktpPath;
  final String croppedFacePath;
  final String ocrJsonPath;
  final String nik;
  final String name;

  const EkycStepSelfieKtpActive({
    required this.documentType,
    required this.ktpPath,
    required this.croppedFacePath,
    required this.ocrJsonPath,
    required this.nik,
    required this.name,
  });

  @override
  List<Object?> get props => [documentType, ktpPath, croppedFacePath, ocrJsonPath, nik, name];
}

class EkycStepSelfieKtpCompleted extends EkycState {
  final DocumentType documentType;
  final String ktpPath;
  final String croppedFacePath;
  final String ocrJsonPath;
  final String nik;
  final String name;
  final String selfiePath;
  final String croppedSelfieFacePath;
  final String croppedKtpFacePath;

  const EkycStepSelfieKtpCompleted({
    required this.documentType,
    required this.ktpPath,
    required this.croppedFacePath,
    required this.ocrJsonPath,
    required this.nik,
    required this.name,
    required this.selfiePath,
    required this.croppedSelfieFacePath,
    required this.croppedKtpFacePath,
  });

  @override
  List<Object?> get props => [
        documentType,
        ktpPath,
        croppedFacePath,
        ocrJsonPath,
        nik,
        name,
        selfiePath,
        croppedSelfieFacePath,
        croppedKtpFacePath,
      ];
}

class EkycComparingLocalState extends EkycState {
  const EkycComparingLocalState();
}

class EkycSubmittingState extends EkycState {
  const EkycSubmittingState();
}

class EkycSuccessState extends EkycState {
  final EkycVerificationEntity verificationResult;

  const EkycSuccessState(this.verificationResult);

  @override
  List<Object?> get props => [verificationResult];
}

class EkycFailureState extends EkycState {
  final String errorMessage;
  final EkycState fallbackState;

  const EkycFailureState({
    required this.errorMessage,
    required this.fallbackState,
  });

  @override
  List<Object?> get props => [errorMessage, fallbackState];
}
