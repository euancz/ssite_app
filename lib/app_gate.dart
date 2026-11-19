import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/member_profile.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  String? _authError;
  final _photos = MicrosoftProfilePhoto();
  Future<Uint8List?>? _photo;
  String? _photoOwner, _photoToken;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _loadPhoto(Supabase.instance.client.auth.currentSession);
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) {
        if (!mounted) return;
        setState(() {
          _authError = null;
          _loadPhoto(state.session);
        });
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

  void _loadPhoto(Session? session) {
    final owner = session?.user.id;
    final token = session?.providerToken;
    if (owner == _photoOwner && (token == null || token == _photoToken)) return;
    _photoOwner = owner;
    _photoToken = token;
    _photo = session == null ? null : _photos.load(session);
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _photos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return session != null
        ? FutureBuilder<Uint8List?>(
            key: ValueKey(session.user.id),
            future: _photo,
            builder: (context, snapshot) => MainScreen(
              onSignOut: _signOut,
              profile: MemberProfile.fromMicrosoft(
                session.user,
                photo: snapshot.data,
              ),
            ),
          )
        : LoginScreen(errorMessage: _authError);
  }
}
