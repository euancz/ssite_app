part of '../main_screen.dart';

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.text});
  final String title, text;
  @override
  Widget build(BuildContext context) {
    final mission = title == 'Mission';
    const curve = Radius.circular(36);
    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
      decoration: BoxDecoration(
        borderRadius: mission
            ? const BorderRadius.only(topLeft: curve, bottomRight: curve)
            : const BorderRadius.only(topRight: curve, bottomLeft: curve),
        border: Border.all(color: const Color(0xff50d7e5)),
        gradient: const LinearGradient(
          colors: [Color(0xff9cecf7), Color(0xff8bf3fa), Color(0xff98e9f7)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff19c7d3),
            offset: Offset(mission ? -4 : 4, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xff063847),
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const Divider(height: 24, color: Color(0xff155571)),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xff063847),
              fontSize: 15,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _Officers extends StatelessWidget {
  const _Officers({required this.officers});
  final List<CmsOfficer> officers;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 650
          ? 3
          : MediaQuery.sizeOf(context).width > 560 &&
                constraints.maxWidth >= 320
          ? 2
          : 1;
      final width = ((constraints.maxWidth - (columns - 1) * 12) / columns)
          .clamp(0.0, 290.0)
          .toDouble();
      return Wrap(
        alignment: WrapAlignment.center,
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
