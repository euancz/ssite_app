part of 'server.dart';

extension Media on MobileServer {
  String? photo(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri != null && ['https', 'http'].contains(uri.scheme)) return value;
    final publicUrl = cfg['SUPABASE_PUBLIC_URL'];
    if (cfg['MEDIA_STORAGE'] == 'supabase' && publicUrl != null)
      return '${publicUrl.replaceFirst(RegExp(r'/$'), '')}/$value';
    return '$origin$api/photos/$value';
  }

  Future<Uint8List> object(
    String method,
    String disk,
    String key, [
    Uint8List? data,
  ]) async {
    require(
      ['private', 'public'].contains(disk) &&
          RegExp(r'^[\w-]+(?:/[\w.-]+)+$').hasMatch(key) &&
          !key.split('/').any((v) => v == '..' || v == '.'),
      404,
      'Unknown file.',
    );
    if (cfg['MEDIA_STORAGE'] != 'supabase') {
      final file = File(
        '${cfg['MOBILE_STORAGE_ROOT'] ?? 'storage'}/$disk/$key',
      );
      if (method == 'GET') {
        require(await file.exists(), 404, 'File unavailable.');
        return file.readAsBytes();
      }
      if (method == 'PUT') {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!);
      } else if (await file.exists()) {
        await file.delete();
      }
      return Uint8List(0);
    }
    final endpoint = Uri.parse(cfg['SUPABASE_S3_ENDPOINT']!),
        bucket = disk == 'private'
            ? (cfg['SUPABASE_PRIVATE_BUCKET'] ?? 'ssite-private')
            : (cfg['SUPABASE_PUBLIC_BUCKET'] ?? 'ssite-public');
    final req = AWSHttpRequest(
      method: AWSHttpMethod.values.byName(method.toLowerCase()),
      uri: endpoint.replace(
        path: '${endpoint.path.replaceFirst(RegExp(r'/$'), '')}/$bucket/$key',
      ),
      body: data,
    );
    final signer = AWSSigV4Signer(
      credentialsProvider: AWSCredentialsProvider(
        AWSCredentials(
          cfg['SUPABASE_S3_ACCESS_KEY_ID']!,
          cfg['SUPABASE_S3_SECRET_ACCESS_KEY']!,
        ),
      ),
    );
    final signed = await signer.sign(
      req,
      credentialScope: AWSCredentialScope(
        region: cfg['SUPABASE_S3_REGION']!,
        service: AWSService.s3,
      ),
      serviceConfiguration: S3ServiceConfiguration(),
    );
    final response = await signed.send().response.timeout(
      const Duration(seconds: 30),
    );
    require(
      response.statusCode >= 200 && response.statusCode < 300,
      response.statusCode == 404 ? 404 : 502,
      'Storage request failed.',
    );
    return Uint8List.fromList(await response.body.expand((v) => v).toList());
  }

  Future<void> retirePublicPhoto(String folder, Object? key) async {
    if (key is! String || !key.startsWith('$folder/')) return;
    try {
      final used = await one(
        db,
        'select exists(select 1 from users where profile_picture=?1 union all select 1 from officer_terms where photo=?1 union all select 1 from sponsors where logo_path=?1) as used',
        [key],
      );
      if (used?['used'] == false) await object('DELETE', 'public', key);
    } catch (_) {
      stderr.writeln('Obsolete public photo requires cleanup.');
    }
  }

  Future<Row> storeUpload(
    Row b,
    String folder,
    String disk, {
    bool isPdf = false,
  }) async {
    final a = b['attachment'];
    require(a is Map && a['data'] is String, 422, 'Choose an attachment.');
    var bytes = base64Decode(a['data']);
    require(
      bytes.isNotEmpty &&
          bytes.length <=
              (isPdf
                  ? int.parse(cfg['SCHOOL_MAX_PDF_SIZE_KB'] ?? '10240') * 1024
                  : 2097152),
      422,
      'Attachment exceeds the size limit.',
    );
    if (isPdf) {
      require(
        bytes.length > 5 &&
            ascii.decode(bytes.sublist(0, 5), allowInvalid: true) == '%PDF-' &&
            a['name'].toString().toLowerCase().endsWith('.pdf'),
        422,
        'Choose a valid PDF.',
      );
    } else {
      final decoder = image.findDecoderForData(bytes);
      require(
        decoder is image.JpegDecoder || decoder is image.PngDecoder,
        422,
        'Choose a JPEG or PNG.',
      );
      final info = decoder!.startDecode(bytes);
      require(
        info != null &&
            info.width * info.height <= 16000000 &&
            (folder != 'sponsor-logos' ||
                info.width <= 6000 && info.height <= 6000),
        422,
        'Image dimensions exceed the limit.',
      );
      final img = decoder.decodeFrame(0);
      require(img != null, 422, 'Unreadable image.');
      bytes = image.encodeJpg(image.bakeOrientation(img!));
    }
    final key = '$folder/${token(20)}.${isPdf ? 'pdf' : 'jpg'}';
    await object('PUT', disk, key, bytes);
    return {
      'path': key,
      'type': isPdf ? 'pdf' : 'image',
      'original_name': a['name']
          .toString()
          .split(RegExp(r'[/\\]'))
          .last
          .replaceAll(RegExp(r'[\x00-\x1f"]'), '')
          .substringBeforeLimit(255),
      'size': bytes.length,
    };
  }

  Future<void> serveObject(HttpRequest req, String disk, String key) async {
    final bytes = await object('GET', disk, key), res = req.response;
    final ext = key.split('.').last.toLowerCase();
    final types = {
      'pdf': 'application/pdf',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'webp': 'image/webp',
    };
    require(types.containsKey(ext), 404, 'Unknown file.');
    res.headers.contentType = ContentType.parse(types[ext]!);
    res.headers.set('Accept-Ranges', 'bytes');
    var start = 0, end = bytes.length - 1;
    final range = req.headers.value('range');
    if (range != null) {
      final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
      require(
        match != null && (match[1]!.isNotEmpty || match[2]!.isNotEmpty),
        416,
        'Invalid byte range.',
      );
      if (match![1]!.isEmpty) {
        start = max(0, bytes.length - int.parse(match[2]!));
      } else {
        start = int.parse(match[1]!);
        if (match[2]!.isNotEmpty) end = min(end, int.parse(match[2]!));
      }
      require(start <= end, 416, 'Invalid byte range.');
      res.statusCode = 206;
      res.headers.set('Content-Range', 'bytes $start-$end/${bytes.length}');
    }
    res.contentLength = end - start + 1;
    res.add(Uint8List.sublistView(bytes, start, end + 1));
  }
}

extension on String {
  String substringBeforeLimit(int n) => length <= n ? this : substring(0, n);
}
