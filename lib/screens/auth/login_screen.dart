import 'package:flutter/material.dart';

import '../main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool _hidePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    debugPrint('Email: $email');
    debugPrint('Password: $password');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // =====================================================
          // BACKGROUND IMAGE
          // =====================================================
          Positioned.fill(
            child: Image.asset('assets/images/Wolf.png', fit: BoxFit.cover),
          ),

          // =====================================================
          // WHITE LOGIN PANEL
          // =====================================================
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.83,
              padding: const EdgeInsets.symmetric(horizontal: 56),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(38),
                  topRight: Radius.circular(38),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 56),

                    // WELCOME
                    const Center(
                      child: Text(
                        'Welcome',
                        style: TextStyle(
                          fontSize: 31,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF103D4C),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Center(
                      child: Text(
                        'Log in to your account to continue',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF555555),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // EMAIL
                    const Text(
                      'Email',
                      style: TextStyle(fontSize: 20, color: Color(0xFF888888)),
                    ),

                    const SizedBox(height: 3),

                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(),
                    ),

                    const SizedBox(height: 13),

                    // PASSWORD
                    const Text(
                      'Password',
                      style: TextStyle(fontSize: 20, color: Color(0xFF888888)),
                    ),

                    const SizedBox(height: 3),

                    TextField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      decoration: _inputDecoration(
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _hidePassword = !_hidePassword;
                            });
                          },
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF999999),
                            size: 22,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 9),

                    // REMEMBER ME
                    Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                            side: const BorderSide(color: Color(0xFFD0D0D0)),
                            activeColor: const Color(0xFF17617A),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Remember me',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF777777),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // LOGIN BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF17617A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 38),

                    const Row(
                      children: [
                        Expanded(child: Divider(color: Color(0xFFD8D8D8))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'Or',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF555555),
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Color(0xFFD8D8D8))),
                      ],
                    ),

                    const SizedBox(height: 38),

                    SizedBox(
                      width: double.infinity,
                      height: 41,
                      child: OutlinedButton(
                        onPressed: () {
                          debugPrint('Microsoft sign-in tapped');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF222222),
                          side: const BorderSide(color: Color(0xFFC8C8C8)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _MicrosoftMark(),
                            SizedBox(width: 8),
                            Text(
                              'Continue with Microsoft',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({Widget? suffixIcon}) {
    return InputDecoration(
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFD5D5D5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFD5D5D5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF17617A)),
      ),
    );
  }
}

class _MicrosoftMark extends StatelessWidget {
  const _MicrosoftMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 14,
      height: 14,
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
}

class _MicrosoftTile extends StatelessWidget {
  const _MicrosoftTile({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 6, height: 6, child: ColoredBox(color: color));
  }
}
