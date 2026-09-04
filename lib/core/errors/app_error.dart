import 'package:equatable/equatable.dart';

sealed class AppError extends Equatable implements Exception {
  const AppError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class UnexpectedAppError extends AppError {
  const UnexpectedAppError([
    super.message = 'Something went wrong. Please try again.',
  ]);
}

final class ValidationAppError extends AppError {
  const ValidationAppError(super.message);
}

enum AuthenticationFailureType {
  invalidEmail,
  weakPassword,
  emailAlreadyInUse,
  invalidCredentials,
  userDisabled,
  tooManyRequests,
  network,
  unknown,
}

final class AuthenticationFailure extends AppError {
  const AuthenticationFailure(this.type, super.message);

  final AuthenticationFailureType type;

  @override
  List<Object?> get props => [type, message];
}

enum PlantFailureType {
  unauthenticated,
  notFound,
  permissionDenied,
  network,
  unknown,
}

final class PlantFailure extends AppError {
  const PlantFailure(this.type, super.message);

  final PlantFailureType type;

  @override
  List<Object?> get props => [type, message];
}

enum PlantObservationFailureType {
  noImage,
  unsupportedFormat,
  imageTooLarge,
  imageProcessing,
  aiUnavailable,
  appCheckRejected,
  permissionDenied,
  modelUnavailable,
  retiredModel,
  quotaExceeded,
  safetyRejected,
  network,
  malformedResponse,
  unauthenticated,
  plantNotFound,
  saveFailed,
  unknown,
}

final class PlantObservationFailure extends AppError {
  const PlantObservationFailure(this.type, super.message);

  final PlantObservationFailureType type;

  @override
  List<Object?> get props => [type, message];
}

enum KnowledgeRetrievalFailureType {
  unauthenticated,
  permissionDenied,
  network,
  unknown,
}

final class KnowledgeRetrievalFailure extends AppError {
  const KnowledgeRetrievalFailure(this.type, super.message);

  final KnowledgeRetrievalFailureType type;

  @override
  List<Object?> get props => [type, message];
}

enum PlantDiagnosisFailureType {
  unauthenticated,
  appCheckRejected,
  permissionDenied,
  unsupportedPlant,
  plantConflict,
  insufficientEvidence,
  malformedSources,
  modelUnavailable,
  retiredModel,
  quotaExceeded,
  safetyRejected,
  network,
  malformedResponse,
  unknownEvidenceReference,
  saveFailed,
  notFound,
  unknown,
}

final class PlantDiagnosisFailure extends AppError {
  const PlantDiagnosisFailure(this.type, super.message);

  final PlantDiagnosisFailureType type;

  @override
  List<Object?> get props => [type, message];
}

enum SoilCheckFailureType {
  unauthenticated,
  plantNotFound,
  insufficientEvidence,
  malformedEvidence,
  saveFailed,
  notFound,
  network,
  unknown,
}

final class SoilCheckFailure extends AppError {
  const SoilCheckFailure(this.type, super.message);

  final SoilCheckFailureType type;

  @override
  List<Object?> get props => [type, message];
}

enum CareLogFailureType {
  unauthenticated,
  permissionDenied,
  network,
  malformedData,
  missingParent,
  notFound,
  unknown,
}

final class CareLogFailure extends AppError {
  const CareLogFailure(this.type, super.message);

  final CareLogFailureType type;

  @override
  List<Object?> get props => [type, message];
}

enum FertilizerAssessmentFailureType {
  unauthenticated,
  plantNotFound,
  insufficientEvidence,
  malformedEvidence,
  saveFailed,
  notFound,
  network,
  unknown,
}

final class FertilizerAssessmentFailure extends AppError {
  const FertilizerAssessmentFailure(this.type, super.message);

  final FertilizerAssessmentFailureType type;

  @override
  List<Object?> get props => [type, message];
}
