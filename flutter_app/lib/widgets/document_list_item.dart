import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../models/document.dart';
import 'status_badge.dart';

class DocumentListItem extends StatelessWidget {
  final MedicalDocument document;
  final VoidCallback onTap;

  const DocumentListItem({
    super.key,
    required this.document,
    required this.onTap,
  });

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

  Widget _buildReportThumbnail(bool isPdf) {
    final imageUrl = _resolveImageUrl(document);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.bgInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Image.asset(
                  'assets/images/report_icon.png',
                  fit: BoxFit.cover,
                ),
                errorWidget: (context, url, error) => Image.asset(
                  'assets/images/report_icon.png',
                  fit: BoxFit.cover,
                ),
              )
            else
              Image.asset(
                'assets/images/report_icon.png',
                fit: BoxFit.cover,
              ),

            // If it's a PDF, overlay a compact badge on bottom right
            if (isPdf)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE11D48),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(5),
                    ),
                  ),
                  child: const Text(
                    'PDF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = document.fileType.contains('pdf') ||
        document.originalName.toLowerCase().endsWith('.pdf');
    final paramCount = document.healthMeasurements.isNotEmpty
        ? document.healthMeasurements.length
        : (document.counts?['healthMeasurements'] ?? 0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            // Rich Report Image Thumbnail / Icon
            _buildReportThumbnail(isPdf),
            const SizedBox(width: 12),

            // Document info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.originalName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _buildMeta(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  if (document.tags.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: document.tags.take(3).map((t) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.bgInput,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            t.tag,
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.textSecondary),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Status + parameters count badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(status: document.processingStatus),
                if (paramCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monitor_heart, size: 11, color: AppTheme.primary),
                        const SizedBox(width: 3),
                        Text(
                          '$paramCount ${paramCount == 1 ? 'param' : 'params'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _buildMeta() {
    final date = DateTime.tryParse(document.uploadedAt);
    final dateStr = date != null
        ? '${date.day}/${date.month}/${date.year}'
        : '';
    final sizeStr = '${(document.fileSize / 1024).toStringAsFixed(0)} KB';
    final catStr =
        document.category != null ? ' • ${document.category!.name}' : '';
    return '$dateStr • $sizeStr$catStr';
  }
}
