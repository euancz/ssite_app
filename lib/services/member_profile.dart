import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cms_api.dart' show resolveCmsImageUrl;

class MemberProfile {
  const MemberProfile({
    required this.name,
    this.email,
    this.photoUrl,
    this.photoBytes,
  });

  final String name;
  final String? email;
  final String? photoUrl;
  final Uint8List? photoBytes;

  factory MemberProfile.fromMicrosoft(User user, {Uint8List? photo}) {
    final identity = user.userMetadata ?? {};
    final email = _text(user.email);
    final avatar = _text(identity['avatar_url']) ?? _text(identity['picture']);
    final url = Uri.tryParse(avatar ?? '');
    return MemberProfile(
      name:
          _text(identity['full_name']) ??
          _text(identity['name']) ??
          email?.split('@').first ??
          'SSITE member',
      email: email,
      photoUrl: url != null && url.scheme == 'https' && url.host.isNotEmpty
          ? avatar
          : null,
      photoBytes: photo,
    );
  }

  factory MemberProfile.fromCms(Map<String, dynamic> user) {
    final photo = _text(user['avatar_url']);
    return MemberProfile(
      name: _text(user['name']) ?? 'SSITE member',
      email: _text(user['email']),
      photoUrl: photo == null ? null : resolveCmsImageUrl(photo),
    );
  }

  static String? _text(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }
}

class MicrosoftProfilePhoto {
  MicrosoftProfilePhoto({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  final http.Client _client;
  final FlutterSecureStorage _storage;
  static final _endpoint = Uri.parse(
    r'https://graph.microsoft.com/v1.0/me/photos/96x96/$value',
  );

  Future<Uint8List?> load(Session session) async {
    if (session.user.appMetadata['provider'] != 'azure') return null;
    final key = 'ssite_microsoft_photo_${session.user.id}';
    final token = session.providerToken;
    if (token != null && token.isNotEmpty) {
      try {
        final request = http.Request('GET', _endpoint)
          ..followRedirects = false
          ..headers['Authorization'] = 'Bearer $token';
        final response = await _client
            .send(request)
            .then(http.Response.fromStream)
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 404) {
          await _write(key, null);
          return null;
        }
        if (response.statusCode == 200 &&
            response.headers['content-type']?.startsWith('image/') == true &&
            response.bodyBytes.isNotEmpty &&
            response.bodyBytes.length <= 256 * 1024) {
          await _write(key, base64Encode(response.bodyBytes));
          return response.bodyBytes;
        }
      } on Exception {
        // Keep the last successful photo if Microsoft cannot be reached.
      }
    }

    try {
      final saved = await _storage.read(key: key);
      return saved == null ? null : base64Decode(saved);
    } on Exception {
      return null;
    }
  }

  Future<void> _write(String key, String? value) async {
    try {
      await _storage.write(key: key, value: value);
    } on Exception {
      // The live photo remains usable when secure storage is unavailable.
    }
  }

  void dispose() => _client.close();
}
