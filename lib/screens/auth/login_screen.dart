import 'package:flutter/material.dart';

import '../../app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.errorMessage,
    required this.onSignIn,
    this.onPolicies,
  });
  final String? errorMessage;
  final Future<void> Function() onSignIn;
  final VoidCallback? onPolicies;

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
      await widget.onSignIn();
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
    backgroundColor: const Color(0xFFEDF7FB),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width <= 380 ? 16 : 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/ssite_logo_cropped.png',
                      width: 40,
                      height: 40,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'SSITE at Mabalacat City College',
                        style: TextStyle(
                          color: navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: const Text.rich(
                    TextSpan(
                      text: 'Campus life.\n',
                      children: [
                        TextSpan(
                          text: 'Closer to you.',
                          style: TextStyle(color: Color(0xFF155571)),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 42,
                      letterSpacing: -1.8,
                      height: 1.08,
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'News, activities, and resources for the SSITE community at Mabalacat City College.',
                  style: TextStyle(color: muted, fontSize: 16, height: 1.6),
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
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 54),
                  child: OutlinedButton.icon(
                    onPressed: _openingSignIn ? null : _signInWithMicrosoft,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: navy,
                      side: const BorderSide(color: Color(0xFFA4B9C4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: _openingSignIn
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: navy,
                            ),
                          )
                        : const _MicrosoftMark(),
                    label: const Text(
                      'Sign in with Microsoft',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Use your MCC Microsoft account to get started.',
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 28),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: navy),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(color: navy, offset: Offset(4, 4)),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _LoginGridPainter(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Student Society in Information Technology Education',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Image.asset(
                            'assets/images/rawri-26-27-community.jpg',
                            height: 190,
                            fit: BoxFit.contain,
                            semanticLabel: 'SSITE wolf mascot in a hoodie',
                          ),
                          const Divider(),
                          const Text(
                            'Different minds. One pack.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (widget.onPolicies != null)
                  TextButton(
                    onPressed: widget.onPolicies,
                    child: const Text('Terms of Service and Privacy Policy'),
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
