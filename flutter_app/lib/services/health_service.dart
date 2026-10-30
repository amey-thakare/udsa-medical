import 'package:dio/dio.dart';
import 'api_client.dart';
import 'medical_history_cache.dart';
import '../models/health_parameter.dart';

class HealthService {
  final Dio _dio = ApiClient().dio;

  Future<List<HealthParameter>> getParameters() async {
    List<HealthParameter> remoteParams = [];
    try {
      final response = await _dio.get('/health-parameters');
      if (response.data != null && response.data['parameters'] != null) {
        final list = response.data['parameters'] as List<dynamic>;
        remoteParams = list
            .map((p) => HealthParameter.fromJson(p as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // Fallback default parameters if remote is offline
    if (remoteParams.isEmpty) {
      remoteParams = [
        HealthParameter(id: 'glucose', name: 'glucose', displayName: 'Blood Glucose', defaultUnit: 'mg/dL', normalMin: 70, normalMax: 100),
        HealthParameter(id: 'hemoglobin', name: 'hemoglobin', displayName: 'Hemoglobin', defaultUnit: 'g/dL', normalMin: 12, normalMax: 17.5),
        HealthParameter(id: 'systolic_bp', name: 'systolic_bp', displayName: 'Systolic Blood Pressure', defaultUnit: 'mmHg', normalMin: 90, normalMax: 120),
        HealthParameter(id: 'diastolic_bp', name: 'diastolic_bp', displayName: 'Diastolic Blood Pressure', defaultUnit: 'mmHg', normalMin: 60, normalMax: 80),
        HealthParameter(id: 'cholesterol', name: 'cholesterol', displayName: 'Total Cholesterol', defaultUnit: 'mg/dL', normalMin: 0, normalMax: 200),
        HealthParameter(id: 'heart_rate', name: 'heart_rate', displayName: 'Heart Rate', defaultUnit: 'bpm', normalMin: 60, normalMax: 100),
        HealthParameter(id: 'hba1c', name: 'hba1c', displayName: 'HbA1c', defaultUnit: '%', normalMin: 4, normalMax: 5.6),
        HealthParameter(id: 'creatinine', name: 'creatinine', displayName: 'Creatinine', defaultUnit: 'mg/dL', normalMin: 0.7, normalMax: 1.3),
        HealthParameter(id: 'wbc', name: 'wbc', displayName: 'White Blood Cells', defaultUnit: 'cells/mcL', normalMin: 4500, normalMax: 11000),
        HealthParameter(id: 'platelets', name: 'platelets', displayName: 'Platelets', defaultUnit: 'cells/mcL', normalMin: 150000, normalMax: 400000),
      ];
    }

    // Merge with persistent local measurement history
    final history = await MedicalHistoryCache.getHealthHistory();
    if (history.isEmpty) return remoteParams;

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in history) {
      final name = MedicalHistoryCache.canonicalize(item['parameterName']?.toString() ?? 'other');
      grouped.putIfAbsent(name, () => []).add(item);
    }

    final merged = <HealthParameter>[];
    final processedNames = <String>{};

    for (final p in remoteParams) {
      processedNames.add(p.name);
      final localItems = grouped[p.name] ?? [];
      if (localItems.isNotEmpty) {
        localItems.sort((a, b) => (b['measuredAt']?.toString() ?? '').compareTo(a['measuredAt']?.toString() ?? ''));
        final latest = localItems.first;
        final totalCount = p.measurementCount + localItems.length;

        merged.add(HealthParameter(
          id: p.id,
          name: p.name,
          displayName: p.displayName,
          defaultUnit: p.defaultUnit.isNotEmpty ? p.defaultUnit : (latest['unit']?.toString() ?? ''),
          normalMin: p.normalMin,
          normalMax: p.normalMax,
          measurementCount: totalCount,
          latestMeasurement: LatestMeasurement(
            value: (latest['value'] as num).toDouble(),
            unit: latest['unit']?.toString() ?? p.defaultUnit,
          ),
        ));
      } else {
        merged.add(p);
      }
    }

    // Add any parameters tracked in history that weren't in default list
    for (final entry in grouped.entries) {
      if (!processedNames.contains(entry.key)) {
        final items = entry.value;
        items.sort((a, b) => (b['measuredAt']?.toString() ?? '').compareTo(a['measuredAt']?.toString() ?? ''));
        final latest = items.first;
        merged.add(HealthParameter(
          id: entry.key,
          name: entry.key,
          displayName: latest['displayName']?.toString() ?? entry.key,
          defaultUnit: latest['unit']?.toString() ?? '',
          measurementCount: items.length,
          latestMeasurement: LatestMeasurement(
            value: (latest['value'] as num).toDouble(),
            unit: latest['unit']?.toString() ?? '',
          ),
        ));
      }
    }

    return merged;
  }

  Future<void> correctMeasurement(
    String measurementId, {
    required double value,
    String? measuredAt,
  }) async {
    final data = <String, dynamic>{'value': value};
    if (measuredAt != null) data['measuredAt'] = measuredAt;
    try {
      await _dio.post('/health-parameters/$measurementId/correct', data: data);
    } catch (_) {}
  }

  Future<HealthTrendData> getTrends(String parameter) async {
    HealthTrendData? remoteTrend;
    try {
      final response = await _dio.get('/health-trends/$parameter');
      if (response.data != null) {
        remoteTrend = HealthTrendData.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}

    // Fetch local measurements for this parameter
    final history = await MedicalHistoryCache.getHealthHistory();
    final canonicalTarget = MedicalHistoryCache.canonicalize(parameter);
    final localMeasurements = history
        .where((item) =>
            MedicalHistoryCache.canonicalize(item['parameterName']?.toString() ?? '') ==
            canonicalTarget)
        .map((item) => HealthMeasurement(
              id: item['id']?.toString() ??
                  'local_${DateTime.now().millisecondsSinceEpoch}',
              value: (item['value'] as num).toDouble(),
              unit: item['unit']?.toString() ?? '',
              measuredAt: item['measuredAt']?.toString(),
              confidence: (item['confidence'] as num?)?.toDouble() ?? 0.95,
              originalText: item['originalText']?.toString(),
            ))
        .toList();

    if (remoteTrend != null && remoteTrend.measurements.isNotEmpty) {
      final allMeasurements = [...remoteTrend.measurements];
      final existingIds = allMeasurements.map((m) => m.id).toSet();
      for (final lm in localMeasurements) {
        if (!existingIds.contains(lm.id)) {
          allMeasurements.add(lm);
        }
      }
      allMeasurements.sort((a, b) => (a.measuredAt ?? '').compareTo(b.measuredAt ?? ''));

      return HealthTrendData(
        parameter: remoteTrend.parameter,
        dataPoints: allMeasurements.length,
        measurements: allMeasurements,
      );
    }

    // Direct local trend data if remote returned no points
    final defaultUnit = localMeasurements.isNotEmpty ? localMeasurements.first.unit : '';
    localMeasurements.sort((a, b) => (a.measuredAt ?? '').compareTo(b.measuredAt ?? ''));

    final paramDefs = {
      'glucose': ('Blood Glucose', 70.0, 100.0),
      'hemoglobin': ('Hemoglobin', 12.0, 17.5),
      'systolic_bp': ('Systolic Blood Pressure', 90.0, 120.0),
      'diastolic_bp': ('Diastolic Blood Pressure', 60.0, 80.0),
      'cholesterol': ('Total Cholesterol', 0.0, 200.0),
      'heart_rate': ('Heart Rate', 60.0, 100.0),
      'hba1c': ('HbA1c', 4.0, 5.6),
      'creatinine': ('Creatinine', 0.7, 1.3),
      'wbc': ('White Blood Cells', 4500.0, 11000.0),
      'platelets': ('Platelets', 150000.0, 400000.0),
    };

    final def = paramDefs[canonicalTarget];

    return HealthTrendData(
      parameter: HealthParameter(
        id: parameter,
        name: parameter,
        displayName: def?.$1 ?? parameter.toUpperCase(),
        defaultUnit: defaultUnit,
        normalMin: def?.$2,
        normalMax: def?.$3,
        measurementCount: localMeasurements.length,
      ),
      dataPoints: localMeasurements.length,
      measurements: localMeasurements,
    );
  }
}
