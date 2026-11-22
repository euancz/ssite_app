import 'dart:typed_data';

import 'cms_api.dart' show resolveCmsImageUrl;

class MemberProfile {
  const MemberProfile({
    required this.name,
    this.email,
    this.photoUrl,
    this.photoBytes,
    this.canAccessWorkspace = false,
  });

  final String name;
  final bool canAccessWorkspace;
  final String? email;
  final String? photoUrl;
  final Uint8List? photoBytes;

  factory MemberProfile.fromCms(Map<String, dynamic> user) {
    final photo = _text(user['avatar_url']);
    return MemberProfile(
      canAccessWorkspace: user['can_access_workspace'] == true,
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
