import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/document.dart';
import '../models/category.dart';

class MedicalHistoryCache {
  static const _storage = FlutterSecureStorage();

  // 1. Save document transcription & metadata
  static Future<void> saveDocumentState({
    required String documentId,
    String? documentName,
    required String text,
    required double confidence,
    required String summary,
    required String categoryName,
    required List<String> tags,
    required List<HealthMeasurementRef> measurements,
  }) async {
    try {
      final data = {
        'documentId': documentId,
        'documentName': documentName ?? 'Medical Report',
        'text': text,
        'confidence': confidence,
        'summary': summary,
        'categoryName': categoryName,
        'tags': tags,
        'measurements': measurements.map((m) => {
          'id': m.id,
          'value': m.value,
          'unit': m.unit,
          'originalText': m.originalText,
          'confidence': m.confidence,
          'measuredAt': m.measuredAt,
          'parameterId': m.parameterId,
          'isManualEntry': m.isManualEntry,
          'parameter': m.parameter != null ? {'displayName': m.parameter!.displayName} : null,
        }).toList(),
        'savedAt': DateTime.now().toIso8601String(),
      };
      await _storage.write(key: 'doc_state_$documentId', value: jsonEncode(data));

      // Maintain set of processed document IDs
      final processed = await getProcessedDocIds();
      processed.add(documentId);
      await _storage.write(
        key: 'processed_doc_ids',
        value: jsonEncode(processed.toList()),
      );

      // Also record all measurements into global user health history
      await recordMeasurements(documentId, documentName ?? 'Medical Report', measurements);
    } catch (_) {}
  }

  // 2. Load document transcription state
  static Future<Map<String, dynamic>?> loadDocumentState(String documentId) async {
    try {
      final raw = await _storage.read(key: 'doc_state_$documentId');
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // 3. Delete document state
  static Future<void> deleteDocumentState(String documentId) async {
    try {
      await _storage.delete(key: 'doc_state_$documentId');
      final processed = await getProcessedDocIds();
      if (processed.remove(documentId)) {
        await _storage.write(
          key: 'processed_doc_ids',
          value: jsonEncode(processed.toList()),
        );
      }
    } catch (_) {}
  }

  // 4. Retrieve all processed document IDs
  static Future<Set<String>> getProcessedDocIds() async {
    try {
      final raw = await _storage.read(key: 'processed_doc_ids');
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        final set = list.map((e) => e.toString()).toSet();
        if (set.isNotEmpty) return set;
      }

      // Fallback: discover from all keys starting with doc_state_
      final all = await _storage.readAll();
      final set = <String>{};
      for (final key in all.keys) {
        if (key.startsWith('doc_state_')) {
          set.add(key.substring('doc_state_'.length));
        }
      }
      if (set.isNotEmpty) {
        await _storage.write(
          key: 'processed_doc_ids',
          value: jsonEncode(set.toList()),
        );
      }
      return set;
    } catch (_) {}
    return {};
  }

  // 5. Total processed document count
  static Future<int> getProcessedDocumentCount() async {
    final ids = await getProcessedDocIds();
    return ids.length;
  }

  // 6. Centralized document hydration - ensures identical status and data across all screens
  static Future<MedicalDocument> hydrateDocument(MedicalDocument d) async {
    try {
      final cached = await loadDocumentState(d.id);
      if (cached != null) {
        final catName = cached['categoryName']?.toString();
        final category = catName != null
            ? MedicalCategory(
                id: catName,
                name: catName,
                icon: getCategoryIcon(catName),
              )
            : d.category;

        final measurements = (cached['measurements'] as List<dynamic>?)
                ?.map((m) =>
                    HealthMeasurementRef.fromJson(m as Map<String, dynamic>))
                .toList() ??
            d.healthMeasurements;

        final text = cached['text']?.toString();
        final extractedText = (text != null && text.isNotEmpty)
            ? ExtractedText(
                id: d.id,
                text: text,
                confidence: (cached['confidence'] as num?)?.toDouble() ?? 0.95,
                snippet: cached['summary']?.toString(),
              )
            : d.extractedText;

        final tags = (cached['tags'] as List<dynamic>?)
                ?.map((t) => DocumentTag(id: t.toString(), tag: t.toString()))
                .toList() ??
            d.tags;

        return d.copyWith(
          processingStatus: 'COMPLETED',
          category: category,
          healthMeasurements: measurements,
          extractedText: extractedText,
          tags: tags,
        );
      }
    } catch (_) {}
    return d;
  }

  // 7. Icon helper for categories
  static String getCategoryIcon(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('blood')) return '🩸';
    if (lower.contains('prescription')) return '💊';
    if (lower.contains('scan')) return '📷';
    if (lower.contains('discharge')) return '🏥';
    if (lower.contains('bill')) return '💰';
    if (lower.contains('lab')) return '🔬';
    if (lower.contains('general')) return '📋';
    return '📁';
  }

  // 8. Record health measurements directly into global user health history
  static Future<void> recordMeasurements(
    String documentId,
    String documentName,
    List<HealthMeasurementRef> measurements,
  ) async {
    try {
      final existing = await getHealthHistory();
      final newEntries = measurements.map((m) => {
        'id': m.id,
        'parameterName': canonicalize(m.parameterId ?? m.parameter?.displayName ?? 'param'),
        'displayName': m.parameter?.displayName ?? m.parameterId ?? 'Health Parameter',
        'value': m.value,
        'unit': m.unit,
        'measuredAt': m.measuredAt ?? DateTime.now().toIso8601String(),
        'confidence': m.confidence ?? 0.95,
        'originalText': m.originalText,
        'documentId': documentId,
        'documentName': documentName,
      }).toList();

      final existingIds = existing.map((e) => e['id']?.toString()).toSet();
      for (final item in newEntries) {
        if (!existingIds.contains(item['id'])) {
          existing.add(item);
        }
      }

      await _storage.write(key: 'user_health_history', value: jsonEncode(existing));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getHealthHistory() async {
    try {
      final raw = await _storage.read(key: 'user_health_history');
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, List<Map<String, dynamic>>>> getHistoryGroupedByParameter() async {
    final history = await getHealthHistory();
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in history) {
      final name = canonicalize(item['parameterName']?.toString() ?? 'other');
      grouped.putIfAbsent(name, () => []).add(item);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => (a['measuredAt']?.toString() ?? '').compareTo(b['measuredAt']?.toString() ?? ''));
    }
    return grouped;
  }

  static String canonicalize(String raw) {
    final lower = raw.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    if (lower.contains('glucose') || lower.contains('sugar') || lower.contains('fbs')) return 'glucose';
    if (lower.contains('hemo') || lower.contains('hb') || lower.contains('hgb')) return 'hemoglobin';
    if (lower.contains('systolic')) return 'systolic_bp';
    if (lower.contains('diastolic')) return 'diastolic_bp';
    if (lower.contains('cholesterol') || lower.contains('lipid')) return 'cholesterol';
    if (lower.contains('heart') || lower.contains('pulse') || lower.contains('bpm')) return 'heart_rate';
    if (lower.contains('hba1c')) return 'hba1c';
    if (lower.contains('creatinine')) return 'creatinine';
    if (lower.contains('wbc') || lower.contains('leucocyte')) return 'wbc';
    if (lower.contains('platelet')) return 'platelets';
    return lower;
  }
}
