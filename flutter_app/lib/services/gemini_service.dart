import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class GeminiOCRResult {
  final String text;
  final double confidence;
  final String qualityStatus;
  final String detectedCategory;
  final List<String> tags;
  final String summary;
  final List<Map<String, dynamic>> parameters;
  final String model;

  GeminiOCRResult({
    required this.text,
    required this.confidence,
    required this.qualityStatus,
    required this.detectedCategory,
    required this.tags,
    this.summary = '',
    this.parameters = const [],
    required this.model,
  });
}

class GeminiService {
  static const String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const List<String> candidateModels = [
    'gemini-3.1-flash-lite',
    'gemini-3-flash-preview',
    'gemini-3.5-flash',
    'gemini-flash-latest',
    'gemini-3.6-flash',
  ];

  static const String medicalAnalysisPrompt = '''
You are an expert AI clinical medical assistant and OCR document parser.
Inspect the provided medical document image carefully and perform comprehensive analysis.

Respond with ONLY a valid, raw JSON object matching this schema:
{
  "category": "Blood Test | Prescription | Lab Report | Scan Report | Discharge Summary | Medical Bill | General | Other",
  "tags": ["Tag1", "Tag2", "Tag3"],
  "summary": "Clear, informative 2-3 sentence clinical summary of findings and doctor recommendations in patient-friendly language.",
  "parameters": [
    {
      "name": "glucose | hemoglobin | systolic_bp | diastolic_bp | cholesterol | heart_rate | hba1c | creatinine | wbc | platelets | <param_key>",
      "displayName": "Readable Name (e.g. Fasting Blood Glucose, Hemoglobin, Total Cholesterol)",
      "value": 123.4,
      "unit": "mg/dL | g/dL | mmHg | bpm | % | cells/mcL | etc",
      "status": "NORMAL | HIGH | LOW",
      "originalText": "Exact text line or measurement from document"
    }
  ],
  "transcription": "Faithful Markdown OCR transcription of all visible text, doctor notes, dates, and tables using Markdown table syntax."
}

Rules:
1. Extract ALL clinical parameters and biomarkers present in the document.
2. For "category", select strictly one of: "Blood Test", "Prescription", "Lab Report", "Scan Report", "Discharge Summary", "Medical Bill", "General", "Other".
3. For "transcription", transcribe all text faithfully, formatting tables cleanly in Markdown.
4. Output ONLY the JSON object, without introductory or markdown codeblock wrappers.
''';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 45),
    receiveTimeout: const Duration(seconds: 60),
  ));

  Future<GeminiOCRResult> transcribeBytes(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final base64Image = base64Encode(bytes);

    for (final model in candidateModels) {
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          final url =
              'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

          final payload = {
            'contents': [
              {
                'parts': [
                  {'text': medicalAnalysisPrompt},
                  {
                    'inline_data': {
                      'mime_type': mimeType,
                      'data': base64Image,
                    }
                  }
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.1,
              'response_mime_type': 'application/json',
            }
          };

          final response = await _dio.post(
            url,
            data: payload,
            options: Options(headers: {'Content-Type': 'application/json'}),
          );

          if (response.statusCode == 200) {
            final data = response.data as Map<String, dynamic>;
            final candidates = data['candidates'] as List<dynamic>?;
            final rawText = candidates?[0]?['content']?['parts']?[0]?['text']
                    as String? ??
                '';
            final trimmed = rawText.trim();

            if (trimmed.isNotEmpty) {
              return _parseGeminiResponse(trimmed, model);
            }
          }
        } catch (e) {
          if (attempt < 2) {
            await Future.delayed(
                Duration(milliseconds: 1000 * (attempt + 1)));
            continue;
          }
          break;
        }
      }
    }

    throw Exception(
        'AI Vision analysis failed. Please check your internet connection.');
  }

  GeminiOCRResult _parseGeminiResponse(String rawResponse, String model) {
    String cleaned = rawResponse;
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    try {
      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      final category = (json['category'] as String?)?.trim() ?? 'General';
      final summary = (json['summary'] as String?)?.trim() ?? '';
      final transcription = (json['transcription'] as String?)?.trim() ?? cleaned;

      final rawTags = json['tags'] as List<dynamic>?;
      final tags = rawTags?.map((t) => t.toString()).toList() ?? <String>[];

      final rawParams = json['parameters'] as List<dynamic>?;
      final parameters = <Map<String, dynamic>>[];

      if (rawParams != null) {
        for (final item in rawParams) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final val = map['value'];
            double? parsedVal;
            if (val is num) {
              parsedVal = val.toDouble();
            } else if (val is String) {
              parsedVal = double.tryParse(val.replaceAll(',', ''));
            }

            if (parsedVal != null) {
              parameters.add({
                'name': map['name']?.toString() ?? 'param',
                'displayName': map['displayName']?.toString() ?? map['name']?.toString() ?? 'Parameter',
                'value': parsedVal,
                'unit': map['unit']?.toString() ?? '',
                'status': map['status']?.toString() ?? 'NORMAL',
                'originalText': map['originalText']?.toString() ?? '',
              });
            }
          }
        }
      }

      final unclearCount = RegExp(r'\[unclear\]', caseSensitive: false)
          .allMatches(transcription)
          .length;
      double conf = 0.95 - (unclearCount * 0.08);
      if (transcription.length < 30) conf = conf.clamp(0.20, 0.60);
      conf = conf.clamp(0.20, 0.99);

      String quality = 'HIGH';
      if (conf < 0.65) {
        quality = 'LOW_REVIEW_NEEDED';
      } else if (conf < 0.85) {
        quality = 'MEDIUM';
      }

      return GeminiOCRResult(
        text: transcription,
        confidence: conf,
        qualityStatus: quality,
        detectedCategory: _normalizeCategory(category),
        tags: tags,
        summary: summary,
        parameters: parameters,
        model: model,
      );
    } catch (_) {
      // Heuristic fallback if json decoding failed
      final detected = _detectCategoryFallback(cleaned);
      return GeminiOCRResult(
        text: cleaned,
        confidence: 0.85,
        qualityStatus: 'HIGH',
        detectedCategory: detected.category,
        tags: detected.tags,
        summary: '',
        parameters: const [],
        model: model,
      );
    }
  }

  String _normalizeCategory(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('blood')) return 'Blood Test';
    if (lower.contains('prescription') || lower.contains('rx')) return 'Prescription';
    if (lower.contains('scan') || lower.contains('x-ray') || lower.contains('mri') || lower.contains('ct')) return 'Scan Report';
    if (lower.contains('discharge')) return 'Discharge Summary';
    if (lower.contains('bill') || lower.contains('invoice')) return 'Medical Bill';
    if (lower.contains('lab')) return 'Lab Report';
    if (lower.contains('other')) return 'Other';
    return 'General';
  }

  ({String category, List<String> tags}) _detectCategoryFallback(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('hemoglobin') || lower.contains('glucose') || lower.contains('blood test')) {
      return (category: 'Blood Test', tags: ['Blood Test']);
    }
    if (lower.contains('prescription') || lower.contains('dosage') || lower.contains('tab.')) {
      return (category: 'Prescription', tags: ['Prescription']);
    }
    if (lower.contains('lab') || lower.contains('pathology')) {
      return (category: 'Lab Report', tags: ['Lab Report']);
    }
    return (category: 'General', tags: []);
  }
}
