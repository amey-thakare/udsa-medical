import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/health_service.dart';
import '../models/health_parameter.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/param_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/status_badge.dart';

class HealthTrendsScreen extends StatefulWidget {
  final String parameter;
  const HealthTrendsScreen({super.key, required this.parameter});

  @override
  State<HealthTrendsScreen> createState() => _HealthTrendsScreenState();
}

class _HealthTrendsScreenState extends State<HealthTrendsScreen> {
  final _healthService = HealthService();
  HealthTrendData? _data;
  bool _loading = true;
  String? _error;

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/health');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTrends();
  }

  Future<void> _loadTrends() async {
    setState(() => _loading = true);
    try {
      final data = await _healthService.getTrends(widget.parameter);
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load trend data';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Loading trends...'),
      );
    }

    if (_error != null) {
      return PopScope(
        canPop: context.canPop(),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) context.go('/health');
        },
        child: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(children: [
                    IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _handleBack),
                    const Text('Health Trends',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700)),
                  ]),
                  AlertBanner(message: _error!, type: AlertType.error),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final data = _data!;
    final measurements = data.measurements;
    final values = measurements.map((m) => m.value).toList();
    final latest = values.isNotEmpty ? values.last : 0.0;
    final previous = values.length > 1 ? values[values.length - 2] : null;
    final avg = values.isNotEmpty
        ? (values.reduce((a, b) => a + b) / values.length)
        : 0.0;

    String trendLabel;
    Color trendColor;
    IconData trendIcon;

    if (previous == null) {
      trendLabel = 'First reading';
      trendColor = AppTheme.textMuted;
      trendIcon = Icons.remove;
    } else {
      final diff = latest - previous;
      if (diff > 0) {
        trendLabel = '+${diff.toStringAsFixed(1)}';
        trendColor = AppTheme.warning;
        trendIcon = Icons.trending_up;
      } else if (diff < 0) {
        trendLabel = diff.toStringAsFixed(1);
        trendColor = AppTheme.success;
        trendIcon = Icons.trending_down;
      } else {
        trendLabel = 'No change';
        trendColor = AppTheme.textMuted;
        trendIcon = Icons.remove;
      }
    }

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/health');
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
                  Text(
                    '${data.parameter.displayName} Trends',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              const AlertBanner(
                message:
                    '⚠️ For informational purposes only. This is not a medical diagnosis. Consult your healthcare provider for interpretation.',
                type: AlertType.warning,
              ),

              if (data.dataPoints == 0)
                EmptyState(
                  icon: Icons.trending_up,
                  title: 'No data available',
                  description:
                      'Upload medical reports containing ${data.parameter.displayName.toLowerCase()} values to see trends',
                )
              else ...[
                // Stats
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        value: latest.toString(),
                        label:
                            'Latest (${data.parameter.defaultUnit})',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: 'Trend',
                        customValue: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(trendIcon, size: 16, color: trendColor),
                            const SizedBox(width: 4),
                            Text(
                              trendLabel,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: trendColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        value: avg.toStringAsFixed(1),
                        label: 'Average',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        value: '${data.dataPoints}',
                        label: 'Readings',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Normal range
                if (data.parameter.normalMin != null &&
                    data.parameter.normalMax != null)
                  AlertBanner(
                    message:
                        'Normal range: ${data.parameter.normalMin}–${data.parameter.normalMax} ${data.parameter.defaultUnit}',
                    type: AlertType.info,
                  ),

                // Chart
                if (measurements.length >= 2) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radius),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.trending_up,
                                size: 16, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              '${data.parameter.displayName} Over Time',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 250,
                          child: _buildChart(measurements, data.parameter),
                        ),
                      ],
                    ),
                  ),
                ] else if (measurements.length == 1) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radius),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Only 1 data point. Upload more reports to see trends.',
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${measurements.first.value} ${data.parameter.defaultUnit}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // History
                const Text(
                  'Measurement History',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                ...measurements.reversed.map((m) => ParamCard(
                      leading: SizedBox(
                        width: 40,
                        child: Center(
                          child: Text(
                            m.value.toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ),
                      title: m.unit,
                      subtitle: m.measuredAt != null
                          ? _formatDate(m.measuredAt!)
                          : '',
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (m.isManualEntry)
                            const StatusBadge(
                                status: 'COMPLETED', small: true),
                          if (m.confidence != null)
                            Text(
                              '${(m.confidence! * 100).toStringAsFixed(0)}% conf.',
                              style: const TextStyle(
                                  fontSize: 10, color: AppTheme.textMuted),
                            ),
                        ],
                      ),
                    )),

                const SizedBox(height: 80),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildChart(
      List<HealthMeasurement> measurements, HealthParameter param) {
    final spots = <FlSpot>[];
    final dates = <int, String>{};

    for (var i = 0; i < measurements.length; i++) {
      spots.add(FlSpot(i.toDouble(), measurements[i].value));
      final date = DateTime.tryParse(measurements[i].measuredAt ?? '');
      if (date != null) {
        dates[i] = DateFormat('MMM d').format(date);
      }
    }

    final minY = measurements.map((m) => m.value).reduce(
            (a, b) => a < b ? a : b) *
        0.9;
    final maxY = measurements.map((m) => m.value).reduce(
            (a, b) => a > b ? a : b) *
        1.1;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppTheme.border,
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textMuted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (dates.containsKey(idx)) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      dates[idx]!,
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textMuted),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (measurements.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (param.normalMin != null)
              HorizontalLine(
                y: param.normalMin!,
                color: AppTheme.success,
                strokeWidth: 1,
                dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true,
                  labelResolver: (_) => 'Min',
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.success),
                ),
              ),
            if (param.normalMax != null)
              HorizontalLine(
                y: param.normalMax!,
                color: AppTheme.warning,
                strokeWidth: 1,
                dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true,
                  labelResolver: (_) => 'Max',
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.warning),
                ),
              ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.primary,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 4,
                color: AppTheme.primary,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primary.withValues(alpha: 0.2),
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
                    fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return DateFormat('MMM d, yyyy').format(date);
  }
}
