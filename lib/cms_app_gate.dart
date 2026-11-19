import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/cms_api.dart';
import 'services/cms_browser_callback.dart';

class CmsAppGate extends StatefulWidget {
  const CmsAppGate({super.key});

  @override
  State<CmsAppGate> createState() => _CmsAppGateState();
}

class _CmsAppGateState extends State<CmsAppGate> {
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  final _api = CmsApi.instance;
  final _storageScope = sha256.convert(utf8.encode(cmsApiBaseUrl)).toString();
  String get _sessionKey => 'ssite_cms_session_$_storageScope';
  String get _verifierKey => 'ssite_cms_sign_in_verifier_$_storageScope';
  StreamSubscription<Uri>? _links;
  Uri? _pendingLink;
  bool _loading = true;
  bool _retryRestore = false;
  bool _exchanging = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _links = AppLinks().uriLinkStream.listen((link) {
        if (_loading && !_exchanging) {
          _pendingLink = link;
        } else {
          unawaited(_finishSignIn(link));
        }
      }, onError: (Object _) {});
    }
    unawaited(_restore());
  }

  Future<void> _restore() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _retryRestore = false;
        _error = null;
      });
    }
    try {
      final callback = kIsWeb ? cmsBrowserCallback() : _pendingLink;
      if (callback != null && _callbackCode(callback) != null) {
        _pendingLink = null;
        await _finishSignIn(callback);
        return;
      }
      final token = await _storage.read(key: _sessionKey);
      if (token != null) {
        _api.accessToken = token;
        await _api.currentUser();
      }
    } on CmsUnauthorized {
      _api.accessToken = null;
      try {
        await _storage.delete(key: _sessionKey);
      } catch (_) {
        _error = 'The old session expired. Please sign in again.';
      }
    } catch (_) {
      _api.accessToken = null;
      _retryRestore = true;
    } finally {
      if (mounted) setState(() => _loading = false);
      if (_pendingLink case final link?) {
        _pendingLink = null;
        await _finishSignIn(link);
      }
    }
  }

  Future<void> _startSignIn() async {
    final random = Random.secure();
    final verifier = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _storage.write(key: _verifierKey, value: verifier);
    final url = Uri.parse('$cmsWebBaseUrl/auth/microsoft/mobile').replace(
      queryParameters: {
        'code_challenge': sha256.convert(utf8.encode(verifier)).toString(),
        if (kIsWeb) 'return_url': Uri.base.removeFragment().toString(),
      },
    );
    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_self',
    )) {
      await _storage.delete(key: _verifierKey);
      throw StateError('Could not open Microsoft sign-in.');
    }
  }

  String? _callbackCode(Uri uri) {
    if (kIsWeb) {
      return uri.fragment.startsWith('ssite_code=')
          ? uri.fragment.substring('ssite_code='.length)
          : null;
    }
    return uri.scheme == 'ssiteapp' &&
            uri.host == 'auth' &&
            uri.path == '/callback'
        ? uri.queryParameters['code']
        : null;
  }

  Future<void> _finishSignIn(Uri uri) async {
    final code = _callbackCode(uri);
    if (!mounted ||
        _exchanging ||
        _api.accessToken != null ||
        code == null ||
        !RegExp(r'^[a-zA-Z0-9]{64}$').hasMatch(code)) {
      return;
    }
    _exchanging = true;
    setState(() {
      _loading = true;
      _retryRestore = false;
      _error = null;
    });
    try {
      final verifier = await _storage.read(key: _verifierKey);
      if (verifier == null) throw CmsUnauthorized();
      final token = await _api.exchangeLoginCode(code, verifier);
      await _storage.write(key: _sessionKey, value: token);
      _api.accessToken = token;
    } catch (_) {
      _error = 'Microsoft sign-in could not be completed. Please try again.';
    } finally {
      try {
        await _storage.delete(key: _verifierKey);
      } catch (_) {
        // A new attempt will replace the verifier.
      }
      _exchanging = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    if (_loading) return;
    final token = _api.accessToken;
    setState(() {
      _api.accessToken = null;
      _loading = true;
      _retryRestore = false;
      _error = null;
    });
    try {
      await Future.wait([
        _storage.delete(key: _sessionKey),
        _storage.delete(key: _verifierKey),
      ]);
    } catch (_) {
      _error = 'The saved session could not be cleared.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (token != null) {
      try {
        await _api.revokeSession(token);
      } catch (_) {
        // Local sign-out also works without a connection.
      }
    }
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_retryRestore) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not connect to the SSITE CMS.'),
                  FilledButton(onPressed: _restore, child: const Text('Retry')),
                  TextButton(
                    onPressed: _signOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_api.accessToken != null) return MainScreen(onSignOut: _signOut);
    return LoginScreen(
      errorMessage: _error,
      onSignIn: _startSignIn,
      onPolicies: () => launchUrl(Uri.parse('$cmsWebBaseUrl/policies')),
    );
  }
}
