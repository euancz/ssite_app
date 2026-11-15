part of '../main_screen.dart';

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'Poppins',
        color: ink,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: muted, fontSize: 12)),
        ),
      ],
    ),
  );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: line),
    ),
    child: child,
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: muted, fontSize: 13),
    ),
  );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_outlined, size: 40, color: muted),
        const SizedBox(height: 12),
        Text(
          error is CmsUnauthorized
              ? 'Your session has expired. Sign out and sign in again.'
              : 'Cannot load SSITE content.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Check your connection and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

String formatCmsDate(String? value) {
  final date = DateTime.tryParse(value ?? '');
  if (date == null) return '';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
