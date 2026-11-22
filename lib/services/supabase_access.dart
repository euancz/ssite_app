part of 'cms_api.dart';

const projectUrl = String.fromEnvironment(
  'SSITE_SUPABASE_URL',
  defaultValue: 'https://olohkttykytclqfuenrp.supabase.co',
);
const publishableKey = String.fromEnvironment(
  'SSITE_SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_PS-6ehrZVem6m-9wumRaTQ_X_1tggMO',
);
const _publicBucket = String.fromEnvironment(
  'SSITE_PUBLIC_BUCKET',
  defaultValue: 'ssite-public',
);
const _privateBucket = String.fromEnvironment(
  'SSITE_PRIVATE_BUCKET',
  defaultValue: 'ssite-private',
);
String get cmsApiBaseUrl => '$projectUrl/rest/v1/rpc';
String resolveCmsImageUrl(String value) => value;
String _storageUrl(String key, bool private) {
  final path = key.split('/').map(Uri.encodeComponent).join('/');
  return '$projectUrl/storage/v1/object/${private ? 'authenticated' : 'public'}/${private ? _privateBucket : _publicBucket}/$path';
}

String? _photo(dynamic path) {
  if (path is! String || path.isEmpty) return null;
  final uri = Uri.tryParse(path);
  if (uri != null && ['http', 'https'].contains(uri.scheme)) return path;
  return _storageUrl(path, false);
}

String? _attachment(String m, _Row r) {
  final key = r[_pdf(m) ? 'file_path' : 'image'];
  if (key is! String || key.isEmpty) return null;
  return _storageUrl(key, _pdf(m) || key.startsWith('post-media/'));
}

void _decoratePost(_Row post) {
  final m = post['module'] as String?;
  if (m == null) return;
  if (post['file_path'] != null) post['file_url'] = _attachment(m, post);
  if (post['image'] != null) post['image_url'] = _attachment(m, post);
  if (post['content_html'] == null) {
    final body = (post['content'] ?? post['description'] ?? '').toString();
    post['content_html'] = post['content_format'] == 'markdown'
        ? md.markdownToHtml(
            body,
            extensionSet: md.ExtensionSet.gitHubFlavored,
            encodeHtml: true,
          )
        : '<p>${const HtmlEscape().convert(body).replaceAll('\n', '<br>')}</p>';
  }
}

extension HostedAccess on CmsApi {
  Future<void> linkMicrosoft(String providerToken) async {
    await _rpc('ssite_app_link', {'provider_token': providerToken});
  }

  Future<void> cleanRetiredFiles() async {
    final storage = Supabase.instance.client.storage;
    final response = await _rpc('ssite_app_write', {
      'route': 'files/cleanup',
      'body': {},
    });
    for (final v in _rows(response['files'])) {
      await storage.from(v['bucket']).remove([v['path']]);
    }
  }

  Future<_Row> _upload(String path, _Row body) async {
    final fields = Map<String, dynamic>.from(body);
    var file = fields.remove('attachment') as _Row?;
    final storage = Supabase.instance.client.storage;
    if (file == null &&
        fields['as_draft'] != true &&
        fields['draft_id'] != null &&
        path.endsWith('/save')) {
      final m = path.split('/')[2];
      final draft = await _get('tools/content/$m/draft/${fields['draft_id']}');
      final old = draft['draft']?['payload']?['attachment'];
      if (old != null) {
        final bytes = await storage.from(_privateBucket).download(old['path']);
        file = {'name': old['original_name'], 'data': base64Encode(bytes)};
      }
    }
    if (file == null) return fields;
    var bytes = base64Decode(file['data']);
    var name = file['name'].toString();
    if (!name.toLowerCase().endsWith('.pdf')) {
      final decoder = img.findDecoderForData(bytes);
      if (decoder is! img.JpegDecoder && decoder is! img.PngDecoder)
        throw const FormatException('Choose a JPEG or PNG.');
      final info = decoder!.startDecode(bytes);
      if (info == null ||
          info.width * info.height > 16000000 ||
          path.startsWith('tools/sponsors/') &&
              (info.width > 6000 || info.height > 6000))
        throw const FormatException('Image dimensions exceed the limit.');
      final frame = decoder.decodeFrame(0);
      if (frame == null) throw const FormatException('Unreadable image.');
      bytes = img.encodeJpg(img.bakeOrientation(frame));
      name = 'profile-or-post.jpg';
    }
    final ticket = await _rpc('ssite_app_write', {
      'route': 'prepare/$path',
      'body': {
        'as_draft': fields['as_draft'] == true,
        'attachment': {'name': name, 'data': base64Encode(bytes)},
      },
    });
    await storage
        .from(ticket['bucket'])
        .uploadBinary(
          ticket['path'],
          bytes,
          fileOptions: FileOptions(contentType: ticket['mime']),
        );
    fields['upload_path'] = ticket['path'];
    return fields;
  }
}
