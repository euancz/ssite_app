import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/cms_api.dart';
import 'services/browser_sign_in.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  static const _storage = FlutterSecureStorage();
  final _api = CmsApi.instance;
  final _links = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  bool _loading = true;
  bool _signedIn = false;
  bool _handlingCode = false;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    _linkSubscription = _links.uriLinkStream.listen(
      _handleSignInLink,
      onError: (_) => _setLoginError('Could not complete Microsoft sign-in.'),
    );
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final code = takeBrowserSignInCode();
    if (code != null) {
      await _handleSignInLink(Uri(scheme: 'ssiteapp', host: 'auth',
          path: '/callback', queryParameters: {'code': code}));
      return;
    }
    final token = await _storage.read(key: 'mobile_access_token');
    if (token != null) {
      _api.accessToken = token;
      try {
        _signedIn = await _api.validateAccessToken(token);
      } catch (_) {
        // Keep the saved token through temporary CMS outages; protected content
        // requests can retry once the connection is available again.
        _signedIn = true;
      }
      if (!_signedIn) {
        await _storage.delete(key: 'mobile_access_token');
        _api.accessToken = null;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _handleSignInLink(Uri uri) async {
    final code = uri.queryParameters['code'];
    if (uri.scheme != 'ssiteapp' || uri.host != 'auth' || code == null || _handlingCode) return;
    _handlingCode = true;
    setState(() {
      _loading = true;
      _loginError = null;
    });
    try {
      final token = await _api.exchangeLoginCode(code);
      await _storage.write(key: 'mobile_access_token', value: token);
      _api.accessToken = token;
      if (mounted) setState(() { _signedIn = true; _loading = false; });
    } catch (_) {
      _setLoginError('Microsoft sign-in could not be verified. Please try again.');
    } finally {
      _handlingCode = false;
    }
  }

  void _setLoginError(String message) {
    if (mounted) setState(() { _loginError = message; _loading = false; });
  }

  Future<void> _signOut() async {
    try { await _api.revokeAccessToken(); } catch (_) {}
    await _storage.delete(key: 'mobile_access_token');
    _api.accessToken = null;
    if (mounted) setState(() { _signedIn = false; _loginError = null; });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _signedIn
        ? MainScreen(onSignOut: _signOut)
        : LoginScreen(errorMessage: _loginError);
  }
}
