import 'package:equatable/equatable.dart';
import 'ekyc_state.dart';
import '../../domain/entities/document_type.dart';

abstract class EkycEvent extends Equatable {
  const EkycEvent();

  @override
  List<Object?> get props => [];
}


class ResetEkyc extends EkycEvent {
  final DocumentType documentType;

  const ResetEkyc(this.documentType);

  @override
  List<Object?> get props => [documentType];
}

class KtpCaptured extends EkycEvent {
  final String ktpPath;
  final String croppedFacePath;
  final String ocrJsonPath;
  final String nik;
  final String name;

  const KtpCaptured({
    required this.ktpPath,
    required this.croppedFacePath,
    required this.ocrJsonPath,
    required this.nik,
    required this.name,
  });

  @override
  List<Object?> get props => [ktpPath, croppedFacePath, ocrJsonPath, nik, name];
}

class StartSelfieKtpScan extends EkycEvent {
  final String ktpPath;
  final String croppedFacePath;
  final String ocrJsonPath;
  final String nik;
  final String name;

  const StartSelfieKtpScan({
    required this.ktpPath,
    required this.croppedFacePath,
    required this.ocrJsonPath,
    required this.nik,
    required this.name,
  });

  @override
  List<Object?> get props => [ktpPath, croppedFacePath, ocrJsonPath, nik, name];
}

class SelfieKtpCaptured extends EkycEvent {
  final String selfiePath;
  final String croppedSelfieFacePath;
  final String croppedKtpFacePath;

  const SelfieKtpCaptured({
    required this.selfiePath,
    required this.croppedSelfieFacePath,
    required this.croppedKtpFacePath,
  });

  @override
  List<Object?> get props => [selfiePath, croppedSelfieFacePath, croppedKtpFacePath];
}

class RestoreState extends EkycEvent {
  final EkycState state;

  const RestoreState(this.state);

  @override
  List<Object?> get props => [state];
}

class SubmitVerification extends EkycEvent {}

class RefreshVerificationStatus extends EkycEvent {
  final String tusUploadId;

  const RefreshVerificationStatus(this.tusUploadId);

  @override
  List<Object?> get props => [tusUploadId];
}

class SetFailure extends EkycEvent {
  final String errorMessage;

  const SetFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
