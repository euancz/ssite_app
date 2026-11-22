import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdfrx/pdfrx.dart';
import '../services/cms_api.dart';
import '../app_theme.dart';

typedef _Data = Map<String, dynamic>;

class AccountTools extends StatefulWidget {
  const AccountTools({
    super.key,
    required this.api,
    required this.path,
    required this.onUnauthorized,
    this.onCompleted,
  });
  final CmsApi api;
  final String path;
  final VoidCallback onUnauthorized;
  final VoidCallback? onCompleted;
  @override
  State<AccountTools> createState() => _AccountToolsState();
}

class _AccountToolsState extends State<AccountTools> {
  late String path = widget.path;
  final history = <String>[];
  late Future<_Data> page = load();
  final filters = <String, String>{};
  Future<_Data> load() async {
    if (path == 'onboarding') {
      final policies = await widget.api.policyText();
      return {
        'title': 'Complete your profile',
        'items': [
          {'title': 'Terms of service and privacy policy', 'detail': policies},
          {
            'title': 'Complete profile',
            'submit': 'profile/complete',
            'fields': [
              {'key': 'attachment', 'type': 'image'},
              {
                'key': 'accept',
                'type': 'check',
                'label': 'I accept the terms and privacy policy',
              },
            ],
          },
        ],
      };
    }
    try {
      return await widget.api.toolPage(path, filters);
    } on CmsUnauthorized {
      widget.onUnauthorized();
      rethrow;
    }
  }

  void go(String next, {bool afterWrite = false}) {
    setState(() {
      if (next != path) {
        if (afterWrite && history.contains(next)) {
          history.removeRange(history.indexOf(next), history.length);
        } else if (!afterWrite) {
          history.add(path);
        }
        path = next;
      }
      filters.clear();
      page = load();
    });
  }

  Future<void> submit(String destination, _Data values) async {
    final submittedPage = page;
    final result = await widget.api.sendAction(
      destination == 'profile/complete' ? destination : 'tools/$destination',
      values,
    );
    if (!mounted || page != submittedPage) return;
    if (path == 'onboarding') {
      widget.onCompleted?.call();
      return;
    }
    go(result['back'] as String? ?? path, afterWrite: true);
  }

  void attachment(_Data row) {
    final url = resolveCmsImageUrl(row['file']);
    final headers = widget.api.headersForUrl(url);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(row['title'])),
          body: row['pdf'] == true
              ? PdfViewer.uri(Uri.parse(url), headers: headers)
              : Center(
                  child: InteractiveViewer(
                    child: Image.network(url, headers: headers),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> editFilters(List<_Data> controls) async {
    final draft = {
      for (final f in controls)
        f['key'] as String: (filters[f['key']] ?? f['value'] ?? '').toString(),
    };
    final applied = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filters', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final f in controls)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: draft[f['key']],
                  decoration: InputDecoration(labelText: _fieldLabel(f)),
                  items: [
                    for (final choice in (f['choices'] as List).cast<String>())
                      DropdownMenuItem(
                        value: choice,
                        child: Text(choice.isEmpty ? 'All' : choice),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) draft[f['key']] = v;
                  },
                ),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    );
    if (mounted && applied == true) {
      setState(() {
        filters.addAll(draft);
        page = load();
      });
    }
  }

  final pendingActions = <String>{};
  Future<void> notificationAction(_Data action) async {
    final route = action['submit'] as String;
    if (!pendingActions.add(route)) return;
    try {
      if (route.endsWith('/delete') &&
          !await _confirmDelete(context, action['title'])) {
        return;
      }
      if (mounted) await submit(route, {});
    } on CmsUnauthorized {
      if (mounted) widget.onUnauthorized();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      pendingActions.remove(route);
    }
  }

  Widget toolRow(_Data row) {
    if (row['submit'] != null) {
      return _ActionForm(
        key: ValueKey('$path/${row['submit']}/${page.hashCode}'),
        action: row,
        submit: submit,
        onUnauthorized: widget.onUnauthorized,
      );
    }
    final String title = row['title']?.toString() ?? '';
    if (row['rows'] case final List children) {
      final rows = children.cast<_Data>();
      final body = Column(
        children: [
          for (final (index, entry) in rows.indexed) ...[
            if (index > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            toolRow(entry),
          ],
        ],
      );
      if (row['collapsed'] == true) {
        return ExpansionTile(
          title: Text(title),
          maintainState: true,
          children: [body],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: body,
          ),
        ],
      );
    }
    final String? target = row['path'];
    if (target != null && (target.endsWith('/new') || target == 'reviews')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FilledButton.icon(
          onPressed: () => go(target),
          icon: Icon(
            target == 'reviews' ? Icons.fact_check_outlined : Icons.add,
          ),
          label: Text(title),
        ),
      );
    }
    final detail = row['detail']?.toString() ?? '';
    if (target == null && row['actions'] == null && detail.length > 200) {
      return ExpansionTile(
        title: Text(title),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [SelectableText(detail)],
      );
    }
    final icon = switch (target) {
      'content/articles' => Icons.article_outlined,
      'content/activities' => Icons.event_outlined,
      'content/achievements' => Icons.emoji_events_outlined,
      'content/documents' => Icons.folder_outlined,
      'content/liquidations' => Icons.receipt_long_outlined,
      'history' => Icons.history,
      'roster' => Icons.groups_outlined,
      'sponsors' => Icons.handshake_outlined,
      'users' => Icons.manage_accounts_outlined,
      _ => null,
    };
    final actions = (row['actions'] as List?)?.cast<_Data>();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: row['image'] != null
          ? CircleAvatar(
              backgroundImage: NetworkImage(
                row['image'],
                headers: widget.api.headersForUrl(row['image']),
              ),
            )
          : icon == null
          ? null
          : Icon(icon, color: const Color(0xff155571)),
      title: Text(title),
      subtitle: detail.isEmpty
          ? null
          : Text(
              detail,
              maxLines: target == null ? null : 2,
              overflow: target == null ? null : TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: muted),
            ),
      trailing: actions != null
          ? PopupMenuButton<_Data>(
              tooltip: 'Notification actions',
              onSelected: notificationAction,
              itemBuilder: (_) => [
                for (final action in actions)
                  PopupMenuItem(value: action, child: Text(action['title'])),
              ],
            )
          : target != null || row['file'] != null
          ? const Icon(Icons.chevron_right, size: 20)
          : null,
      onTap: row['file'] != null
          ? () => attachment(row)
          : target == null
          ? null
          : () => go(target),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: history.isEmpty,
    onPopInvokedWithResult: (popped, _) {
      if (!popped && history.isNotEmpty) {
        go(history.removeLast(), afterWrite: true);
      }
    },
    child: FutureBuilder<_Data>(
      future: page,
      builder: (context, snap) {
        final data = snap.data,
            ready = snap.connectionState == ConnectionState.done;
        return Scaffold(
          appBar: AppBar(
            title: Text(data?['title'] ?? 'SSITE'),
            actions: [
              if (path == 'onboarding')
                TextButton(
                  onPressed: widget.onUnauthorized,
                  child: const Text('Sign out'),
                ),
            ],
            leading: history.isEmpty
                ? null
                : BackButton(
                    onPressed: () => go(history.removeLast(), afterWrite: true),
                  ),
          ),
          body: !ready
              ? const Center(child: CircularProgressIndicator())
              : snap.hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(snap.error.toString()),
                      TextButton(
                        onPressed: () => go(path),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: ListView(
                        key: PageStorageKey(path),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        children: [
                          if (path == 'users' || data?['filters'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: filters['q'] ?? '',
                                      textInputAction: TextInputAction.search,
                                      decoration: const InputDecoration(
                                        hintText: 'Search',
                                        prefixIcon: Icon(Icons.search),
                                      ),
                                      onFieldSubmitted: (v) => setState(() {
                                        filters['q'] = v.trim();
                                        page = load();
                                      }),
                                    ),
                                  ),
                                  if (data?['filters']
                                      case final List controls) ...[
                                    const SizedBox(width: 8),
                                    IconButton.outlined(
                                      tooltip: 'Filters',
                                      isSelected: filters.entries.any(
                                        (e) =>
                                            e.key != 'q' && e.value.isNotEmpty,
                                      ),
                                      onPressed: () =>
                                          editFilters(controls.cast<_Data>()),
                                      icon: const Icon(Icons.tune),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          if ((data!['items'] as List).isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'No records to display.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          for (final row
                              in (data['items'] as List).cast<_Data>())
                            toolRow(row),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    ),
  );
}

String _fieldLabel(_Data f) {
  final label = (f['label'] ?? (f['key'] as String).replaceAll('_', ' '))
      .toString();
  return label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
}

Future<bool> _confirmDelete(BuildContext context, String title) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text('Permanently delete this record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

class _ActionForm extends StatefulWidget {
  const _ActionForm({
    super.key,
    required this.action,
    required this.submit,
    required this.onUnauthorized,
  });
  final _Data action;
  final Future<void> Function(String, _Data) submit;
  final VoidCallback onUnauthorized;
  @override
  State<_ActionForm> createState() => _ActionFormState();
}

class _ActionFormState extends State<_ActionForm> {
  late final _Data fields = {
    for (final f in (widget.action['fields'] as List? ?? []))
      if (!['pdf', 'image'].contains(f['type']))
        f['key']: f['type'] == 'check' ? false : f['value'] ?? '',
  };
  bool busy = false;
  String? error;
  Future<void> send({bool draft = false}) async {
    if (busy) return;
    if (widget.action['title'].toString().toLowerCase().startsWith('delete')) {
      if (!await _confirmDelete(context, widget.action['title']) || !mounted) {
        return;
      }
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.submit(widget.action['submit'], {
        ...fields,
        if (draft) 'as_draft': true,
      });
    } on CmsUnauthorized {
      widget.onUnauthorized();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pick(String key, bool pdf) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: pdf ? ['pdf'] : ['jpg', 'jpeg', 'png'],
      );
      if (files.isEmpty) return;
      final file = files.first;
      if (await file.xFile.length() > (pdf ? 10 : 2) * 1024 * 1024) {
        throw FormatException('Choose a file up to ${pdf ? 10 : 2} MB.');
      }
      final bytes = await file.xFile.readAsBytes();
      if (mounted) {
        setState(
          () => fields[key] = {'name': file.name, 'data': base64Encode(bytes)},
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Widget control(_Data f) {
    final key = f['key'] as String, type = f['type'], label = _fieldLabel(f);
    if (type == 'hidden') return const SizedBox.shrink();
    if (type == 'check') {
      return CheckboxListTile(
        title: Text(label),
        value: fields[key] == true,
        onChanged: (v) => setState(() => fields[key] = v),
      );
    }
    if (type == 'pdf' || type == 'image') {
      return OutlinedButton.icon(
        onPressed: busy ? null : () => pick(key, type == 'pdf'),
        icon: const Icon(Icons.attach_file),
        label: Text(
          fields[key]?['name'] ??
              (type == 'pdf' ? 'Select PDF' : 'Select photo'),
        ),
      );
    }
    final choices = (f['choices'] as List? ?? []).cast<String>();
    if (type == 'ids') {
      return Column(
        children: [
          for (final c in choices)
            CheckboxListTile(
              title: Text(c.split('|').skip(1).join('|')),
              value: (fields[key] as String)
                  .split(',')
                  .contains(c.split('|').first),
              onChanged: (v) => setState(() {
                final selected = (fields[key] as String)
                    .split(',')
                    .where((id) => id.isNotEmpty)
                    .toSet();
                if (v == true) {
                  selected.add(c.split('|').first);
                } else {
                  selected.remove(c.split('|').first);
                }
                fields[key] = selected.join(',');
              }),
            ),
        ],
      );
    }
    if (type == 'select') {
      final ids = choices.map((s) => s.split('|').first);
      return DropdownButtonFormField<String>(
        initialValue: ids.contains(fields[key]) ? fields[key] : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final c in choices)
            DropdownMenuItem(
              value: c.split('|').first,
              child: Text(
                c.contains('|')
                    ? c.substring(c.indexOf('|') + 1)
                    : c.isEmpty
                    ? '—'
                    : c,
              ),
            ),
        ],
        onChanged: (v) => fields[key] = v,
      );
    }
    return TextFormField(
      initialValue: fields[key]?.toString(),
      minLines: type == 'long' ? 3 : 1,
      maxLines: type == 'long' ? 12 : 1,
      decoration: InputDecoration(
        labelText: label,
        hintText: type == 'date' ? 'YYYY-MM-DD' : null,
      ),
      onChanged: (v) => fields[key] = v,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = (widget.action['fields'] as List? ?? [])
        .cast<_Data>()
        .where((f) => f['type'] != 'hidden');
    const secondaryKeys = {
      'content_format',
      'sort_order',
      'is_active',
      'remove_logo',
    };
    final secondary = visible
        .where((f) => secondaryKeys.contains(f['key']))
        .toList();
    Widget input(_Data f) =>
        Padding(padding: const EdgeInsets.only(bottom: 12), child: control(f));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final field in visible.where(
            (f) => !secondaryKeys.contains(f['key']),
          ))
            input(field),
          if (secondary.isNotEmpty)
            ExpansionTile(
              title: const Text('More options'),
              maintainState: true,
              tilePadding: EdgeInsets.zero,
              children: [for (final field in secondary) input(field)],
            ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (widget.action['preview'] == true ||
              widget.action['draft'] == true)
            Wrap(
              spacing: 12,
              children: [
                if (widget.action['preview'] == true)
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (ctx) {
                        final body =
                            (fields['content'] ?? fields['description'] ?? '')
                                .toString();
                        return AlertDialog(
                          title: Text(fields['title'] ?? 'Preview'),
                          content: SingleChildScrollView(
                            child: fields['content_format'] == 'markdown'
                                ? Html(data: md.markdownToHtml(body))
                                : Text(body),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ],
                        );
                      },
                    ),
                    child: const Text('Preview'),
                  ),
                if (widget.action['draft'] == true)
                  OutlinedButton(
                    onPressed: busy ? null : () => send(draft: true),
                    child: const Text('Save draft'),
                  ),
              ],
            ),
          if (widget.action['title'].toString().toLowerCase().startsWith(
            'delete',
          ))
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: busy ? null : () => send(),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(widget.action['title']),
            )
          else
            FilledButton(
              onPressed: busy ? null : () => send(),
              child: Text(widget.action['title']),
            ),
        ],
      ),
    );
  }
}
