import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdfrx/pdfrx.dart';
import '../services/cms_api.dart';

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
    final result = await widget.api.sendAction(
      destination == 'profile/complete' ? destination : 'tools/$destination',
      values,
    );
    if (!mounted) return;
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
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (path == 'users' || data?['filters'] != null)
                        TextFormField(
                          initialValue: filters['q'] ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Search',
                          ),
                          onFieldSubmitted: (v) => setState(() {
                            filters['q'] = v.trim();
                            page = load();
                          }),
                        ),
                      for (final f
                          in (data?['filters'] as List? ?? []).cast<_Data>())
                        DropdownButtonFormField<String>(
                          initialValue: filters[f['key']] ?? f['value'],
                          decoration: InputDecoration(labelText: f['key']),
                          items: [
                            for (final v
                                in (f['choices'] as List).cast<String>())
                              DropdownMenuItem(
                                value: v,
                                child: Text(v.isEmpty ? 'All' : v),
                              ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                filters[f['key']] = v;
                                page = load();
                              });
                            }
                          },
                        ),
                      if ((data!['items'] as List).isEmpty)
                        const Text('No records to display.'),
                      for (final row in (data['items'] as List).cast<_Data>())
                        if (row['submit'] != null)
                          _ActionForm(
                            key: ValueKey(
                              '$path/${row['submit']}/${page.hashCode}',
                            ),
                            action: row,
                            submit: submit,
                            onUnauthorized: widget.onUnauthorized,
                          )
                        else
                          ListTile(
                            title: Text(row['title'].toString()),
                            subtitle: row['detail'] == null
                                ? null
                                : Text(row['detail'].toString()),
                            leading: row['image'] == null
                                ? null
                                : CircleAvatar(
                                    backgroundImage: NetworkImage(
                                      row['image'],
                                      headers: widget.api.headersForUrl(
                                        row['image'],
                                      ),
                                    ),
                                  ),
                            trailing: row['path'] == null && row['file'] == null
                                ? null
                                : const Icon(Icons.chevron_right),
                            onTap: row['file'] != null
                                ? () => attachment(row)
                                : row['path'] == null
                                ? null
                                : () => go(row['path']),
                          ),
                    ],
                  ),
                ),
        );
      },
    ),
  );
}

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
      if (await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(widget.action['title']),
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
              ) !=
              true ||
          !mounted) {
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
    final key = f['key'] as String,
        type = f['type'],
        label = (f['label'] ?? key.replaceAll('_', ' ')).toString();
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in (widget.action['fields'] as List? ?? []).cast<_Data>())
          Padding(padding: const EdgeInsets.only(bottom: 8), child: control(f)),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (widget.action['preview'] == true)
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) {
                final body = (fields['content'] ?? fields['description'] ?? '')
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
        FilledButton(
          onPressed: busy ? null : () => send(),
          child: Text(widget.action['title']),
        ),
      ],
    ),
  );
}
