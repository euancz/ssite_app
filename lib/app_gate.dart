import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/cms_api.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  final _api = CmsApi.instance;
  String? _authError;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) {
        _api.accessToken = state.session?.accessToken;
        _authError = null;
        if (mounted) setState(() {});
      },
      onError: (Object error) {
        if (mounted) {
          setState(
            () => _authError =
                'Sign-in could not be completed. Please try again.',
          );
        }
      },
    );
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    _api.accessToken = null;
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    _api.accessToken = session?.accessToken;
    return session != null
        ? MainScreen(onSignOut: _signOut)
        : LoginScreen(errorMessage: _authError);
  }
}
