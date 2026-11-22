part of '../main_screen.dart';

class _CommunityHero extends StatelessWidget {
  const _CommunityHero({required this.onBrowse, required this.onUpdates});

  final VoidCallback onBrowse;
  final VoidCallback onUpdates;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width <= 380;
    const heroInk = Color(0xFF123E4C);
    const actionColor = Color(0xFF155571);
    final buttons = [
      FilledButton.icon(
        onPressed: onBrowse,
        style: FilledButton.styleFrom(
          backgroundColor: actionColor,
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: const Icon(Icons.arrow_forward, size: 17),
        iconAlignment: IconAlignment.end,
        label: const Text('Browse posts'),
      ),
      TextButton.icon(
        onPressed: onUpdates,
        style: TextButton.styleFrom(foregroundColor: actionColor),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        iconAlignment: IconAlignment.end,
        label: const Text('Latest updates'),
      ),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFEAF4F7),
        border: Border(bottom: BorderSide(color: Color(0xFFC8DFE5))),
      ),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1045),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              narrow ? 16 : 24,
              width < 768 ? 24 : 52,
              narrow ? 16 : 24,
              width < 768 ? 24 : 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Color(0xFF2384A0), width: 3),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(left: narrow ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'SSITE',
                            style: TextStyle(
                              color: heroInk,
                              fontSize: narrow
                                  ? (width * .15).clamp(42, 52).toDouble()
                                  : 52,
                              fontWeight: FontWeight.w700,
                              height: 1.05,
                              letterSpacing: -2.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Mabalacat City College',
                          style: TextStyle(
                            color: heroInk,
                            fontSize: narrow ? 19 : 22,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Catch up on campus stories, student activities, and achievements.',
                          style: TextStyle(
                            color: Color(0xFF425E69),
                            fontSize: 15,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (narrow)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: buttons,
                          )
                        else
                          Wrap(spacing: 16, children: buttons),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: narrow ? 20 : 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 416),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFC4D9E1)),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Image.asset(
                            width < 768
                                ? 'assets/images/rawri-community-cutout.png'
                                : 'assets/images/ssite_logo_cropped.png',
                            width: (width * .18).clamp(56, 80).toDouble(),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Student Society in Information Technology Education',
                              style: TextStyle(
                                color: Color(0xFF325464),
                                fontSize: 14,
                                height: 1.55,
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
          ),
        ),
      ),
    );
  }
}
