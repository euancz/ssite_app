import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/account_tools.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/cms_api.dart';

class CmsAppGate extends StatefulWidget {
  const CmsAppGate({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<CmsAppGate> createState() => _CmsAppGateState();
}

class _CmsAppGateState extends State<CmsAppGate> {
  final api = CmsApi.instance;
  late final StreamSubscription<AuthState> subscription;
  String? owner, error;
  bool loading = false, needsProfile = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    api.sessionToken = () => widget.client.auth.currentSession?.accessToken;
    subscription = widget.client.auth.onAuthStateChange.listen(
      (state) {
        if (mounted && owner != state.session?.user.id)
          unawaited(restore(state.session));
      },
      onError: (Object e) {
        if (mounted)
          setState(() => error = 'Sign-in expired. Please sign in again.');
      },
    );
    unawaited(restore(widget.client.auth.currentSession));
  }

  Future<void> restore(Session? session) async {
    final run = ++generation;
    setState(() {
      owner = session?.user.id;
      error = null;
      loading = session != null;
      needsProfile = false;
    });
    if (session == null) return;
    try {
      var profile = await api.currentUser();
      if (profile['linked'] != true) {
        final token = session.providerToken;
        if (token == null || token.isEmpty)
          throw const FormatException(
            'Please sign out and sign in again to link your school account.',
          );
        await api.linkMicrosoft(token);
        profile = await api.currentUser();
      }
      if (mounted && run == generation) {
        setState(() => needsProfile = profile['profile_complete'] != true);
        if (!needsProfile)
          unawaited(api.cleanRetiredFiles().catchError((Object _) {}));
      }
    } catch (e) {
      if (mounted && run == generation)
        setState(
          () => error = e is FormatException
              ? e.message
              : 'Could not connect to your school account. Please retry.',
        );
    } finally {
      if (mounted && run == generation) setState(() => loading = false);
    }
  }

  Future<void> signOut() async {
    try {
      await widget.client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      if (!mounted) return;
      if (widget.client.auth.currentSession == null) {
        await restore(null);
        setState(
          () => error =
              'Signed out on this device. Could not confirm sign-out with the server.',
        );
      } else {
        setState(
          () => error =
              'Could not sign out. Check your connection and try again.',
        );
      }
    }
  }

  Future<void> signIn() async {
    final opened = await widget.client.auth.signInWithOAuth(
      OAuthProvider.azure,
      scopes: 'email User.Read',
      queryParams: const {'prompt': 'login'},
      redirectTo: kIsWeb ? Uri.base.origin : 'ssiteapp://auth/callback',
    );
    if (!opened) throw StateError('Browser unavailable.');
  }

  Future<void> policies() async {
    final text = await api.policyText();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms of service and privacy policy'),
        content: SingleChildScrollView(child: Text(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (owner == null)
      return LoginScreen(
        onSignIn: signIn,
        onPolicies: policies,
        errorMessage: error,
      );
    if (error != null)
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!),
                FilledButton(
                  onPressed: () => restore(widget.client.auth.currentSession),
                  child: const Text('Retry'),
                ),
                TextButton(onPressed: signOut, child: const Text('Sign out')),
              ],
            ),
          ),
        ),
      );
    if (needsProfile)
      return AccountTools(
        api: api,
        path: 'onboarding',
        onUnauthorized: signOut,
        onCompleted: () => restore(widget.client.auth.currentSession),
      );
    return MainScreen(key: ValueKey(owner), onSignOut: signOut);
  }
}
