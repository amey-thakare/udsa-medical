import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/document_service.dart';
import '../services/medical_history_cache.dart';
import '../models/document.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../widgets/document_list_item.dart';
import '../widgets/loading_indicator.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final _docService = DocumentService();
  List<MedicalDocument> _documents = [];
  List<MedicalCategory> _categories = [];
  bool _loading = true;
  int _page = 1;
  int _totalPages = 1;
  final String _filterStatus = '';
  String _filterCategory = '';
  bool _groupByCategory = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadDocuments();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _docService.getCategories();
      setState(() => _categories = cats);
    } catch (_) {}
  }

  Future<void> _loadDocuments() async {
    setState(() => _loading = true);
    try {
      final data = await _docService.list(
        page: _page,
        limit: 50,
        status: _filterStatus.isEmpty ? null : _filterStatus,
        categoryId: _filterCategory.isEmpty ? null : _filterCategory,
      );

      final docs = (data['documents'] as List)
          .map((d) => MedicalDocument.fromJson(d as Map<String, dynamic>))
          .toList();

      final hydratedDocs =
          await Future.wait(docs.map(MedicalHistoryCache.hydrateDocument));

      setState(() {
        _documents = hydratedDocs;
        _totalPages =
            (data['pagination']?['pages'] as num?)?.toInt() ?? 1;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<MedicalDocument> get _filteredDocuments {
    if (_searchQuery.trim().isEmpty) return _documents;
    final q = _searchQuery.toLowerCase().trim();
    return _documents.where((doc) {
      final nameMatches = doc.originalName.toLowerCase().contains(q);
      final catMatches = doc.category?.name.toLowerCase().contains(q) ?? false;
      final tagMatches = doc.tags.any((t) => t.tag.toLowerCase().contains(q));
      return nameMatches || catMatches || tagMatches;
    }).toList();
  }

  Map<String, List<MedicalDocument>> get _groupedDocuments {
    final map = <String, List<MedicalDocument>>{};
    for (final doc in _filteredDocuments) {
      final catName = doc.category?.name ?? 'General';
      map.putIfAbsent(catName, () => []).add(doc);
    }
    return map;
  }

  int _countForCategory(String? catId) {
    if (catId == null || catId.isEmpty) return _documents.length;
    return _documents.where((d) => d.category?.id == catId || d.category?.name == catId).length;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDocuments;
    final grouped = _groupedDocuments;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & view mode toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Medical Records',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.folder_copy_outlined, size: 14),
                        label: Text('Groups', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.list_alt, size: 14),
                        label: Text('List', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                    selected: {_groupByCategory},
                    onSelectionChanged: (Set<bool> sel) {
                      setState(() => _groupByCategory = sel.first);
                    },
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search Bar
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.border),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'Search by report name, category, or tag...',
                    hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),

              // Category Pills / Chips (Horizontal Carousel)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip(
                      label: 'All (${_documents.length})',
                      icon: '🗂️',
                      isSelected: _filterCategory.isEmpty,
                      onTap: () {
                        setState(() {
                          _filterCategory = '';
                          _page = 1;
                        });
                        _loadDocuments();
                      },
                    ),
                    ..._categories.map((c) {
                      final count = _countForCategory(c.id);
                      return _buildCategoryChip(
                        label: '${c.name} ($count)',
                        icon: c.icon,
                        isSelected: _filterCategory == c.id,
                        onTap: () {
                          setState(() {
                            _filterCategory = _filterCategory == c.id ? '' : c.id;
                            _page = 1;
                          });
                          _loadDocuments();
                        },
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Content Area
              Expanded(
                child: _loading
                    ? const LoadingIndicator(message: 'Loading records...')
                    : filtered.isEmpty
                        ? EmptyState(
                            icon: Icons.description,
                            title: 'No records found',
                            description: _searchQuery.isNotEmpty ||
                                    _filterCategory.isNotEmpty ||
                                    _filterStatus.isNotEmpty
                                ? 'Try clearing your filters or search term'
                                : 'Upload your first medical document to get started',
                            action: ElevatedButton.icon(
                              onPressed: () async {
                                await context.push('/upload');
                                _loadDocuments();
                              },
                              icon: const Icon(Icons.upload, size: 16),
                              label: const Text('Upload Document'),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadDocuments,
                            child: _groupByCategory
                                ? _buildGroupedList(grouped)
                                : _buildFlatList(filtered),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedList(Map<String, List<MedicalDocument>> grouped) {
    final categoryOrder = [
      'Blood Test',
      'Prescription',
      'Lab Report',
      'Scan Report',
      'Discharge Summary',
      'Medical Bill',
      'General',
      'Other',
    ];

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final idxA = categoryOrder.indexOf(a);
        final idxB = categoryOrder.indexOf(b);
        if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
        return a.compareTo(b);
      });

    return ListView.builder(
      itemCount: sortedKeys.length,
      itemBuilder: (context, idx) {
        final catName = sortedKeys[idx];
        final docs = grouped[catName]!;
        final icon = _getCategoryIcon(catName);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    catName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${docs.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...docs.map(
              (doc) => DocumentListItem(
                document: doc,
                onTap: () async {
                  await context.push('/documents/${doc.id}', extra: doc);
                  _loadDocuments();
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Widget _buildFlatList(List<MedicalDocument> docs) {
    return ListView.builder(
      itemCount: docs.length + (_totalPages > 1 ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == docs.length) {
          return _buildPagination();
        }
        return DocumentListItem(
          document: docs[index],
          onTap: () async {
            await context.push('/documents/${docs[index].id}', extra: docs[index]);
            _loadDocuments();
          },
        );
      },
    );
  }

  String _getCategoryIcon(String cat) {
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

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton(
            onPressed: _page > 1
                ? () {
                    setState(() => _page--);
                    _loadDocuments();
                  }
                : null,
            child: const Text('Previous'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('$_page / $_totalPages',
                style: const TextStyle(fontSize: 13)),
          ),
          OutlinedButton(
            onPressed: _page < _totalPages
                ? () {
                    setState(() => _page++);
                    _loadDocuments();
                  }
                : null,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}
