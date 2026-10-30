import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/search_service.dart';
import '../services/medical_history_cache.dart';
import '../models/document.dart';
import '../theme/app_theme.dart';
import '../widgets/document_list_item.dart';
import '../widgets/loading_indicator.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchService = SearchService();
  final _controller = TextEditingController();
  List<MedicalDocument> _results = [];
  bool _loading = false;
  bool _searched = false;
  int _totalResults = 0;

  final _suggestions = [
    'glucose',
    'hemoglobin',
    'blood test',
    'prescription',
    'cholesterol',
  ];

  Future<void> _search([String? query]) async {
    final q = query ?? _controller.text.trim();
    if (q.isEmpty) return;

    if (query != null) _controller.text = q;

    setState(() {
      _loading = true;
      _searched = true;
    });

    try {
      final data = await _searchService.search(q);
      final rawResults = (data['results'] as List)
          .map((d) => d is MedicalDocument
              ? d
              : MedicalDocument.fromJson(d as Map<String, dynamic>))
          .toList();
      final results =
          await Future.wait(rawResults.map(MedicalHistoryCache.hydrateDocument));

      setState(() {
        _results = results;
        _totalResults =
            (data['pagination']?['total'] as num?)?.toInt() ?? results.length;
      });
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _loading = false);
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/home');
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
                    color: AppTheme.textSecondary,
                  ),
                  const Text(
                    'Search Records',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search bar
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by name, text, category...',
                  prefixIcon:
                      const Icon(Icons.search, color: AppTheme.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                ),
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: 12),

              // Suggestion chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _suggestions.map((term) {
                  return GestureDetector(
                    onTap: () => _search(term),
                    child: Chip(label: Text(term)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Results
              Expanded(
                child: _loading
                    ? const LoadingIndicator(message: 'Searching...')
                    : _searched && _results.isEmpty
                        ? const EmptyState(
                            icon: Icons.search_off,
                            title: 'No results found',
                            description:
                                'Try different keywords like "glucose", "blood test", or "prescription"',
                          )
                        : ListView(
                            children: [
                              if (_totalResults > 0 && _searched)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    'Found $_totalResults result${_totalResults != 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                              ..._results.map((doc) => DocumentListItem(
                                    document: doc,
                                    onTap: () async {
                                      await context.push('/documents/${doc.id}', extra: doc);
                                      _search();
                                    },
                                  )),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
