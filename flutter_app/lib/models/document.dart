import 'category.dart';

class DocumentTag {
  final String id;
  final String tag;

  DocumentTag({required this.id, required this.tag});

  factory DocumentTag.fromJson(Map<String, dynamic> json) {
    return DocumentTag(
      id: json['id']?.toString() ?? '',
      tag: json['tag']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tag': tag,
  };
}

class ExtractedText {
  final String id;
  final String? text;
  final double? confidence;
  final String? snippet;

  ExtractedText({required this.id, this.text, this.confidence, this.snippet});

  factory ExtractedText.fromJson(Map<String, dynamic> json) {
    return ExtractedText(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      snippet: json['snippet']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'confidence': confidence,
    'snippet': snippet,
  };
}

class MedicalDocument {
  final String id;
  final String? fileName;
  final String? storagePath;
  final String originalName;
  final String fileType;
  final int fileSize;
  final String processingStatus;
  final String? processingError;
  final String uploadedAt;
  final MedicalCategory? category;
  final List<DocumentTag> tags;
  final ExtractedText? extractedText;
  final List<HealthMeasurementRef> healthMeasurements;
  final Map<String, int>? counts;

  MedicalDocument({
    required this.id,
    this.fileName,
    this.storagePath,
    required this.originalName,
    required this.fileType,
    required this.fileSize,
    required this.processingStatus,
    this.processingError,
    required this.uploadedAt,
    this.category,
    this.tags = const [],
    this.extractedText,
    this.healthMeasurements = const [],
    this.counts,
  });

  factory MedicalDocument.fromJson(Map<String, dynamic> json) {
    return MedicalDocument(
      id: json['id']?.toString() ?? '',
      fileName: json['fileName']?.toString(),
      storagePath: json['storagePath']?.toString(),
      originalName: json['originalName']?.toString() ?? 'Document',
      fileType: json['fileType']?.toString() ?? 'image/jpeg',
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      processingStatus: json['processingStatus']?.toString() ?? 'UPLOADED',
      processingError: json['processingError']?.toString(),
      uploadedAt: json['uploadedAt']?.toString() ?? '',
      category: json['category'] != null
          ? MedicalCategory.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((t) => DocumentTag.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      extractedText: json['extractedText'] != null
          ? ExtractedText.fromJson(json['extractedText'] as Map<String, dynamic>)
          : null,
      healthMeasurements: (json['healthMeasurements'] as List<dynamic>?)
              ?.map((m) =>
                  HealthMeasurementRef.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      counts: json['_count'] != null
          ? Map<String, int>.from(
              (json['_count'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
              ),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'storagePath': storagePath,
    'originalName': originalName,
    'fileType': fileType,
    'fileSize': fileSize,
    'processingStatus': processingStatus,
    'processingError': processingError,
    'uploadedAt': uploadedAt,
    'category': category?.toJson(),
    'tags': tags.map((t) => t.toJson()).toList(),
    'extractedText': extractedText?.toJson(),
    'healthMeasurements': healthMeasurements.map((m) => m.toJson()).toList(),
    '_count': counts,
  };

  MedicalDocument copyWith({
    String? processingStatus,
    String? processingError,
    String? storagePath,
    MedicalCategory? category,
    List<DocumentTag>? tags,
    ExtractedText? extractedText,
    List<HealthMeasurementRef>? healthMeasurements,
  }) {
    return MedicalDocument(
      id: id,
      fileName: fileName,
      storagePath: storagePath ?? this.storagePath,
      originalName: originalName,
      fileType: fileType,
      fileSize: fileSize,
      processingStatus: processingStatus ?? this.processingStatus,
      processingError: processingError ?? this.processingError,
      uploadedAt: uploadedAt,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      extractedText: extractedText ?? this.extractedText,
      healthMeasurements: healthMeasurements ?? this.healthMeasurements,
      counts: counts,
    );
  }
}

class HealthMeasurementRef {
  final String id;
  final double value;
  final String unit;
  final String? originalText;
  final bool isManualEntry;
  final String? measuredAt;
  final double? confidence;
  final String? parameterId;
  final HealthParamRef? parameter;

  HealthMeasurementRef({
    required this.id,
    required this.value,
    required this.unit,
    this.originalText,
    this.isManualEntry = false,
    this.measuredAt,
    this.confidence,
    this.parameterId,
    this.parameter,
  });

  factory HealthMeasurementRef.fromJson(Map<String, dynamic> json) {
    return HealthMeasurementRef(
      id: json['id']?.toString() ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? '',
      originalText: json['originalText']?.toString(),
      isManualEntry: json['isManualEntry'] as bool? ?? false,
      measuredAt: json['measuredAt']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      parameterId: json['parameterId']?.toString(),
      parameter: json['parameter'] != null
          ? HealthParamRef.fromJson(json['parameter'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'value': value,
    'unit': unit,
    'originalText': originalText,
    'isManualEntry': isManualEntry,
    'measuredAt': measuredAt,
    'confidence': confidence,
    'parameterId': parameterId,
    'parameter': parameter?.toJson(),
  };
}

class HealthParamRef {
  final String? displayName;

  HealthParamRef({this.displayName});

  factory HealthParamRef.fromJson(Map<String, dynamic> json) {
    return HealthParamRef(
      displayName: json['displayName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
  };
}
