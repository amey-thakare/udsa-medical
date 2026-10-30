import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../services/document_service.dart';
import '../services/health_service.dart';
import '../services/medical_history_cache.dart';
import '../models/document.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/document_list_item.dart';
import '../widgets/loading_indicator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _docService = DocumentService();
  final _healthService = HealthService();
  bool _loading = true;
  int _totalDocs = 0;
  int _processedDocs = 0;
  int _trackedParams = 0;
  int _totalMeasurements = 0;
  List<MedicalDocument> _recentDocs = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final results = await Future.wait([
        _docService.list(limit: 5),
        _healthService.getParameters(),
        MedicalHistoryCache.getProcessedDocIds(),
      ]);

      final docsData = results[0] as Map<String, dynamic>;
      final params = results[1] as List;
      final processedDocIds = results[2] as Set<String>;

      final rawDocs = (docsData['documents'] as List)
          .map((d) => d is MedicalDocument
              ? d
              : MedicalDocument.fromJson(d as Map<String, dynamic>))
          .toList();

      final docs =
          await Future.wait(rawDocs.map(MedicalHistoryCache.hydrateDocument));

      final totalMeasurements = params.fold<int>(
          0, (sum, p) => sum + (p.measurementCount as int));
      
      final inDocProcessedCount =
          docs.where((d) => d.processingStatus == 'COMPLETED').length;
      final processedCount =
          math.max(processedDocIds.length, inDocProcessedCount);

      setState(() {
        _totalDocs =
            (docsData['pagination']?['total'] as num?)?.toInt() ?? docs.length;
        _processedDocs = processedCount;
        _trackedParams =
            params.where((p) => p.measurementCount > 0).length;
        _totalMeasurements = totalMeasurements;
        _recentDocs = docs;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (_loading) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Loading dashboard...'),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting
                Text(
                  'Hello, ${user?.name.split(' ').first ?? 'User'}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'All your Reports, Simple, Smart, Sorted',
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),

                // Stats grid
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                          value: '$_totalDocs', label: 'Documents'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                          value: '$_processedDocs', label: 'Processed'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                          value: '$_trackedParams', label: 'Parameters'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                          value: '$_totalMeasurements',
                          label: 'Measurements'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Quick actions
                const Text(
                  'Quick Actions',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await context.push('/upload');
                          _loadDashboard();
                        },
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('Upload Report',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await context.push('/search');
                          _loadDashboard();
                        },
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('Search',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Recent documents
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Documents',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    GestureDetector(
                      onTap: () async {
                        await context.push('/records');
                        _loadDashboard();
                      },
                      child: const Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_recentDocs.isEmpty)
                  const EmptyState(
                    icon: Icons.description,
                    title: 'No documents yet',
                    description:
                        'Upload your first medical report to get started',
                  )
                else
                  ..._recentDocs.map(
                    (doc) => DocumentListItem(
                      document: doc,
                      onTap: () async {
                        await context.push('/documents/${doc.id}', extra: doc);
                        _loadDashboard();
                      },
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
}
