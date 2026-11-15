part of '../main_screen.dart';

class _SponsorCard extends StatelessWidget {
  const _SponsorCard({required this.sponsor});
  final CmsSponsor sponsor;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(sponsor.websiteUrl ?? '');
    final canVisit =
        uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'https' || uri.scheme == 'http');
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sponsor.logoUrl != null) ...[
              Center(
                child: Image.network(
                  sponsor.logoUrl!,
                  height: 100,
                  fit: BoxFit.contain,
                  errorBuilder: (_, error, stack) =>
                      const Icon(Icons.business, size: 64),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(sponsor.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(sponsor.description),
            if (canVisit)
              TextButton.icon(
                onPressed: () async {
                  try {
                    if (!await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    )) {
                      throw StateError('Could not open page');
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open the sponsor page.'),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Visit Official Page'),
              ),
          ],
        ),
      ),
    );
  }
}
