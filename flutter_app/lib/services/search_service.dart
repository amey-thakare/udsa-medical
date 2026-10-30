import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/document.dart';
import 'medical_history_cache.dart';

class SearchService {
  final Dio _dio = ApiClient().dio;

  Future<Map<String, dynamic>> search(String query,
      {int page = 1, int limit = 20}) async {
    final response = await _dio.get('/search', queryParameters: {
      'q': query,
      'page': page,
      'limit': limit,
    });
    final data = response.data as Map<String, dynamic>;
    if (data['results'] is List) {
      final rawDocs = (data['results'] as List)
          .map((d) => d is MedicalDocument
              ? d
              : MedicalDocument.fromJson(d as Map<String, dynamic>))
          .toList();
      final hydrated =
          await Future.wait(rawDocs.map(MedicalHistoryCache.hydrateDocument));
      data['results'] = hydrated.map((d) => d.toJson()).toList();
    }
    return data;
  }
}
