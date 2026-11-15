part of '../main_screen.dart';

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.text});
  final String title, text;
  @override
  Widget build(BuildContext context) => _Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(title),
        Text(
          text,
          style: const TextStyle(color: muted, height: 1.65, fontSize: 14),
        ),
      ],
    ),
  );
}

class _Officers extends StatelessWidget {
  const _Officers({required this.officers});
  final List<CmsOfficer> officers;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 650
          ? 3
          : constraints.maxWidth >= 320
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final officer in officers)
            SizedBox(
              width: width,
              child: _Surface(
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: officer.photoUrl == null
                          ? const ColoredBox(
                              color: Color(0xFFC7ECF9),
                              child: Icon(
                                Icons.person_outline,
                                size: 48,
                                color: navy,
                              ),
                            )
                          : Image.network(
                              officer.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.person_outline,
                                size: 48,
                                color: navy,
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      officer.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      officer.position,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
