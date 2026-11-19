part of 'main_screen.dart';

enum _AccountAction { refresh, signOut }

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.profile, required this.size});

  final MemberProfile? profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final words = profile?.name.trim().split(RegExp(r'\s+')) ?? [];
    final initials = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.characters.first.toUpperCase())
        .join();
    final placeholder = ColoredBox(
      color: const Color(0xFFD9F0FA),
      child: Center(
        child: initials.isEmpty
            ? Icon(Icons.person_outline, color: navy, size: size * .52)
            : Text(
                initials,
                style: TextStyle(
                  color: navy,
                  fontSize: size * .32,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
    final photo = profile?.photoBytes;
    final url = profile?.photoUrl;
    if (photo != null || url != null) {
      return SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: photo != null
              ? Image.memory(
                  photo,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                )
              : Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
      );
    }
    return SizedBox.square(
      dimension: size,
      child: ClipOval(child: placeholder),
    );
  }
}

class _MemberAccount extends StatelessWidget {
  const _MemberAccount({required this.profile});

  final ValueNotifier<MemberProfile?> profile;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        ValueListenableBuilder<MemberProfile?>(
          valueListenable: profile,
          builder: (context, member, _) => Container(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEAF7FC), Color(0xFFD5EDF9)],
              ),
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: _MemberAvatar(profile: member, size: 76),
                ),
                const SizedBox(height: 12),
                Text(
                  member?.name ?? 'SSITE member',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (member?.email case final email?) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.refresh_rounded),
          title: const Text('Refresh content'),
          onTap: () => Navigator.pop(context, _AccountAction.refresh),
        ),
        ListTile(
          leading: const Icon(Icons.logout_rounded),
          title: const Text('Sign out'),
          onTap: () => Navigator.pop(context, _AccountAction.signOut),
        ),
      ],
    ),
  );
}
