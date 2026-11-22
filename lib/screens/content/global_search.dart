part of '../main_screen.dart';

const _searchSections = {
  'articles': 'Articles',
  'activities': 'Activities',
  'achievements': 'Achievements',
  'documents': 'Documents',
  'liquidations': 'Transparency',
  'officers': 'Officers',
};

class _GlobalSearch extends StatefulWidget {
  const _GlobalSearch({required this.api});
  final CmsApi api;

  @override
  State<_GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends State<_GlobalSearch> {
  final _input = TextEditingController();
  String _query = '';
  String? _section;
  Map<String, CmsPostPage> _posts = {};
  List<CmsOfficer> _officers = [];
  int _request = 0;
  bool _loading = false;
  bool _failed = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final request = ++_request;
    final term = query.trim();
    setState(() {
      _query = term;
      _posts = {};
      _officers = [];
      _failed = false;
      _loading = term.runes.length >= 2;
    });
    if (!_loading) return;

    try {
      final aboutRequest = widget.api.about();
      final modules = _searchSections.keys.where((key) => key != 'officers');
      final posts = <String, CmsPostPage>{};
      await Future.wait([
        for (final module in modules)
          widget.api.postsPage(module, query: term).then((result) {
            posts[module] = result;
          }),
        aboutRequest.then((about) {
          if (!mounted || request != _request) return;
          final words = term.toLowerCase().split(RegExp(r'\s+'));
          final officers = <CmsOfficer>[
            ...about.officers,
            ...about.history.values.expand((term) => term),
          ];
          setState(() {
            _officers = officers.where((officer) {
              final text = '${officer.name} ${officer.position}'.toLowerCase();
              return words.every(text.contains);
            }).toList();
          });
        }),
      ]);
      if (mounted && request == _request) setState(() => _posts = posts);
    } catch (_) {
      if (mounted && request == _request) setState(() => _failed = true);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _more(String module, CmsPostPage current) async {
    final request = ++_request;
    setState(() => _loading = true);
    try {
      final next = await widget.api.postsPage(
        module,
        query: _query,
        page: current.currentPage + 1,
      );
      if (!mounted || request != _request) return;
      setState(
        () =>
            _posts[module] = next.withItems([...current.items, ...next.items]),
      );
    } catch (_) {
      if (!mounted || request != _request) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load more results.')),
      );
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = _section == null ? _searchSections.keys : [_section!];
    return Scaffold(
      appBar: AppBar(title: const Text('Search SSITE')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            TextField(
              controller: _input,
              autofocus: true,
              maxLength: 100,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search all content',
                counterText: '',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Submit search',
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    _search(_input.text);
                  },
                ),
              ),
              onSubmitted: _search,
            ),
            const SizedBox(height: 12),
            if (_query.runes.length < 2)
              const Text('Enter at least two characters to search.'),
            if (_loading) const LinearProgressIndicator(),
            if (_failed)
              _Failure(
                error: 'Could not load search results.',
                onRetry: () => _search(_query),
              ),
            if (!_failed && _posts.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                key: ValueKey(_section),
                isExpanded: true,
                initialValue: _section ?? '',
                decoration: const InputDecoration(labelText: 'Result type'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All results')),
                  for (final e in _searchSections.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (value) => setState(
                  () =>
                      _section = value == null || value.isEmpty ? null : value,
                ),
              ),
              const SizedBox(height: 16),
              if (!sections.any(
                (key) => key == 'officers'
                    ? _officers.isNotEmpty
                    : _posts[key]!.items.isNotEmpty,
              ))
                const _Empty('No matching results.'),
              for (final section in sections)
                if (section == 'officers' && _officers.isNotEmpty) ...[
                  const _Heading('Officers'),
                  _Officers(officers: _officers),
                ] else if (_posts[section] case final page?
                    when page.items.isNotEmpty) ...[
                  _Heading(_searchSections[section]!),
                  for (final post
                      in _section == null ? page.items.take(3) : page.items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(post.title),
                      subtitle: post.description.isEmpty
                          ? null
                          : Text(
                              post.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openPost(context, post),
                    ),
                  if (_section == null && page.total > 3)
                    TextButton(
                      onPressed: () => setState(() => _section = section),
                      child: Text('View all ${page.total} results'),
                    ),
                  if (_section != null && page.hasMore)
                    OutlinedButton(
                      onPressed: _loading ? null : () => _more(section, page),
                      child: const Text('Load more'),
                    ),
                ],
            ],
          ],
        ),
      ),
    );
  }
}
