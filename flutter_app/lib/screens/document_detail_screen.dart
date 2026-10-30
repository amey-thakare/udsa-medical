import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../services/api_client.dart';
import '../services/gemini_service.dart';
import '../services/document_service.dart';
import '../services/health_service.dart';
import '../services/medical_history_cache.dart';
import '../models/document.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/param_card.dart';
import '../widgets/loading_indicator.dart';
import '../utils/error_handler.dart';

class DocumentDetailScreen extends StatefulWidget {
  final String documentId;
  final MedicalDocument? initialDocument;

  const DocumentDetailScreen({
    super.key,
    required this.documentId,
    this.initialDocument,
  });

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen>
    with SingleTickerProviderStateMixin {
  final _docService = DocumentService();
  final _healthService = HealthService();
  MedicalDocument? _doc;
  late bool _loading;
  String? _error;
  bool _processing = false;
  bool _deleting = false;
  List<MedicalCategory> _categories = [];
  Timer? _pollTimer;
  late TabController _tabController;
  bool _showFormatted = true;
  Uint8List? _localImageBytes;

  @override
  void initState() {
    super.initState();
    _doc = widget.initialDocument;
    _loading = widget.initialDocument == null;
    _tabController = TabController(length: 4, vsync: this);
    _loadDocument(silent: widget.initialDocument != null);
    _loadCategories();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDocument({bool silent = false}) async {
    try {
      MedicalDocument doc;
      try {
        doc = await _docService.get(widget.documentId);
      } catch (e) {
        doc = _doc ??
            MedicalDocument(
              id: widget.documentId,
              originalName: 'Document',
              fileType: 'image/jpeg',
              fileSize: 0,
              processingStatus: 'UPLOADED',
              uploadedAt: DateTime.now().toIso8601String(),
            );
      }

      // Check persistent medical history cache
      final cachedState =
          await MedicalHistoryCache.loadDocumentState(widget.documentId);
      if (cachedState != null) {
        ExtractedText? text = doc.extractedText;
        if (text == null || (text.text?.isEmpty ?? true)) {
          text = ExtractedText(
            id: widget.documentId,
            text: cachedState['text']?.toString() ?? '',
            confidence:
                (cachedState['confidence'] as num?)?.toDouble() ?? 0.95,
            snippet: cachedState['summary']?.toString(),
          );
        }

        List<HealthMeasurementRef> measurements = doc.healthMeasurements;
        if (measurements.isEmpty && cachedState['measurements'] != null) {
          final list = cachedState['measurements'] as List<dynamic>;
          measurements = list
              .map((m) =>
                  HealthMeasurementRef.fromJson(m as Map<String, dynamic>))
              .toList();
        }

        MedicalCategory? category = doc.category;
        if (category == null && cachedState['categoryName'] != null) {
          final catName = cachedState['categoryName'].toString();
          category = _categories.firstWhere(
            (c) => c.name.toLowerCase() == catName.toLowerCase(),
            orElse: () =>
                MedicalCategory(id: catName, name: catName, icon: '📋'),
          );
        }

        List<DocumentTag> tags = doc.tags;
        if (tags.isEmpty && cachedState['tags'] != null) {
          final rawTags = cachedState['tags'] as List<dynamic>;
          tags = rawTags
              .map((t) => DocumentTag(id: t.toString(), tag: t.toString()))
              .toList();
        }

        doc = doc.copyWith(
          processingStatus: 'COMPLETED',
          extractedText: text,
          healthMeasurements: measurements,
          category: category,
          tags: tags,
        );
      }

      if (mounted) {
        setState(() {
          _doc = doc;
          if (!silent) _loading = false;
        });

        // Auto-refresh when processing is active
        if (doc.processingStatus == 'PROCESSING') {
          _startPolling();
        } else {
          _pollTimer?.cancel();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!silent) {
            _error = ApiErrorHandler.extract(
              e,
              fallback: 'Failed to load document details. Please check your network connection and tap Retry.',
            );
            _loading = false;
          }
        });
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    int pollAttempts = 0;
    const maxPollAttempts = 40; // 40 * 2.5s = 100s timeout guard
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) async {
      pollAttempts++;
      if (pollAttempts > maxPollAttempts) {
        timer.cancel();
        if (mounted && _doc?.processingStatus == 'PROCESSING') {
          setState(() {
            _error = 'Processing is taking longer than expected. Tap Retry OCR if needed.';
          });
        }
        return;
      }
      try {
        final freshDoc = await _docService.get(widget.documentId);
        if (mounted) {
          setState(() {
            // Guard: Preserve extracted parameters if server returns empty list
            if (freshDoc.healthMeasurements.isEmpty &&
                _doc?.healthMeasurements.isNotEmpty == true) {
              _doc = freshDoc.copyWith(healthMeasurements: _doc!.healthMeasurements);
            } else {
              _doc = freshDoc;
            }
          });
          if (freshDoc.processingStatus != 'PROCESSING') {
            timer.cancel();
          }
        }
      } catch (_) {
        // Silently continue polling on transient network drops
      }
    });
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _docService.getCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/records');
    }
  }

  Future<void> _handleProcess() async {
    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final doc = _doc;
      Uint8List? imageBytes;

      if (doc != null) {
        try {
          String downloadUrl;
          if (doc.storagePath != null && doc.storagePath!.isNotEmpty) {
            if (doc.storagePath!.startsWith('http://') ||
                doc.storagePath!.startsWith('https://')) {
              downloadUrl = doc.storagePath!;
            } else {
              downloadUrl =
                  '${ApiConfig.baseUrl.replaceAll('/api', '')}${doc.storagePath}';
            }
          } else {
            final fileIdentifier = doc.fileName ?? doc.originalName;
            downloadUrl =
                '${ApiConfig.baseUrl.replaceAll('/api', '')}/uploads/$fileIdentifier';
          }

          final response = await ApiClient().dio.get<List<int>>(
            downloadUrl,
            options: Options(responseType: ResponseType.bytes),
          );
          if (response.data != null && response.data!.isNotEmpty) {
            imageBytes = Uint8List.fromList(response.data!);
          }
        } catch (_) {}
      }

      // If downloading from server failed, prompt user to pick photo from gallery
      if ((imageBytes == null || imageBytes.isEmpty) && mounted) {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery);
        if (picked != null) {
          imageBytes = await picked.readAsBytes();
        }
      }

      if (imageBytes != null && imageBytes.isNotEmpty) {
        setState(() => _localImageBytes = imageBytes);
        final geminiService = GeminiService();
        final result = await geminiService.transcribeBytes(imageBytes);

        // Convert AI parameters directly into HealthMeasurementRef items
        final convertedMeasurements = result.parameters.map((p) {
          final paramName = p['name']?.toString() ?? 'param';
          final displayName = p['displayName']?.toString() ?? paramName;
          final val = p['value'] is num
              ? (p['value'] as num).toDouble()
              : (double.tryParse(p['value'].toString().replaceAll(',', '')) ?? 0.0);
          final unit = p['unit']?.toString() ?? '';
          final orig = p['originalText']?.toString() ?? '$displayName: $val $unit';

          return HealthMeasurementRef(
            id: 'ai_${paramName}_${DateTime.now().millisecondsSinceEpoch}',
            value: val,
            unit: unit,
            originalText: orig,
            confidence: result.confidence,
            measuredAt: DateTime.now().toIso8601String(),
            parameterId: paramName,
            parameter: HealthParamRef(displayName: displayName),
          );
        }).toList();

        final matchedCategory = _categories.firstWhere(
          (c) => c.name.toLowerCase() == result.detectedCategory.toLowerCase(),
          orElse: () => MedicalCategory(
            id: result.detectedCategory,
            name: result.detectedCategory,
            icon: result.detectedCategory == 'Blood Test'
                ? '🩸'
                : (result.detectedCategory == 'Prescription' ? '💊' : '📁'),
          ),
        );

        // Save completely to persistent MedicalHistoryCache & user Health History
        await MedicalHistoryCache.saveDocumentState(
          documentId: widget.documentId,
          documentName: _doc?.originalName ?? 'Medical Report',
          text: result.text,
          confidence: result.confidence,
          summary: result.summary,
          categoryName: result.detectedCategory,
          tags: result.tags,
          measurements: convertedMeasurements,
        );

        // 1. Immediately update UI state so user sees all parameters instantly!
        if (mounted) {
          setState(() {
            _doc = (_doc ??
                    MedicalDocument(
                      id: widget.documentId,
                      originalName: 'Document',
                      fileType: 'image/jpeg',
                      fileSize: 0,
                      processingStatus: 'COMPLETED',
                      uploadedAt: DateTime.now().toIso8601String(),
                    ))
                .copyWith(
              processingStatus: 'COMPLETED',
              processingError: null,
              category: matchedCategory,
              tags: result.tags.map((t) => DocumentTag(id: t, tag: t)).toList(),
              extractedText: ExtractedText(
                id: widget.documentId,
                text: result.text,
                confidence: result.confidence,
                snippet: result.summary,
              ),
              healthMeasurements: convertedMeasurements,
            );
          });

          // Switch directly to Parameters tab if measurements were found
          if (convertedMeasurements.isNotEmpty) {
            _tabController.animateTo(2);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Medical AI: Categorized as ${result.detectedCategory} • ${convertedMeasurements.length} parameters extracted!',
              ),
              backgroundColor: AppTheme.success,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        // 2. Persist to backend and merge with backend response
        try {
          final res = await _docService.updateText(
            widget.documentId,
            text: result.text,
            confidence: result.confidence,
            categoryName: result.detectedCategory,
            tags: result.tags,
            parameters: result.parameters,
            summary: result.summary,
          );

          if (mounted && res['document'] != null) {
            final backendDoc = MedicalDocument.fromJson(
                res['document'] as Map<String, dynamic>);
            setState(() {
              if (backendDoc.healthMeasurements.isNotEmpty) {
                _doc = backendDoc;
              } else if (convertedMeasurements.isNotEmpty) {
                _doc = backendDoc.copyWith(
                    healthMeasurements: convertedMeasurements);
              }
            });
          }
        } catch (e) {
          debugPrint('Backend sync note: $e');
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Please select the photo to analyze with AI';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = ApiErrorHandler.extract(e));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Delete this document? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await _docService.delete(widget.documentId);
      if (mounted) context.go('/records');
    } catch (e) {
      setState(() {
        _error = 'Failed to delete';
        _deleting = false;
      });
    }
  }

  Future<void> _showCategorySheet() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ..._categories.map(
              (cat) => ListTile(
                leading: Text(cat.icon, style: const TextStyle(fontSize: 20)),
                title: Text(cat.name),
                subtitle: cat.description != null
                    ? Text(
                        cat.description!,
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await _docService.updateCategory(widget.documentId, cat.id);
                    _loadDocument();
                  } catch (_) {}
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCorrectionDialog(HealthMeasurementRef m) async {
    final valueController = TextEditingController(text: m.value.toString());
    final dateController = TextEditingController(
      text: m.measuredAt?.split('T').first ?? '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Correct Measurement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${m.parameter?.displayName ?? m.parameterId} — Original: "${m.originalText}"',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valueController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Value'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dateController,
              decoration: const InputDecoration(
                labelText: 'Date (YYYY-MM-DD)',
                hintText: '2024-01-15',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = double.tryParse(valueController.text);
              if (value == null) return;
              Navigator.pop(ctx);
              try {
                await _healthService.correctMeasurement(
                  m.id,
                  value: value,
                  measuredAt: dateController.text.isNotEmpty
                      ? dateController.text
                      : null,
                );
                _loadDocument();
              } catch (_) {
                setState(() => _error = 'Failed to correct measurement');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _doc == null) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Loading document...'),
      );
    }

    if (_doc == null) {
      final isSessionError = _error != null &&
          (_error!.toLowerCase().contains('session') ||
              _error!.toLowerCase().contains('sign in') ||
              _error!.toLowerCase().contains('log in'));

      return PopScope(
        canPop: context.canPop(),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) context.go('/records');
        },
        child: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _handleBack,
                      ),
                      const Text(
                        'Document',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AlertBanner(
                    message: _error ??
                        'Failed to load document details. Please check your network connection and tap Retry.',
                    type: AlertType.error,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: isSessionError
                        ? ElevatedButton.icon(
                            onPressed: () => context.go('/login'),
                            icon: const Icon(Icons.login, size: 16),
                            label: const Text('Sign In Again'),
                          )
                        : ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _loading = true;
                                _error = null;
                              });
                              _loadDocument();
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry Loading'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final doc = _doc!;

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/records');
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _handleBack,
                      color: AppTheme.textSecondary,
                    ),
                    Expanded(
                      child: Text(
                        doc.originalName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null)
                        AlertBanner(message: _error!, type: AlertType.error),

                      // Status banner
                      _buildStatusBanner(doc),
                      const SizedBox(height: 12),

                      // Actions
                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ElevatedButton.icon(
                              onPressed: _processing ? null : _handleProcess,
                              icon: const Icon(Icons.auto_awesome, size: 14),
                              label: Text(
                                _processing
                                    ? 'Analyzing...'
                                    : 'Analyze with AI',
                                style: const TextStyle(fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _showCategorySheet,
                            icon: const Icon(Icons.label_outline, size: 14),
                            label: const Text(
                              'Category',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _deleting ? null : _handleDelete,
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppTheme.danger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tab bar
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.bgInput,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: AppTheme.shadowSm,
                          ),
                          labelColor: AppTheme.primary,
                          unselectedLabelColor: AppTheme.textMuted,
                          labelStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          dividerColor: Colors.transparent,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          tabs: [
                            const Tab(
                              icon: Icon(Icons.description_outlined, size: 15),
                              text: 'Real Report',
                            ),
                            const Tab(
                              icon: Icon(Icons.auto_awesome, size: 15),
                              text: 'AI Report',
                            ),
                            Tab(
                              icon: const Icon(Icons.monitor_heart, size: 15),
                              text: 'Parameters (${doc.healthMeasurements.length})',
                            ),
                            const Tab(
                              icon: Icon(Icons.info_outline, size: 15),
                              text: 'Info',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tab content
                      SizedBox(
                        height: 520,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildRealReportTab(doc),
                            _buildTextTab(doc),
                            _buildParamsTab(doc),
                            _buildInfoTab(doc),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(MedicalDocument doc) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (doc.processingStatus) {
      case 'PROCESSING':
        bgColor = AppTheme.warningLight;
        textColor = AppTheme.warning;
        icon = Icons.refresh;
        label = 'Processing...';
      case 'COMPLETED':
        final double? conf = doc.extractedText?.confidence;
        final bool isLow =
            (conf != null && (conf <= 1.0 ? conf : conf / 100) < 0.60);
        if (isLow) {
          bgColor = AppTheme.warningLight;
          textColor = AppTheme.warning;
          icon = Icons.warning_amber_rounded;
          label = 'Processing completed (Low accuracy warning)';
        } else {
          bgColor = AppTheme.successLight;
          textColor = AppTheme.success;
          icon = Icons.check_circle;
          label = 'Processing completed (Medical AI)';
        }
      case 'FAILED':
        bgColor = AppTheme.dangerLight;
        textColor = AppTheme.danger;
        icon = Icons.error;
        label = 'Processing failed';
      default:
        bgColor = AppTheme.primaryLight;
        textColor = AppTheme.primary;
        icon = Icons.access_time;
        label = 'Uploaded - Pending processing';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: textColor)),
                if (doc.processingError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      doc.processingError!,
                      style: TextStyle(fontSize: 12, color: textColor),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  String? _resolveImageUrl(MedicalDocument doc) {
    final lowerName = doc.originalName.toLowerCase();
    final lowerType = doc.fileType.toLowerCase();
    if (lowerName.endsWith('.pdf') || lowerType.contains('pdf')) {
      return null;
    }

    if (doc.storagePath != null && doc.storagePath!.isNotEmpty) {
      if (doc.storagePath!.startsWith('http://') ||
          doc.storagePath!.startsWith('https://')) {
        return doc.storagePath!;
      }
      return '${ApiConfig.baseUrl.replaceAll('/api', '')}${doc.storagePath}';
    }

    final fileIdentifier = doc.fileName ?? doc.originalName;
    if (fileIdentifier.isNotEmpty) {
      return '${ApiConfig.baseUrl.replaceAll('/api', '')}/uploads/$fileIdentifier';
    }
    return null;
  }

  void _showFullScreenImage(String? imageUrl, Uint8List? imageBytes, String title) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: Center(
                  child: imageBytes != null
                      ? Image.memory(imageBytes, fit: BoxFit.contain)
                      : (imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.contain,
                              placeholder: (context, url) =>
                                  const CircularProgressIndicator(color: Colors.white),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.broken_image,
                                size: 60,
                                color: Colors.white54,
                              ),
                            )
                          : const SizedBox.shrink()),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPdfViewerPlaceholder(MedicalDocument doc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFDA4AF)),
              ),
              child: const Icon(
                Icons.picture_as_pdf,
                size: 36,
                color: Color(0xFFE11D48),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              doc.originalName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'PDF Medical Record • ${(doc.fileSize / 1024).toStringAsFixed(1)} KB',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.auto_awesome, size: 15),
              label: const Text('View AI Generated Report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealReportTab(MedicalDocument doc) {
    final isPdf = doc.fileType.toLowerCase().contains('pdf') ||
        doc.originalName.toLowerCase().endsWith('.pdf');
    final imageUrl = _resolveImageUrl(doc);
    final hasImage = _localImageBytes != null || imageUrl != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sub-header toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.bgInput,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusSm)),
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isPdf ? Icons.picture_as_pdf : Icons.image_outlined,
                      size: 16,
                      color: isPdf ? const Color(0xFFE11D48) : AppTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPdf ? 'Original PDF Document' : 'Original Scanned Report',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (!isPdf && hasImage)
                  InkWell(
                    onTap: () => _showFullScreenImage(imageUrl, _localImageBytes, doc.originalName),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fullscreen, size: 14, color: AppTheme.primary),
                          SizedBox(width: 4),
                          Text(
                            'Full Screen',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Main display area with pinch-to-zoom
          Expanded(
            child: isPdf
                ? _buildPdfViewerPlaceholder(doc)
                : (_localImageBytes != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(AppTheme.radiusSm),
                        ),
                        child: InteractiveViewer(
                          panEnabled: true,
                          scaleEnabled: true,
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Center(
                            child: Image.memory(
                              _localImageBytes!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      )
                    : (imageUrl != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(AppTheme.radiusSm),
                            ),
                            child: InteractiveViewer(
                              panEnabled: true,
                              scaleEnabled: true,
                              minScale: 0.5,
                              maxScale: 4.0,
                              child: Center(
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) => Image.asset(
                                    'assets/images/report_icon.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/report_icon.png',
                                  width: 90,
                                  height: 90,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Original Scanned Photo',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _handleProcess,
                                  icon: const Icon(Icons.photo_library, size: 14),
                                  label: const Text('Select Photo from Gallery', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ))),
          ),

          // Footer bar with quick action to switch to AI report
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.bgInput,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusSm)),
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pinch, size: 14, color: AppTheme.textMuted),
                    SizedBox(width: 4),
                    Text(
                      'Pinch to zoom',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _tabController.animateTo(1),
                  icon: const Icon(Icons.auto_awesome, size: 13, color: AppTheme.primary),
                  label: const Text(
                    'View AI Report →',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildInfoTab(MedicalDocument doc) {
    // Extract AI Clinical Summary from snippet or from markdown block
    String? aiSummary = doc.extractedText?.snippet;
    final text = doc.extractedText?.text ?? '';
    if ((aiSummary == null || aiSummary.isEmpty) &&
        text.contains('> **AI Clinical Summary**:')) {
      final parts = text.split('> **AI Clinical Summary**:');
      if (parts.length > 1) {
        aiSummary = parts[1].split('\n\n').first.trim();
      }
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          if (aiSummary != null && aiSummary.isNotEmpty) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 15, color: AppTheme.primary),
                      SizedBox(width: 6),
                      Text(
                        'AI Clinical Summary',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    aiSummary,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _infoRow('File Name', doc.originalName),
                _infoRow('File Type', doc.fileType),
                _infoRow(
                  'File Size',
                  '${(doc.fileSize / 1024).toStringAsFixed(1)} KB',
                ),
                _infoRow('Uploaded', _formatDate(doc.uploadedAt)),
                _infoRow(
                  'Category',
                  doc.category != null
                      ? '${doc.category!.icon} ${doc.category!.name}'
                      : 'Not categorized',
                ),
                _infoRow('Status', doc.processingStatus),
                if (doc.extractedText?.confidence != null) ...[
                  _infoRow(
                    'Accuracy',
                    '${(doc.extractedText!.confidence! <= 1.0 ? doc.extractedText!.confidence! * 100 : doc.extractedText!.confidence!).toStringAsFixed(1)}%',
                  ),
                  _infoRow('Engine', 'Medical AI Vision ✨'),
                ],
                _infoRow(
                  'Extracted Biomarkers',
                  '${doc.healthMeasurements.length} parameters',
                ),
                if (doc.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: doc.tags
                          .where((t) => ![
                                'mg',
                                'ml',
                                'g',
                                'kg',
                                'unit',
                                'units'
                              ].contains(t.tag.toLowerCase()))
                          .map((t) => Chip(label: Text(t.tag)))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextTab(MedicalDocument doc) {
    if (doc.extractedText == null) {
      return const EmptyState(
        icon: Icons.description,
        title: 'No text extracted',
        description: 'Process this document to extract text using OCR',
      );
    }

    final String text = doc.extractedText!.text ?? '';
    final double? rawConf = doc.extractedText!.confidence;
    final double? normConf = rawConf != null
        ? (rawConf <= 1.0 ? rawConf * 100 : rawConf)
        : null;

    final isLow = normConf != null && normConf < 60;
    final qualityLabel = isLow
        ? 'Low Accuracy (Manual review advised)'
        : (normConf != null && normConf < 85 ? 'Medium Accuracy' : 'High Accuracy');
    final qualityColor =
        isLow ? AppTheme.warning : (normConf != null && normConf < 85 ? AppTheme.textSecondary : AppTheme.success);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: qualityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: qualityColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLow ? Icons.info_outline : Icons.check_circle_outline,
                        size: 13,
                        color: qualityColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        normConf != null
                            ? '$qualityLabel (${normConf.toStringAsFixed(1)}%)'
                            : qualityLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: qualityColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Copy Full Text',
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('OCR text copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                TextButton.icon(
                  onPressed: _processing ? null : _handleProcess,
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: Text(
                    _processing ? 'Processing...' : 'Re-analyze with AI',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => _tabController.animateTo(0),
              icon: const Icon(Icons.arrow_back, size: 13, color: AppTheme.primary),
              label: const Text('← Real Report', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Markdown', style: TextStyle(fontSize: 11)),
                  icon: Icon(Icons.table_chart_outlined, size: 13),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Plain Text', style: TextStyle(fontSize: 11)),
                  icon: Icon(Icons.notes, size: 13),
                ),
              ],
              selected: {_showFormatted},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() {
                  _showFormatted = newSelection.first;
                });
              },
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgInput,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.border),
            ),
            child: _showFormatted
                ? Markdown(
                    data: text.isNotEmpty ? text : 'No text extracted',
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                      p: const TextStyle(
                          fontSize: 13, height: 1.6, color: AppTheme.textPrimary),
                      h1: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary),
                      h2: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary),
                      h3: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary),
                      tableBorder:
                          TableBorder.all(color: AppTheme.border, width: 1),
                      tableHead: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary),
                      tableBody: const TextStyle(
                          fontSize: 12, color: AppTheme.textPrimary),
                      tableCellsPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      code: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: AppTheme.textPrimary),
                    ),
                  )
                : SingleChildScrollView(
                    child: SelectableText(
                      text.isNotEmpty ? text : 'No text extracted',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.7,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildParamsTab(MedicalDocument doc) {
    if (doc.healthMeasurements.isEmpty) {
      return EmptyState(
        icon: Icons.monitor_heart,
        title: 'No parameters extracted yet',
        description: doc.processingStatus == 'COMPLETED'
            ? 'No health parameters found in this document. Tap below to re-extract with Medical AI.'
            : 'Extract health biomarkers and parameters using Medical AI.',
        action: ElevatedButton.icon(
          onPressed: _processing ? null : _handleProcess,
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: Text(_processing ? 'Analyzing...' : 'Extract with AI'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: doc.healthMeasurements.length,
            itemBuilder: (context, index) {
              final m = doc.healthMeasurements[index];
              final needsReview =
                  m.confidence != null && m.confidence! < 0.8 && !m.isManualEntry;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: needsReview
                    ? BoxDecoration(
                        border: Border.all(color: AppTheme.warning, width: 1),
                        borderRadius: BorderRadius.circular(12),
                        color: AppTheme.warningLight.withValues(alpha: 0.5),
                      )
                    : null,
                child: ParamCard(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.monitor_heart,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                  ),
                  title: m.parameter?.displayName ?? m.parameterId ?? 'Unknown',
                  subtitle: m.originalText != null ? '"${m.originalText}"' : null,
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        m.value.toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      Text(
                        m.unit,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      if (m.isManualEntry)
                        const StatusBadge(status: 'COMPLETED', small: true)
                      else if (needsReview)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.warning,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Review',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () => _showCorrectionDialog(m),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
