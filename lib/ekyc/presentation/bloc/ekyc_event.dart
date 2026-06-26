import 'package:equatable/equatable.dart';
import 'ekyc_state.dart';

abstract class EkycEvent extends Equatable {
  const EkycEvent();

  @override
  List<Object?> get props => [];
}

class ResetEkyc extends EkycEvent {}

class KtpCaptured extends EkycEvent {
  final String ktpPath;
  final String croppedFacePath;
  final String nik;
  final String name;

  const KtpCaptured({
    required this.ktpPath,
    required this.croppedFacePath,
    required this.nik,
    required this.name,
  });

  @override
  List<Object?> get props => [ktpPath, croppedFacePath, nik, name];
}

class StartLivenessScan extends EkycEvent {
  final String ktpPath;
  final String croppedFacePath;
  final String nik;
  final String name;

  const StartLivenessScan({
    required this.ktpPath,
    required this.croppedFacePath,
    required this.nik,
    required this.name,
  });

  @override
  List<Object?> get props => [ktpPath, croppedFacePath, nik, name];
}

class LivenessCaptured extends EkycEvent {
  final String selfiePath;

  const LivenessCaptured({required this.selfiePath});

  @override
  List<Object?> get props => [selfiePath];
}

class RestoreState extends EkycEvent {
  final EkycState state;

  const RestoreState(this.state);

  @override
  List<Object?> get props => [state];
}

class SubmitVerification extends EkycEvent {}

class SetFailure extends EkycEvent {
  final String errorMessage;

  const SetFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
