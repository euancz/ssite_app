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
  final _suggestionOverlay = OverlayPortalController();
  Timer? _suggestionTimer;
  int _suggestionRequest = 0;
  List<String> _suggestions = [];
  bool _introExpanded = false;
  String _appliedQuery = '';
  String _module = 'all';
  CmsHome? _discover;
  String _sort = 'recent';
  String _category = '', _semester = '', _academicYear = '';
  Map<String, List<String>> _documentOptions = {};
  Map<String, String> get _documentQuery => widget.kind == 'documents'
      ? {
          if (_category.isNotEmpty) 'category': _category,
          if (_semester.isNotEmpty) 'semester': _semester,
          if (_academicYear.isNotEmpty) 'academic_year': _academicYear,
        }
      : {};
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
        final page = await _api.postsPage(
          widget.kind == 'discover' ? _module : widget.kind,
          query: query,
          sort: _sort,
          filters: _documentQuery,
        );
        if (!mounted || request != _suggestionRequest) return;
        final seen = <String>{};
        setState(() {
          _suggestions = page.items
              .map((post) => post.title.trim())
              .where((title) => title.isNotEmpty && seen.add(title.toLowerCase()))
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
      } else if (widget.kind == 'discover' && _module == 'all') {
        final result = await _api.discover();
        if (mounted && request == _request) setState(() => _discover = result);
      } else if (widget.kind == 'about') {
        final result = await _api.about();
        if (mounted && request == _request) setState(() => _about = result);
      } else {
        final result = await _api.postsPage(
          widget.kind == 'discover' ? _module : widget.kind,
          query: _appliedQuery,
          sort: _sort,
          filters: _documentQuery,
        );
        if (mounted && request == _request) {
          setState(() {
            _page = result;
            _documentOptions = result.filters;
          });
        }
      }
    } catch (error) {
      if (mounted && request == _request) setState(() => _error = error);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _more() async {
    final page = _page;
    if (page == null || !page.hasMore || _loadingMore) return;
    final request = _request;
    setState(() => _loadingMore = true);
    try {
      final next = await _api.postsPage(
        widget.kind == 'discover' ? _module : widget.kind,
        query: _appliedQuery,
        sort: _sort,
        filters: _documentQuery,
        page: page.currentPage + 1,
      );
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
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1045),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: kind == 'home' ? 0 : 20,
                  vertical: kind == 'home' ? 0 : 24,
                ),
                child: CmsHero(name: name, label: title),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 864),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (kind == 'home') ..._intro(),
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
                    else if (kind == 'discover' &&
                        _module == 'all' &&
                        _discover != null)
                      ..._discoverContent(_discover!)
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
          const Center(
            child: Text(
              'SSITE · Mabalacat City College',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _intro() => [
    const SizedBox(height: 20),
    Image.asset(
      'assets/images/rawri-26-27-community.jpg',
      height: 140,
      fit: BoxFit.contain,
    ),
    const SizedBox(height: 16),
    const _Heading('Welcome to the SSITE Community!'),
    Text(
      'Welcome to the official website of the Student Society in Information Technology Education (SSITE) of Mabalacat City College. Stay connected with our latest announcements, activities, articles, and achievements as we bring IT students together through collaboration, innovation, and meaningful experiences.',
      maxLines: _introExpanded ? null : 4,
      overflow: _introExpanded ? null : TextOverflow.ellipsis,
      style: const TextStyle(color: muted, height: 1.7, fontSize: 14),
    ),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => setState(() => _introExpanded = !_introExpanded),
        child: Text(_introExpanded ? 'Show less' : 'Read more about SSITE'),
      ),
    ),
    const SizedBox(height: 28),
  ];

  List<Widget> _homeContent(CmsHome data) => [
    const _Heading("What's New at SSITE"),
    for (final post in [
      ...data.articles,
      ...data.activities,
      ...data.achievements,
    ])
      _NewsCard(post: post),
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
    if (widget.kind == 'discover') ...[
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final entry in {
              'all': 'All',
              'articles': 'Articles',
              'activities': 'Activities',
              'achievements': 'Achievements',
            }.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(entry.value),
                  selected: _module == entry.key,
                  selectedColor: const Color(0xFFC7ECF9),
                  onSelected: (_) {
                    _module = entry.key;
                    reload();
                  },
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
    ],
    if (widget.kind != 'discover' || _module != 'all') ...[
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
            hintText: 'Search title',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _search,
              builder: (context, value, child) => IconButton(
                tooltip: value.text.isEmpty ? 'Search' : 'Clear search',
                icon: Icon(
                  value.text.isEmpty ? Icons.arrow_forward : Icons.close,
                ),
                onPressed: () {
                  _search.clear();
                  reload();
                },
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (widget.kind == 'documents') ...[
        ExpansionTile(
          title: Text(
            _documentQuery.isEmpty
                ? 'Filters'
                : 'Filters (${_documentQuery.length} active)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          leading: const Icon(Icons.tune, size: 20),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
          shape: const Border(),
          collapsedShape: const Border(),
          maintainState: true,
          children: _documentFilters(),
        ),
        const SizedBox(height: 12),
      ],
      Row(
        children: [
          Expanded(
            child: Text(
              widget.kind == 'documents'
                  ? 'Official documents'
                  : widget.kind == 'liquidations'
                  ? 'Transactions'
                  : _module[0].toUpperCase() + _module.substring(1),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          DropdownButton<String>(
            underline: const SizedBox.shrink(),
            value: _sort,
            items: const [
              DropdownMenuItem(
                value: 'recent',
                child: Text('Most recent', style: TextStyle(fontSize: 12)),
              ),
              DropdownMenuItem(
                value: 'oldest',
                child: Text('Oldest', style: TextStyle(fontSize: 12)),
              ),
              DropdownMenuItem(
                value: 'title',
                child: Text('Title (A to Z)', style: TextStyle(fontSize: 12)),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                _sort = value;
                reload();
              }
            },
          ),
        ],
      ),
      const Divider(),
      const SizedBox(height: 8),
      if (_appliedQuery.isNotEmpty || _documentQuery.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              _search.clear();
              _category = _semester = _academicYear = '';
              reload();
            },
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Clear search and filters'),
          ),
        ),
    ],
  ];

  List<Widget> _discoverContent(CmsHome data) {
    final sections = {
      'Articles': data.articles,
      'Activities': data.activities,
      'Achievements': data.achievements,
    };
    int addedAt(CmsPost post) =>
        DateTime.tryParse(
          post.createdAt ?? post.date ?? '',
        )?.millisecondsSinceEpoch ??
        0;

    final stories = [
      for (final posts in sections.values)
        if (posts.isNotEmpty) posts.first,
    ]..sort((a, b) => addedAt(b).compareTo(addedAt(a)));
    return [
      const _Heading('Stories & Highlights'),
      if (stories.isEmpty)
        const _Empty('No published stories yet')
      else ...[
        const Text(
          'Latest story',
          style: TextStyle(color: muted, fontWeight: FontWeight.w600),
        ),
        _NewsCard(post: stories.first),
        for (final section in sections.entries) ...[
          _Heading(section.key),
          if (section.value.isEmpty)
            _Empty('No published ${section.key.toLowerCase()} yet')
          else
            _NewsCard(post: section.value.first),
        ],
      ],
    ];
  }

  List<Widget> _documentFilters() => [
    _filter(
      'Sort By Semester',
      _semester,
      const {'': 'All Semesters', '1': '1st Semester', '2': '2nd Semester'},
      (value) {
        _semester = value;
        reload();
      },
    ),
    _filter(
      'Categories',
      _category,
      {
        '': 'All categories',
        for (final category in _documentOptions['category'] ?? <String>[])
          category: category,
      },
      (value) {
        _category = value;
        reload();
      },
    ),
    if (_documentOptions.containsKey('academic_year'))
      _filter(
        'Academic year',
        _academicYear,
        {
          '': 'All academic years',
          'unassigned': 'Not assigned',
          for (final year in _documentOptions['academic_year'] ?? <String>[])
            year: year,
        },
        (value) {
          _academicYear = value;
          reload();
        },
      ),
  ];

  Widget _filter(
    String label,
    String selected,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$selected'),
      initialValue: options.containsKey(selected) ? selected : '',
      isExpanded: true,
      decoration: InputDecoration(labelText: label, fillColor: Colors.white),
      items: options.entries
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    ),
  );

  List<Widget> _feedContent() {
    final data = _page;
    if (data == null || data.items.isEmpty) {
      return [
        _Empty(
          _appliedQuery.isNotEmpty || _documentQuery.isNotEmpty
              ? 'No matches. Try another keyword or clear your search and filters.'
              : 'No posts have been published yet.',
        ),
      ];
    }
    return [
      Text(
        '${data.total} results',
        style: const TextStyle(color: muted, fontSize: 12),
      ),
      const SizedBox(height: 12),
      if (widget.kind == 'liquidations')
        _TransactionTable(posts: data.items)
      else
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
