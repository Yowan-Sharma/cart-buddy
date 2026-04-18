import 'package:dio/dio.dart';
import '../models/organisation_model.dart';

class OrganisationService {
  final Dio _dio;

  OrganisationService(this._dio);

  Future<List<Organisation>> getOrganisations() async {
    try {
      final response = await _dio.get('organisations/');
      return (response.data as List)
          .map((e) => Organisation.fromJson(e))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Campus>> getCampuses() async {
    try {
      final response = await _dio.get('organisations/campuses/');
      return (response.data as List)
          .map((e) => Campus.fromJson(e))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> joinOrganisation(int organisationId) async {
    try {
      await _dio.patch('users/me/', data: {
        'organisation': organisationId,
      });
    } catch (e) {
      rethrow;
    }
  }
}
