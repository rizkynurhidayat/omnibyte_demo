import 'package:equatable/equatable.dart';
import '../../domain/entities/verification_entity.dart';

abstract class ScannerState extends Equatable {
  const ScannerState();

  @override
  List<Object?> get props => [];
}

class ScannerInitial extends ScannerState {}

class ScannerLoading extends ScannerState {}

class ScannerSuccess extends ScannerState {
  final VerificationEntity verificationResult;

  const ScannerSuccess(this.verificationResult);

  @override
  List<Object?> get props => [verificationResult];
}

class ScannerFailure extends ScannerState {
  final String errorMessage;

  const ScannerFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
