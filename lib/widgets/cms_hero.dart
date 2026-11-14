import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Desktop artwork and a readable mobile composition of the same CMS banner.
class CmsHero extends StatelessWidget {
  const CmsHero({super.key, required this.name, required this.label});
  final String name;
  final String label;
  static final _artwork = <String, Future<String>>{};

  static Future<String> _load(String name) async {
    return rootBundle.loadString('assets/heroes/hero-$name.svg');
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 768 && name != 'home') {
      return _MobileHero(name: name);
    }
    return Semantics(
      label: label,
      image: true,
      child: AspectRatio(
        aspectRatio: name == 'home'
            ? 1419 / 807
            : name == 'about'
            ? 1059 / 343
            : 1083 / 351,
        child: ExcludeSemantics(
          child: FutureBuilder<String>(
            future: _artwork.putIfAbsent(name, () => _load(name)),
            builder: (_, snapshot) => snapshot.hasData
                ? SvgPicture.string(
                    snapshot.data!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => SvgPicture.asset(
                      'assets/heroes/hero-$name.svg',
                      fit: BoxFit.contain,
                    ),
                  )
                : SvgPicture.asset(
                    'assets/heroes/hero-$name.svg',
                    fit: BoxFit.contain,
                  ),
          ),
        ),
      ),
    );
  }
}

class _MobileHero extends StatelessWidget {
  const _MobileHero({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final (eyebrow, title, description) = switch (name) {
      'discover' => (
        'Articles · activities · achievements',
        'Stories & highlights',
        "Discover the stories, activities, and achievements that highlight our students' creativity, experiences, and accomplishments.",
      ),
      'documents' => (
        'Documents · records · archives',
        'Official records',
        "Browse SSITE's official documents and organizational records in one accessible location.",
      ),
      'transparency' => (
        'Financial transparency · accountability · trust',
        'Funds with purpose',
        "Explore SSITE's financial records, expense reports, and liquidation documents to see how organization funds are managed and utilized.",
      ),
      _ => (
        'About the organization',
        'Get to know SSITE',
        'Discover who we are, what we stand for, and the vision that brings our community together.',
      ),
    };
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF63E1ED), Color(0xFF80D7E8), Color(0xFF7CE5E5)],
        ),
      ),
      child: CustomPaint(
        painter: const _HeroGrid(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                eyebrow,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  height: 1.5,
                  color: Color(0xFF155571),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 28,
                    height: 1.2,
                    color: Color(0xFF063847),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFF155571),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroGrid extends CustomPainter {
  const _HeroGrid();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x0C155571);
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroGrid oldDelegate) => false;
}
