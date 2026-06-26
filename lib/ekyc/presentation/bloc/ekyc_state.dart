import 'package:equatable/equatable.dart';
import '../../domain/entities/ekyc_verification_entity.dart';

abstract class EkycState extends Equatable {
  const EkycState();

  @override
  List<Object?> get props => [];
}

class EkycInitial extends EkycState {}

class EkycStepKtpActive extends EkycState {}

class EkycStepKtpCompleted extends EkycState {
  final String ktpPath;
  final String croppedFacePath;
  final String nik;
  final String name;

  const EkycStepKtpCompleted({
    required this.ktpPath,
    required this.croppedFacePath,
    required this.nik,
    required this.name,
  });

  @override
  List<Object?> get props => [ktpPath, croppedFacePath, nik, name];
}

class EkycStepLivenessActive extends EkycState {
  final String ktpPath;
  final String croppedFacePath;
  final String nik;
  final String name;

  const EkycStepLivenessActive({
    required this.ktpPath,
    required this.croppedFacePath,
    required this.nik,
    required this.name,
  });

  @override
  List<Object?> get props => [ktpPath, croppedFacePath, nik, name];
}

class EkycStepLivenessCompleted extends EkycState {
  final String ktpPath;
  final String croppedFacePath;
  final String nik;
  final String name;
  final String selfiePath;

  const EkycStepLivenessCompleted({
    required this.ktpPath,
    required this.croppedFacePath,
    required this.nik,
    required this.name,
    required this.selfiePath,
  });

  @override
  List<Object?> get props => [ktpPath, croppedFacePath, nik, name, selfiePath];
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
