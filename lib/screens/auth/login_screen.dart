import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.errorMessage});
  final String? errorMessage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _openingSignIn = false;
  String? _launchError;

  Future<void> _signInWithMicrosoft() async {
    setState(() {
      _openingSignIn = true;
      _launchError = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.azure,
        redirectTo: kIsWeb ? Uri.base.origin : 'ssiteapp://auth/callback',
        scopes: 'email',
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => _launchError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _launchError =
              'Could not open Microsoft sign-in. Check your internet connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _openingSignIn = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: line),
                  ),
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: CustomPaint(painter: _LoginGridPainter()),
                      ),
                      Center(
                        child: Image.asset(
                          'assets/images/rawri-26-27-community.jpg',
                          width: 250,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Welcome to SSITE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in with your Mabalacat City College Microsoft account to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 24),
                if (widget.errorMessage != null || _launchError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _launchError ?? widget.errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFF9B1C1C),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _openingSignIn ? null : _signInWithMicrosoft,
                    style: FilledButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _openingSignIn
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const _MicrosoftMark(),
                    label: const Text(
                      'Continue with Microsoft',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Sign in securely with Microsoft through Supabase.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _LoginGridPainter extends CustomPainter {
  const _LoginGridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x183A9EAE)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MicrosoftMark extends StatelessWidget {
  const _MicrosoftMark();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 18,
    height: 18,
    child: Column(
      children: [
        Row(
          children: [
            _MicrosoftTile(color: Color(0xFFF25022)),
            SizedBox(width: 2),
            _MicrosoftTile(color: Color(0xFF7FBA00)),
          ],
        ),
        SizedBox(height: 2),
        Row(
          children: [
            _MicrosoftTile(color: Color(0xFF00A4EF)),
            SizedBox(width: 2),
            _MicrosoftTile(color: Color(0xFFFFB900)),
          ],
        ),
      ],
    ),
  );
}

class _MicrosoftTile extends StatelessWidget {
  const _MicrosoftTile({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 8, height: 8, child: ColoredBox(color: color));
}
