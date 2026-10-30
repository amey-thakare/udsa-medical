import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/document.dart';

class ParameterCache {
  static const _storage = FlutterSecureStorage();

  static Future<void> save(String documentId, List<HealthMeasurementRef> measurements) async {
    try {
      final list = measurements.map((m) => {
        'id': m.id,
        'value': m.value,
        'unit': m.unit,
        'originalText': m.originalText,
        'confidence': m.confidence,
        'measuredAt': m.measuredAt,
        'parameterId': m.parameterId,
        'isManualEntry': m.isManualEntry,
        'parameter': m.parameter != null ? {'displayName': m.parameter!.displayName} : null,
      }).toList();
      await _storage.write(key: 'cached_measurements_$documentId', value: jsonEncode(list));
    } catch (_) {}
  }

  static Future<List<HealthMeasurementRef>> load(String documentId) async {
    try {
      final raw = await _storage.read(key: 'cached_measurements_$documentId');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded
            .map((item) => HealthMeasurementRef.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
