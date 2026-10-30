import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/health_service.dart';
import '../services/document_service.dart';
import '../services/medical_history_cache.dart';
import '../models/health_parameter.dart';
import '../models/document.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_indicator.dart';

const _paramIcons = {
  'glucose': '🩸',
  'hemoglobin': '🔴',
  'systolic_bp': '❤️',
  'diastolic_bp': '💙',
  'cholesterol': '🟡',
  'heart_rate': '💓',
  'hba1c': '🧪',
  'creatinine': '🟠',
  'wbc': '⚪',
  'platelets': '🟤',
};

class HealthParamsScreen extends StatefulWidget {
  const HealthParamsScreen({super.key});

  @override
  State<HealthParamsScreen> createState() => _HealthParamsScreenState();
}

class _HealthParamsScreenState extends State<HealthParamsScreen> {
  final _healthService = HealthService();
  final _docService = DocumentService();

  List<HealthParameter> _parameters = [];
  Map<String, List<Map<String, dynamic>>> _historyByParam = {};
  bool _loading = true;
  String _selectedFilter = 'all'; // 'all', 'tracked', 'untracked'

  @override
  void initState() {
    super.initState();
    _loadParameters();
  }

  Future<void> _loadParameters() async {
    try {
      // 1. Auto-scan all uploaded documents to aggregate any extracted parameters
      try {
        final docsData = await _docService.list(limit: 50);
        final docs = (docsData['documents'] as List?)
            ?.map((d) => d is MedicalDocument
                ? d
                : MedicalDocument.fromJson(d as Map<String, dynamic>))
            .toList() ?? [];
        for (final doc in docs) {
          final cached = await MedicalHistoryCache.loadDocumentState(doc.id);
          if (cached != null && cached['measurements'] != null) {
            final list = cached['measurements'] as List<dynamic>;
            if (list.isNotEmpty) {
              final refs = list
                  .map((m) =>
                      HealthMeasurementRef.fromJson(m as Map<String, dynamic>))
                  .toList();
              await MedicalHistoryCache.recordMeasurements(
                doc.id,
                doc.originalName,
                refs,
              );
            }
          } else if (doc.healthMeasurements.isNotEmpty) {
            await MedicalHistoryCache.recordMeasurements(
              doc.id,
              doc.originalName,
              doc.healthMeasurements,
            );
          }
        }
      } catch (_) {}

      // 2. Fetch parameters and grouped history
      final params = await _healthService.getParameters();
      final grouped = await MedicalHistoryCache.getHistoryGroupedByParameter();

      if (mounted) {
        setState(() {
          _parameters = params;
          _historyByParam = grouped;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Loading health parameters & history...'),
      );
    }

    final trackedParams = _parameters.where((p) {
      final history = _historyByParam[MedicalHistoryCache.canonicalize(p.name)] ?? [];
      return p.measurementCount > 0 || history.isNotEmpty;
    }).toList();

    final untrackedParams = _parameters.where((p) {
      final history = _historyByParam[MedicalHistoryCache.canonicalize(p.name)] ?? [];
      return p.measurementCount == 0 && history.isEmpty;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadParameters,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Health Parameters',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'History & trends extracted from your reports',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppTheme.primary),
                      onPressed: () {
                        setState(() => _loading = true);
                        _loadParameters();
                      },
                      tooltip: 'Refresh History',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Clinical disclaimer banner
                const AlertBanner(
                  message:
                      '⚠️ Values are extracted from uploaded medical reports using Medical AI. Always consult your doctor for medical decisions.',
                  type: AlertType.warning,
                ),
                const SizedBox(height: 14),

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All Parameters (${_parameters.length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'tracked',
                        'With History (${trackedParams.length})',
                        icon: Icons.trending_up,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'untracked',
                        'Available (${untrackedParams.length})',
                        icon: Icons.monitor_heart_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 1. TRACKED PARAMETERS SECTION (WITH GRAPHS & HISTORY)
                if (_selectedFilter != 'untracked' && trackedParams.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.show_chart, size: 20, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Tracked Parameters with History (${trackedParams.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...trackedParams.map((p) {
                    final canonical = MedicalHistoryCache.canonicalize(p.name);
                    final history = _historyByParam[canonical] ?? [];
                    return _buildParameterGraphCard(p, history);
                  }),
                  const SizedBox(height: 20),
                ],

                // 2. UNTRACKED / NO DATA YET SECTION
                if (_selectedFilter != 'tracked' && untrackedParams.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.checklist_rtl, size: 20, color: AppTheme.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        'No Data Yet (${untrackedParams.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...untrackedParams.map(_buildUntrackedCard),
                  const SizedBox(height: 20),
                ],

                // Empty state if totally empty
                if (trackedParams.isEmpty && untrackedParams.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 40),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.monitor_heart, size: 48, color: AppTheme.primary),
                        const SizedBox(height: 12),
                        const Text(
                          'No health parameters extracted yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Upload your blood test, prescription, or clinical report to see your health history and graphs here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/upload'),
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text('Upload Report'),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, {IconData? icon}) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Parameter Card with Embedded Graph & Detailed Measurement History
  Widget _buildParameterGraphCard(
    HealthParameter param,
    List<Map<String, dynamic>> history,
  ) {
    // Determine latest reading
    double? latestVal;
    String unit = param.defaultUnit;
    String? latestDate;
    String? latestReport;

    if (history.isNotEmpty) {
      final latest = history.last;
      latestVal = (latest['value'] as num).toDouble();
      unit = latest['unit']?.toString() ?? param.defaultUnit;
      latestDate = latest['measuredAt']?.toString();
      latestReport = latest['documentName']?.toString();
    } else if (param.latestMeasurement != null) {
      latestVal = param.latestMeasurement!.value;
      unit = param.latestMeasurement!.unit;
    }

    // Reference range status
    String status = 'NORMAL';
    Color statusColor = AppTheme.success;
    if (latestVal != null) {
      if (param.normalMax != null && latestVal > param.normalMax!) {
        status = 'HIGH';
        statusColor = AppTheme.danger;
      } else if (param.normalMin != null && latestVal < param.normalMin!) {
        status = 'LOW';
        statusColor = AppTheme.warning;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. CARD HEADER
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _paramIcons[param.name] ?? '📊',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name and normal range
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        param.displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        param.normalMin != null && param.normalMax != null
                            ? 'Normal: ${param.normalMin}–${param.normalMax} $unit'
                            : 'Unit: $unit',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      if (latestReport != null || latestDate != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          latestDate != null && latestReport != null
                              ? '${_formatHistoryDate(latestDate)} • $latestReport'
                              : (latestReport != null ? 'Source: $latestReport' : _formatHistoryDate(latestDate)),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Latest Value + Status Pill
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (latestVal != null) ...[
                      Text(
                        latestVal.toString(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        unit,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ] else
                      const Text(
                        '--',
                        style: TextStyle(fontSize: 18, color: AppTheme.textMuted),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.border),

          // 2. EMBEDDED GRAPH
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '📈 Trend Over Reports (${max(history.length, 1)} reading${history.length != 1 ? 's' : ''})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/trends/${param.name}'),
                      child: const Text(
                        'Full Graph →',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (history.length >= 2)
                  SizedBox(
                    height: 120,
                    child: _buildMiniLineChart(history, param),
                  )
                else
                  _buildSingleValueGauge(latestVal, param, unit),
              ],
            ),
          ),

          // 3. MEASUREMENT HISTORY LIST
          if (history.isNotEmpty) ...[
            const Divider(height: 1, color: AppTheme.border),
            Container(
              color: AppTheme.bgInput.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        'Measurement History (${history.length})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...history.reversed.take(4).map((item) {
                    final val = (item['value'] as num).toDouble();
                    final itemUnit = item['unit']?.toString() ?? unit;
                    final dateStr = _formatHistoryDate(item['measuredAt']?.toString());
                    final docName = item['documentName']?.toString() ?? 'Report';
                    final origText = item['originalText']?.toString();

                    return Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.description, size: 14, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  docName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  dateStr,
                                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                ),
                                if (origText != null && origText.isNotEmpty)
                                  Text(
                                    '"$origText"',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '$val $itemUnit',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Mini Sparkline / LineChart
  Widget _buildMiniLineChart(
    List<Map<String, dynamic>> history,
    HealthParameter param,
  ) {
    final spots = <FlSpot>[];
    final dates = <int, String>{};

    for (var i = 0; i < history.length; i++) {
      final val = (history[i]['value'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), val));
      final date = DateTime.tryParse(history[i]['measuredAt'] ?? '');
      if (date != null) {
        dates[i] = DateFormat('d MMM').format(date);
      }
    }

    final values = history.map((h) => (h['value'] as num).toDouble()).toList();
    double minVal = values.reduce(min);
    double maxVal = values.reduce(max);
    if (param.normalMin != null) minVal = min(minVal, param.normalMin!);
    if (param.normalMax != null) maxVal = max(maxVal, param.normalMax!);

    final minY = (minVal * 0.9).floorToDouble();
    final maxY = (maxVal * 1.1).ceilToDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppTheme.border.withValues(alpha: 0.7),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (dates.containsKey(idx)) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      dates[idx]!,
                      style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (history.length - 1).toDouble(),
        minY: minY,
        maxY: maxY > minY ? maxY : minY + 10,
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (param.normalMin != null)
              HorizontalLine(
                y: param.normalMin!,
                color: AppTheme.success.withValues(alpha: 0.6),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            if (param.normalMax != null)
              HorizontalLine(
                y: param.normalMax!,
                color: AppTheme.warning.withValues(alpha: 0.6),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 3.5,
                color: AppTheme.primary,
                strokeWidth: 1.5,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primary.withValues(alpha: 0.25),
                  AppTheme.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              return LineTooltipItem(
                '${s.y} ${param.defaultUnit}',
                const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // Single Value Range Gauge
  Widget _buildSingleValueGauge(
    double? val,
    HealthParameter param,
    String unit,
  ) {
    final minVal = param.normalMin ?? 70.0;
    final maxVal = param.normalMax ?? 100.0;
    final cur = val ?? minVal;
    final ratio = ((cur - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Min: $minVal $unit',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              Text('Max: $maxVal $unit',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppTheme.bgInput,
              valueColor: AlwaysStoppedAnimation<Color>(
                cur > maxVal
                    ? AppTheme.danger
                    : (cur < minVal ? AppTheme.warning : AppTheme.success),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              '1 reading extracted from report. Upload more reports to track timeline curve.',
              style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // Untracked Card
  Widget _buildUntrackedCard(HealthParameter p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.bgInput,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                _paramIcons[p.name] ?? '📊',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  p.normalMin != null && p.normalMax != null
                      ? 'Normal: ${p.normalMin}–${p.normalMax} ${p.defaultUnit}'
                      : 'Unit: ${p.defaultUnit}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/upload'),
            child: const Text('Upload', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _formatHistoryDate(String? raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('MMM d, yyyy • h:mm a').format(dt);
  }
}
