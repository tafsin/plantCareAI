import 'package:plantcare_ai/features/soil_check/domain/entities/soil_check.dart';

abstract interface class SoilCheckRepository {
  Future<String> save(String plantId, SoilCheckRecord record);
  Stream<List<SoilCheckRecord>> watchHistory(String plantId);
  Stream<SoilCheckRecord?> watchDetails(String plantId, String soilCheckId);
  Future<void> delete(String plantId, String soilCheckId);
}
