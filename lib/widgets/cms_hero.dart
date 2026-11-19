import 'dart:ui' as ui;

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
    final bannerWidth = MediaQuery.sizeOf(context).width - 32;
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
        'Discover who we are, what we stand for, and the vision that brings our community of aspiring IT professionals together.',
      ),
    };
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: (bannerWidth * .26).clamp(144, 192).toDouble(),
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xD9FFFFFF)),
        borderRadius: BorderRadius.all(
          Radius.elliptical(bannerWidth * .036, 20),
        ),
        gradient: const LinearGradient(
          begin: Alignment(-1, -.4),
          end: Alignment(1, .4),
          colors: [Color(0xFF63E1ED), Color(0xFF80D7E8), Color(0xFF7CE5E5)],
        ),
      ),
      child: CustomPaint(
        painter: const _HeroGrid(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                eyebrow.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  height: 1.5,
                  color: Color(0xFF174B5C),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Semantics(
                header: true,
                child: Text(
                  title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (bannerWidth * .065).clamp(25.6, 44).toDouble(),
                    height: 1.12,
                    color: const Color(0xFF073746),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF174B5C),
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
    final depth = size.height * .27;
    for (final edge in [0.0, size.height]) {
      final inward = edge == 0 ? 1 : -1;
      final paint = Paint()
        ..strokeWidth = 1.5
        ..shader = ui.Gradient.linear(
          Offset(0, edge),
          Offset(0, edge + inward * depth),
          const [Color(0x3017A6D2), Color(0x0017A6D2)],
        );
      final middle = size.width / 2;
      for (var index = -7; index <= 7; index++) {
        final offset = index * size.width / 10;
        canvas.drawLine(
          Offset(middle + offset, edge),
          Offset(middle + offset * .42, edge + inward * depth),
          paint,
        );
      }
      for (final step in [.16, .37, .64, 1.0]) {
        final y = edge + inward * depth * step;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeroGrid oldDelegate) => false;
}
