part of '../main_screen.dart';

/// Native equivalents of the five CMS public navigation destinations.
class CmsPage extends StatefulWidget {
  const CmsPage({
    super.key,
    required this.kind,
    required this.onSelect,
    this.api,
  });
  final String kind;
  final ValueChanged<int> onSelect;
  final CmsApi? api;
  @override
  State<CmsPage> createState() => _CmsPageState();
}

class _CmsPageState extends State<CmsPage> {
  late final _api = widget.api ?? CmsApi.instance;
  final _search = TextEditingController();
  final _newsAnchor = GlobalKey();
  final _suggestionOverlay = OverlayPortalController();
  Timer? _suggestionTimer;
  int _suggestionRequest = 0;
  List<String> _suggestions = [];
  String _appliedQuery = '';
  String _module = 'all';
  String _sort = 'recent';
  String _category = '', _semester = '', _academicYear = '';
  String _period = '', _event = '', _reportYear = '';
  Map<String, List<String>> _filterOptions = {};
  Map<String, String> get _feedFilters => {
    if (_category.isNotEmpty) 'category': _category,
    if (_semester.isNotEmpty) 'semester': _semester,
    if (_academicYear.isNotEmpty) 'academic_year': _academicYear,
    if (_period.isNotEmpty) 'period': _period,
    if (_event.isNotEmpty) 'event': _event,
    if (_reportYear.isNotEmpty) 'year': _reportYear,
  };
  CmsHome? _home;
  CmsAbout? _about;
  CmsPostPage? _page;
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _dismissSuggestions() {
    _suggestionTimer?.cancel();
    _suggestionRequest++;
    if (_suggestionOverlay.isShowing) _suggestionOverlay.hide();
  }

  void _suggest(String input) {
    _dismissSuggestions();
    final query = input.trim();
    if (query.isEmpty) return;
    setState(() => _suggestions = []);
    _suggestionOverlay.show();
    if (query.runes.length < 2) return;
    final request = _suggestionRequest;
    _suggestionTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        final page = await _fetchPage(query, includeOptions: false);
        if (!mounted || request != _suggestionRequest) return;
        final seen = <String>{};
        setState(() {
          _suggestions = page.items
              .map((post) => post.title.trim())
              .where(
                (title) => title.isNotEmpty && seen.add(title.toLowerCase()),
              )
              .take(5)
              .toList();
        });
      } catch (_) {
        // The user can still submit the search if suggestions fail to load.
      }
    });
  }

  Widget _buildSearchSuggestions(
    BuildContext context,
    OverlayChildLayoutInfo layout,
  ) {
    final field = MatrixUtils.transformRect(
      layout.childPaintTransform,
      Offset.zero & layout.childSize,
    );
    final viewportBottom =
        layout.overlaySize.height - MediaQuery.viewInsetsOf(context).bottom;
    const gap = 4.0;
    final below = viewportBottom - field.bottom - gap;
    final above = field.top - MediaQuery.paddingOf(context).top - gap;
    final opensUp = below < 140 && above > below;
    final maxHeight = (opensUp ? above : below).clamp(0.0, 240.0).toDouble();
    if (maxHeight == 0 || field.bottom < 0 || field.top >= viewportBottom) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        Positioned(
          left: field.left,
          width: field.width,
          top: opensUp ? null : field.bottom + gap,
          bottom: opensUp ? layout.overlaySize.height - field.top + gap : null,
          child: TextFieldTapRegion(
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    children: [
                      for (final title in _suggestions)
                        ListTile(
                          dense: true,
                          title: Text(title),
                          onTap: () => _submitSuggestion(title),
                        ),
                      ListTile(
                        dense: true,
                        title: Text('Search for “${_search.text.trim()}”'),
                        onTap: _submitSuggestion,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _submitSuggestion([String? title]) {
    if (title != null) {
      _search.text = String.fromCharCodes(title.runes.take(100));
    }
    FocusScope.of(context).unfocus();
    reload();
  }

  Future<void> reload() async {
    _dismissSuggestions();
    final request = ++_request;
    _appliedQuery = _search.text.trim();
    setState(() {
      _suggestions = [];
      _loading = true;
      _error = null;
      _page = null;
    });
    try {
      if (widget.kind == 'home') {
        final result = await _api.home();
        if (mounted && request == _request) setState(() => _home = result);
      } else if (widget.kind == 'about') {
        final result = await _api.about();
        if (mounted && request == _request) setState(() => _about = result);
      } else {
        final result = await _fetchPage(_appliedQuery);
        if (mounted && request == _request) {
          setState(() {
            _page = result;
            _filterOptions = result.filters;
          });
        }
      }
    } catch (error) {
      if (mounted && request == _request) setState(() => _error = error);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<CmsPostPage> _fetchPage(
    String query, {
    int page = 1,
    bool includeOptions = true,
  }) {
    if (widget.kind == 'discover') {
      return _api.discoverPage(
        type: _module,
        query: query,
        sort: _sort,
        period: _period,
        category: _category,
        page: page,
        includeOptions: includeOptions && page == 1,
      );
    }
    return _api.postsPage(
      widget.kind,
      query: query,
      sort: _sort,
      filters: _feedFilters,
      page: page,
      includeOptions: includeOptions && page == 1,
    );
  }

  Future<void> _more() async {
    final page = _page;
    if (page == null || !page.hasMore || _loadingMore) return;
    final request = _request;
    setState(() => _loadingMore = true);
    try {
      final next = await _fetchPage(_appliedQuery, page: page.currentPage + 1);
      if (mounted && request == _request) {
        setState(() => _page = next.withItems([...page.items, ...next.items]));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load more posts. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final compact = MediaQuery.sizeOf(context).width < 768;
    final name = kind == 'liquidations' ? 'transparency' : kind;
    final title = switch (kind) {
      'home' => 'Welcome to the SSITE Community!',
      'discover' => 'Discover SSITE',
      'documents' => 'Official records',
      'liquidations' => 'Transparency',
      _ => 'Get to know SSITE',
    };
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (kind == 'home')
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CommunityHero(
                  onBrowse: () => widget.onSelect(1),
                  onUpdates: () {
                    if (_newsAnchor.currentContext case final anchor?) {
                      Scrollable.ensureVisible(
                        anchor,
                        duration: const Duration(milliseconds: 300),
                      );
                    }
                  },
                ),
                _intro(),
                SizedBox(key: _newsAnchor),
              ],
            )
          else
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1045),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 16 : 20,
                    vertical: compact ? 22 : 24,
                  ),
                  child: CmsHero(name: name, label: title),
                ),
              ),
            ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 864),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (kind != 'home' && kind != 'about') ..._filters(),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      _Failure(error: _error!, onRetry: reload)
                    else if (kind == 'home' && _home != null)
                      ..._homeContent(_home!)
                    else if (kind == 'about' && _about != null)
                      ..._aboutContent(_about!)
                    else
                      ..._feedContent(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const CmsFooter(),
        ],
      ),
    );
  }

  Widget _intro() => Padding(
    padding: const EdgeInsets.only(bottom: 32),
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF11D0DF), Color(0xFF64E5EE)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ColoredBox(
              color: Color(0xFF0BA6C0),
              child: SizedBox(height: 3),
            ),
            const SizedBox(height: 32),
            Image.asset(
              'assets/images/rawri-community-cutout.png',
              height: 176,
              fit: BoxFit.contain,
              semanticLabel: 'SSITE wolf mascot wearing a hoodie',
            ),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 576),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    children: [
                      Text(
                        'Welcome to the SSITE Community!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Welcome to the official website of the Student Society in Information Technology Education (SSITE) of Mabalacat City College. Stay connected with our latest announcements, activities, articles, and achievements as we bring IT students together through collaboration, innovation, and meaningful experiences.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF063847),
                          height: 1.55,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  List<Widget> _homeContent(CmsHome data) => [
    const _Heading("What's New at SSITE"),
    for (final post in [
      ...data.articles,
      ...data.activities,
      ...data.achievements,
    ])
      _NewsCard(post: post, imageFirst: post.module != 'articles'),
    if (data.articles.isEmpty &&
        data.activities.isEmpty &&
        data.achievements.isEmpty)
      const _Empty('No posts have been published yet.'),
    Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () => widget.onSelect(1),
        label: const Text('Discover more'),
        icon: const Icon(Icons.arrow_forward, size: 18),
      ),
    ),
    const SizedBox(height: 24),
    const _Heading('Meet the SSITE Leaders'),
    if (data.officers.isEmpty)
      const _Empty('Our current leaders will be announced soon.')
    else
      _Officers(officers: data.officers),
    TextButton(
      onPressed: () => widget.onSelect(4),
      child: const Text('About the organization'),
    ),
    const SizedBox(height: 24),
    const _Heading('The Network Behind SSITE'),
    const Text(
      'Recognizing the partners and sponsors whose support, collaboration, and shared vision help SSITE create meaningful opportunities for IT students and the community.',
      style: TextStyle(color: muted, height: 1.7, fontSize: 14),
    ),
    const SizedBox(height: 16),
    if (data.sponsors.isEmpty)
      const _Empty('Our partners and sponsors will be announced soon.'),
    for (final sponsor in data.sponsors) _SponsorCard(sponsor: sponsor),
  ];

  List<Widget> _aboutContent(CmsAbout data) => [
    const _InfoCard(
      title: 'Mission',
      text:
          'SSITE provides hands-on, research-based, and values-centered learning experiences, equipping students with the skills needed to excel in both local and global IT industries while fulfilling their social responsibilities.',
    ),
    const _InfoCard(
      title: 'Vision',
      text:
          'SSITE aims to cultivate competitive Information Technology professionals capable of thriving in both local and international IT industries while upholding ethical standards.',
    ),
    const SizedBox(height: 16),
    _Heading('SSITE Officers A.Y. ${data.academicYear}'),
    if (data.officers.isEmpty)
      _Empty('Officers for A.Y. ${data.academicYear} will be announced soon.')
    else
      _Officers(officers: data.officers),
    if (data.history.isNotEmpty) ...[
      const SizedBox(height: 24),
      const _Heading('Leadership History'),
      for (final year in data.history.entries)
        Card(
          child: ExpansionTile(
            initiallyExpanded: year.key == data.history.keys.first,
            title: Text('SSITE Officers A.Y. ${year.key}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: _Officers(officers: year.value),
              ),
            ],
          ),
        ),
    ],
    const SizedBox(height: 24),
    const _Heading('Terms & Privacy'),
    const Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text('Acceptable use'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Use SSITE and its materials for their intended school and organization purposes. Respect authorship and document restrictions. Publishing and administrative tools are limited to assigned roles.',
            ),
          ),
        ],
      ),
    ),
    const Card(
      child: ExpansionTile(
        title: Text('Terms of service'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Keep your account secure and sign out on shared devices. Report incorrect content or account concerns to ssite@gmail.com.',
            ),
          ),
        ],
      ),
    ),
    const Card(
      child: ExpansionTile(
        title: Text('Privacy policy'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'SSITE uses your name, school email, and Microsoft account identifier to identify your account. Microsoft handles your Microsoft password. You can manage your photo and account details through profile settings.',
            ),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _filters() => [
    OverlayPortal.overlayChildLayoutBuilder(
      controller: _suggestionOverlay,
      overlayChildBuilder: _buildSearchSuggestions,
      child: TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        onTap: () {
          if (!_suggestionOverlay.isShowing) _suggest(_search.text);
        },
        onChanged: _suggest,
        onSubmitted: (_) => _submitSuggestion(),
        onTapOutside: (_) => _dismissSuggestions(),
        decoration: InputDecoration(
          hintText: switch (widget.kind) {
            'documents' => 'Search document titles',
            'liquidations' => 'Search reports...',
            _ => 'Title or description',
          },
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _search,
            builder: (context, value, child) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _search.clear();
                      _submitSuggestion();
                    },
                  ),
                IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.search),
                  onPressed: _submitSuggestion,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    const SizedBox(height: 16),
    Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _openFilters,
        icon: const Icon(Icons.tune, size: 18),
        label: Text(_filterCount == 0 ? 'Filters' : 'Filters ($_filterCount)'),
      ),
    ),
    const SizedBox(height: 24),
    if (_appliedQuery.isNotEmpty || _filterCount > 0)
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            _search.clear();
            _category = _semester = _academicYear = _period = _event =
                _reportYear = '';
            _module = 'all';
            _sort = 'recent';
            reload();
          },
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Clear search and filters'),
        ),
      ),
  ];

  int get _filterCount =>
      _feedFilters.length +
      (_module == 'all' ? 0 : 1) +
      (_sort == 'recent' ? 0 : 1);

  Future<void> _openFilters() async {
    _dismissSuggestions();
    FocusScope.of(context).unfocus();
    final draft = {'type': _module, 'sort': _sort, ..._feedFilters};
    final discover = widget.kind == 'discover';
    final reports = widget.kind == 'liquidations';
    Map<String, String> options(String key, String first) => {
      '': first,
      for (final v in _filterOptions[key] ?? <String>[]) v: v,
    };
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, redraw) {
          Widget field(String label, String key, Map<String, String> values) =>
              _filter(
                label,
                draft[key] ?? '',
                values,
                (value) => redraw(() {
                  if (key == 'type' && draft[key] != value)
                    draft.remove('category');
                  draft[key] = value;
                }),
              );
          return AlertDialog(
            title: const Text('Filter by'),
            scrollable: true,
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (discover)
                    field('Content type', 'type', const {
                      'all': 'All content',
                      'articles': 'Articles',
                      'activities': 'Activities',
                      'achievements': 'Achievements',
                    }),
                  if (reports)
                    field(
                      'Event name',
                      'event',
                      options('event', 'All events'),
                    ),
                  if (discover &&
                      draft['type'] == _module &&
                      _module != 'all' &&
                      options('category', '').length > 1)
                    field(
                      'Category',
                      'category',
                      options('category', 'All categories'),
                    ),
                  if (discover)
                    field('Date added', 'period', const {
                      '': 'Any time',
                      'week': 'Last 7 days',
                      'month': 'Last 30 days',
                      'year': 'Last year',
                    }),
                  field('Sort by', 'sort', {
                    'recent': 'Newest added',
                    'oldest': 'Oldest added',
                    'title': 'Title (A to Z)',
                    if (reports) ...{
                      'report_soonest': 'Report date (oldest first)',
                      'report_latest': 'Report date (newest first)',
                      if (_api.supportsWebsite) ...{
                        'amount_high': 'Amount (high to low)',
                        'amount_low': 'Amount (low to high)',
                      },
                    },
                  }),
                  if (reports)
                    field(
                      'Report year',
                      'year',
                      options('year', 'All report years'),
                    ),
                  if (widget.kind == 'documents') ...[
                    if (_filterOptions.containsKey('academic_year'))
                      field('Academic year', 'academic_year', {
                        ...options('academic_year', 'All academic years'),
                        'unassigned': 'Not assigned',
                      }),
                    field(
                      'Category',
                      'category',
                      options('category', 'All categories'),
                    ),
                  ],
                  if (!discover)
                    field('Semester', 'semester', const {
                      '': 'All semesters',
                      '1': '1st Semester',
                      '2': '2nd Semester',
                    }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Apply filters'),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || apply != true) return;
    _module = draft['type']!;
    _sort = draft['sort']!;
    _period = draft['period'] ?? '';
    _category = draft['category'] ?? '';
    _semester = draft['semester'] ?? '';
    _academicYear = draft['academic_year'] ?? '';
    _event = draft['event'] ?? '';
    _reportYear = draft['year'] ?? '';
    await reload();
  }

  Widget _filter(
    String label,
    String selected,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$selected'),
      initialValue: options.containsKey(selected)
          ? selected
          : options.keys.first,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, fillColor: Colors.white),
      items: options.entries
          .map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    ),
  );

  List<Widget> _feedContent() {
    final data = _page;
    if (data != null && data.items.isEmpty && widget.kind == 'liquidations')
      return [
        _TransactionTable(
          posts: const [],
          filtered: _filterCount > 0 || _appliedQuery.isNotEmpty,
        ),
      ];
    if (data == null || data.items.isEmpty) {
      return [
        _Empty(
          _appliedQuery.isNotEmpty || _feedFilters.isNotEmpty
              ? 'No matches. Try another keyword or clear your search and filters.'
              : 'No posts have been published yet.',
        ),
      ];
    }
    return [
      if (widget.kind == 'liquidations')
        _TransactionTable(posts: data.items)
      else if (widget.kind == 'discover') ...[
        for (final post in data.items)
          _NewsCard(post: post, imageFirst: true, excerpt: true),
      ] else
        for (final post in data.items)
          if (widget.kind == 'documents')
            _DocumentTile(post: post)
          else
            CmsPostCard(post: post),
      if (data.hasMore)
        Center(
          child: OutlinedButton(
            onPressed: _loadingMore ? null : _more,
            child: Text(_loadingMore ? 'Loading…' : 'Load more'),
          ),
        ),
    ];
  }
}
