import '../models/document.dart';
import 'dart:io';
import '../services/gemini_service.dart';
import '../services/medical_history_cache.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/document_service.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_indicator.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _docService = DocumentService();
  File? _file;
  String? _fileName;
  bool _uploading = false;
  double _progress = 0;
  String? _error;
  Map<String, dynamic>? _success;

  final _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];
  final int _maxSize = 10 * 1024 * 1024;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      _validateAndSetFile(file, result.files.single.name);
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
    );

    if (photo != null) {
      _validateAndSetFile(File(photo.path), photo.name);
    }
  }

  void _validateAndSetFile(File file, String name) {
    setState(() => _error = null);

    if (file.lengthSync() > _maxSize) {
      setState(() => _error = 'File too large. Maximum: 10MB');
      return;
    }

    setState(() {
      _file = file;
      _fileName = name;
    });
  }

  Future<void> _handleUpload() async {
    if (_file == null) return;
    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });

    try {
      final res = await _docService.upload(
        _file!.path,
        _fileName ?? 'document',
        onProgress: (sent, total) {
          if (total > 0) {
            setState(() => _progress = sent / total);
          }
        },
      );

      final doc = res['document'] as Map<String, dynamic>;
      setState(() => _success = doc);

      // Auto-trigger direct AI analysis & parameter extraction
      final docId = doc['id'] as String;
      try {
        if (_file != null) {
          final bytes = await File(_file!.path).readAsBytes();
          final geminiService = GeminiService();
          final result = await geminiService.transcribeBytes(bytes);
          final convertedMeasurements = result.parameters.map((p) {
            final paramName = p['name']?.toString() ?? 'param';
            final displayName = p['displayName']?.toString() ?? paramName;
            final val = p['value'] is num
                ? (p['value'] as num).toDouble()
                : (double.tryParse(p['value'].toString().replaceAll(',', '')) ?? 0.0);
            final unit = p['unit']?.toString() ?? '';
            final orig = p['originalText']?.toString() ?? '$displayName: $val $unit';

            return {
              'id': 'ai_${paramName}_${DateTime.now().millisecondsSinceEpoch}',
              'value': val,
              'unit': unit,
              'originalText': orig,
              'confidence': result.confidence,
              'measuredAt': DateTime.now().toIso8601String(),
              'parameterId': paramName,
              'parameter': {'displayName': displayName},
            };
          }).toList();

          final measurementsList = convertedMeasurements.map((m) => HealthMeasurementRef.fromJson(m)).toList();
          await MedicalHistoryCache.saveDocumentState(
            documentId: docId,
            text: result.text,
            confidence: result.confidence,
            summary: result.summary,
            categoryName: result.detectedCategory,
            tags: result.tags,
            measurements: measurementsList,
          );

          final updatedRes = await _docService.updateText(
            docId,
            text: result.text,
            confidence: result.confidence,
            categoryName: result.detectedCategory,
            tags: result.tags,
            parameters: result.parameters,
            summary: result.summary,
          );

          if (updatedRes['document'] != null) {
            final map = Map<String, dynamic>.from(updatedRes['document'] as Map);
            if ((map['healthMeasurements'] as List?)?.isEmpty ?? true) {
              map['healthMeasurements'] = convertedMeasurements;
            }
            setState(() => _success = map);
          } else {
            final map = Map<String, dynamic>.from(doc);
            map['healthMeasurements'] = convertedMeasurements;
            map['category'] = {'name': result.detectedCategory};
            map['extractedText'] = {'text': result.text, 'confidence': result.confidence};
            setState(() => _success = map);
          }
        }
      } catch (aiError) {
        debugPrint('AI analysis note: $aiError');
      }
    } catch (e) {
      setState(() => _error = 'Upload failed. Please try again.');
    } finally {
      setState(() => _uploading = false);
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _reset() {
    setState(() {
      _file = null;
      _fileName = null;
      _success = null;
      _progress = 0;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_success != null) {
      return PopScope(
        canPop: context.canPop(),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) context.go('/home');
        },
        child: _buildSuccessView(),
      );
    }

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _handleBack,
                    color: AppTheme.textSecondary,
                  ),
                  const Text(
                    'Upload Document',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const AlertBanner(
                message:
                    '📋 Upload medical reports (PDF, JPG, PNG). OCR processing will extract text and health parameters automatically.',
                type: AlertType.info,
              ),

              if (_error != null)
                AlertBanner(message: _error!, type: AlertType.error),

              if (_file == null) ...[
                // Drop zone
                GestureDetector(
                  onTap: _pickFile,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppTheme.border,
                          width: 2,
                          strokeAlign: BorderSide.strokeAlignInside),
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      color: AppTheme.bgCard,
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.upload_file,
                            size: 40, color: AppTheme.primary),
                        SizedBox(height: 12),
                        Text(
                          'Tap to select a file',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'PDF, JPG, PNG • Max 10MB',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('Take Photo'),
                  ),
                ),
              ] else ...[
                // File preview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm - 1),
                              child: _fileName?.endsWith('.pdf') == true
                                  ? Image.asset('assets/images/report_icon.png', fit: BoxFit.cover)
                                  : Image.file(_file!, fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _fileName ?? 'Document',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${(_file!.lengthSync() / 1024).toStringAsFixed(0)} KB',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: _reset,
                            color: AppTheme.textMuted,
                          ),
                        ],
                      ),

                      if (_uploading) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Uploading...',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textMuted)),
                            Text('${(_progress * 100).toInt()}%',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: _progress,
                            minHeight: 6,
                            backgroundColor: AppTheme.bgInput,
                            valueColor: const AlwaysStoppedAnimation(
                                AppTheme.primary),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _uploading ? null : _handleUpload,
                          icon: const Icon(Icons.upload, size: 16),
                          label: Text(_uploading
                              ? 'Uploading... ${(_progress * 100).toInt()}%'
                              : 'Upload Document'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildSuccessView() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _handleBack,
                    color: AppTheme.textSecondary,
                  ),
                  const Text('Upload Document',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                ],
              ),
              const Spacer(),
              const Text('✅', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('Upload Successful!',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                _success?['originalName'] ?? '',
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              const Text(
                'OCR processing has been started automatically. You can check the results in the document details.',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final docMap = _success;
                    MedicalDocument? medDoc;
                    if (docMap != null) {
                      try {
                        medDoc = MedicalDocument.fromJson(docMap);
                      } catch (_) {}
                    }
                    context.go(
                      "/documents/${_success?['id']}",
                      extra: medDoc,
                    );
                  },
                  child: const Text('View Document'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _reset,
                  child: const Text('Upload Another'),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}