import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'workspace_screen.dart';
import 'package:pdfrx/pdfrx.dart';

import '../app_theme.dart';
import '../services/cms_api.dart';
import '../widgets/cms_hero.dart';
import '../widgets/cms_navigation.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.onSignOut, this.api});
  final VoidCallback onSignOut;
  final CmsApi? api;
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;
  bool _canAccessWorkspace = false;
  bool _openingWorkspace = false;
  late final _api = widget.api ?? CmsApi.instance;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    try {
      final user = await _api.currentUser();
      if (mounted) {
        setState(
          () => _canAccessWorkspace = user['can_access_workspace'] == true,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _canAccessWorkspace = false);
    }
  }

  Future<void> _openWorkspace() async {
    if (_openingWorkspace) return;
    setState(() => _openingWorkspace = true);
    try {
      final uri = await _api.openWorkspaceSession();
      if (!mounted) return;
      if (!kIsWeb &&
          [
            TargetPlatform.android,
            TargetPlatform.iOS,
            TargetPlatform.macOS,
          ].contains(defaultTargetPlatform)) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => WorkspaceScreen(uri: uri)),
        );
      } else {
        if (!await launchUrl(uri, webOnlyWindowName: '_self')) {
          throw StateError('Could not open workspace');
        }
      }
    } catch (_) {
      await _loadAccount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Workspace could not be opened. Check your connection and account access, then try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingWorkspace = false);
    }
  }

  final _keys = List.generate(5, (_) => GlobalKey<_CmsPageState>());
  void _select(int index) => setState(() => _tab = index);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 768;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset(
              'assets/images/ssite_logo_cropped.png',
              width: 40,
              height: 40,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      constraints.maxWidth < 240
                          ? 'SSITE'
                          : 'STUDENT SOCIETY IN INFORMATION\nTECHNOLOGY EDUCATION',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: constraints.maxWidth < 240 ? 18 : 13,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const Text(
                      'Mabalacat City College',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (_canAccessWorkspace)
            IconButton(
              tooltip: 'Workspace',
              onPressed: _openingWorkspace ? null : _openWorkspace,
              icon: _openingWorkspace
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.dashboard_outlined),
            ),
          PopupMenuButton<String>(
            tooltip: 'Account options',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'workspace') {
                _openWorkspace();
              } else if (value == 'refresh') {
                _keys[_tab].currentState?.reload();
                _loadAccount();
              } else {
                widget.onSignOut();
              }
            },
            itemBuilder: (_) => [
              if (_canAccessWorkspace)
                const PopupMenuItem(
                  value: 'workspace',
                  child: Text('Workspace'),
                ),
              const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
              const PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
        bottom: compact
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(80),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: CmsNavigation(
                    selectedIndex: _tab,
                    onSelect: _select,
                    compact: false,
                  ),
                ),
              ),
      ),
      body: CustomPaint(
        painter: const _GridPainter(),
        child: SafeArea(
          top: false,
          child: IndexedStack(
            index: _tab,
            children: [
              CmsPage(
                key: _keys[0],
                kind: 'home',
                onSelect: _select,
                api: widget.api,
              ),
              CmsPage(
                key: _keys[1],
                kind: 'discover',
                onSelect: _select,
                api: widget.api,
              ),
              CmsPage(
                key: _keys[2],
                kind: 'liquidations',
                onSelect: _select,
                api: widget.api,
              ),
              CmsPage(
                key: _keys[3],
                kind: 'documents',
                onSelect: _select,
                api: widget.api,
              ),
              CmsPage(
                key: _keys[4],
                kind: 'about',
                onSelect: _select,
                api: widget.api,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: compact
          ? CmsNavigation(selectedIndex: _tab, onSelect: _select)
          : null,
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()..color = const Color(0x0617324D);
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), pen);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), pen);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

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
  bool _introExpanded = false;
  String _module = 'articles';
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
    _search.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    final request = ++_request;
    setState(() {
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
        final result = await _api.postsPage(
          widget.kind == 'discover' ? _module : widget.kind,
          query: _search.text,
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
        query: _search.text,
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
  ];

  List<Widget> _filters() => [
    if (widget.kind == 'discover') ...[
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final entry in {
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
    TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => reload(),
      decoration: InputDecoration(
        hintText: 'Search title',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.arrow_forward),
          onPressed: reload,
        ),
      ),
    ),
    const SizedBox(height: 16),
    if (widget.kind == 'documents') ...[
      ExpansionTile(
        title: const Text(
          'Filters',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
  ];

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
      return [const _Empty('No published posts match your search.')];
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

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'Poppins',
        color: ink,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
    ),
  );
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.post});
  final CmsPost post;
  @override
  Widget build(BuildContext context) => _Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          post.moduleLabel.toUpperCase(),
          style: const TextStyle(
            color: muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          post.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'By ${post.author} · ${formatCmsDate(post.date)}',
          style: const TextStyle(color: muted, fontSize: 11),
        ),
        TextButton(
          onPressed: () => _openPost(context, post),
          child: const Text('Read More →'),
        ),
        if (post.imageUrl != null) _PostImage(post: post),
      ],
    ),
  );
}

class CmsPostCard extends StatelessWidget {
  const CmsPostCard({super.key, required this.post, this.full = false});
  final CmsPost post;
  final bool full;
  @override
  Widget build(BuildContext context) => _Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFC7ECF9),
              child: Text(
                post.author.isEmpty ? 'FM' : post.author.substring(0, 1),
                style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.author,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (post.authorRole?.isNotEmpty == true)
                    Text(
                      post.authorRole!,
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  Text(
                    '${formatCmsDate(post.createdAt ?? post.date)} · ${post.moduleLabel}',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (post.category?.isNotEmpty == true)
          Text(
            'Category: ${post.category}',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        const SizedBox(height: 4),
        Text(
          post.title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        if (post.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            post.description,
            maxLines: full ? null : 3,
            overflow: full ? null : TextOverflow.ellipsis,
            style: const TextStyle(color: muted, fontSize: 14, height: 1.65),
          ),
        ],
        if (post.imageUrl != null) ...[
          const SizedBox(height: 14),
          _PostImage(post: post),
        ],
        if (post.location?.isNotEmpty == true)
          _Meta(icon: Icons.location_on_outlined, text: post.location!),
        if (post.awardee?.isNotEmpty == true)
          _Meta(icon: Icons.emoji_events_outlined, text: post.awardee!),
        if (post.amount != null)
          _Meta(icon: Icons.payments_outlined, text: 'PHP ${post.amount}'),
        if (post.academicYear?.isNotEmpty == true)
          _Meta(icon: Icons.school_outlined, text: 'A.Y. ${post.academicYear}'),
        if (post.semester?.isNotEmpty == true)
          _Meta(
            icon: Icons.calendar_month_outlined,
            text: 'Semester ${post.semester}',
          ),
        if (post.fileUrl != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('View PDF'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(post.title)),
                  body: PdfViewer.uri(
                    Uri.parse(post.fileUrl!),
                    headers: CmsApi.instance.headersForUrl(post.fileUrl!),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Divider(color: line),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          children: [
            if (!full)
              TextButton(
                onPressed: () => _openPost(context, post),
                child: const Text('Read full post'),
              ),
            if (post.url != null)
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: post.url!));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied')),
                    );
                  }
                },
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Copy link'),
              ),
          ],
        ),
      ],
    ),
  );
}

void _openPost(BuildContext context, CmsPost post) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(post.moduleLabel)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 864),
                child: CmsPostCard(post: post, full: true),
              ),
            ),
          ),
        ),
      ),
    );

class _PostImage extends StatelessWidget {
  const _PostImage({required this.post});
  final CmsPost post;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 5,
                child: _image(BoxFit.contain),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 8,
              child: IconButton.filledTonal(
                tooltip: 'Close image',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(aspectRatio: 16 / 9, child: _image(BoxFit.cover)),
    ),
  );
  Widget _image(BoxFit fit) => Image.network(
    post.imageUrl!,
    width: double.infinity,
    fit: fit,
    headers: CmsApi.instance.headersForUrl(post.imageUrl!),
    loadingBuilder: (_, child, progress) => progress == null
        ? child
        : const Center(child: CircularProgressIndicator()),
    errorBuilder: (_, _, _) => const ColoredBox(
      color: Color(0xFFE5EFF4),
      child: Center(child: Icon(Icons.broken_image_outlined, color: muted)),
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: muted, fontSize: 12)),
        ),
      ],
    ),
  );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: line),
    ),
    child: child,
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.text});
  final String title, text;
  @override
  Widget build(BuildContext context) => _Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(title),
        Text(
          text,
          style: const TextStyle(color: muted, height: 1.65, fontSize: 14),
        ),
      ],
    ),
  );
}

class _Officers extends StatelessWidget {
  const _Officers({required this.officers});
  final List<CmsOfficer> officers;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 650
          ? 3
          : constraints.maxWidth >= 320
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final officer in officers)
            SizedBox(
              width: width,
              child: _Surface(
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: officer.photoUrl == null
                          ? const ColoredBox(
                              color: Color(0xFFC7ECF9),
                              child: Icon(
                                Icons.person_outline,
                                size: 48,
                                color: navy,
                              ),
                            )
                          : Image.network(
                              officer.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.person_outline,
                                size: 48,
                                color: navy,
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      officer.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      officer.position,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: muted, fontSize: 13),
    ),
  );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_outlined, size: 40, color: muted),
        const SizedBox(height: 12),
        Text(
          error is CmsUnauthorized
              ? 'Your session has expired. Sign out and sign in again.'
              : 'Cannot reach the SSITE CMS.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Check your connection and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

String formatCmsDate(String? value) {
  final date = DateTime.tryParse(value ?? '');
  if (date == null) return '';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.post});
  final CmsPost post;
  @override
  Widget build(BuildContext context) => _Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: Color(0xFF155571),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.category?.isNotEmpty == true) ...[
                    Text(
                      post.category!,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    post.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            if (post.academicYear?.isNotEmpty == true)
              Text(
                'A.Y. ${post.academicYear}',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            if (post.semester?.isNotEmpty == true)
              Text(
                'Semester ${post.semester}',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            if (post.createdAt?.isNotEmpty == true)
              Text(
                formatCmsDate(post.createdAt),
                style: const TextStyle(fontSize: 12, color: muted),
              ),
          ],
        ),
        if (post.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            post.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: muted),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: post.fileUrl != null
              ? TextButton.icon(
                  onPressed: () => _openPdf(context, post),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('View PDF'),
                )
              : TextButton(
                  onPressed: () => _openPost(context, post),
                  child: const Text('View document'),
                ),
        ),
      ],
    ),
  );
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.post});
  final CmsPost post;
  @override
  Widget build(BuildContext context) => _Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(post.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            if (post.date?.isNotEmpty == true)
              Text(
                formatCmsDate(post.date),
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            Text(
              'PHP ${post.amount ?? '—'}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _openPost(context, post),
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: const Text('View report'),
        ),
      ],
    ),
  );
}

class _TransactionTable extends StatelessWidget {
  const _TransactionTable({required this.posts});
  final List<CmsPost> posts;
  @override
  Widget build(BuildContext context) => MediaQuery.sizeOf(context).width < 600
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final post in posts) _TransactionCard(post: post)],
        )
      : _Surface(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columnSpacing: 24,
                  horizontalMargin: 0,
                  headingRowColor: const WidgetStatePropertyAll(
                    Color(0xFFC7ECF9),
                  ),
                  columns: const [
                    DataColumn(label: Text('Event title')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Amount')),
                  ],
                  rows: [
                    for (final post in posts)
                      DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 180,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  alignment: Alignment.centerLeft,
                                ),
                                onPressed: () => _openPost(context, post),
                                icon: const Icon(
                                  Icons.description_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  post.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              formatCmsDate(post.date),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              'PHP ${post.amount ?? '—'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
}

void _openPdf(BuildContext context, CmsPost post) {
  if (post.fileUrl == null) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(post.title)),
        body: PdfViewer.uri(
          Uri.parse(post.fileUrl!),
          headers: CmsApi.instance.headersForUrl(post.fileUrl!),
        ),
      ),
    ),
  );
}
