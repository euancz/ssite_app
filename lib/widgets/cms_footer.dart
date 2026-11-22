import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';

class CmsFooter extends StatelessWidget {
  const CmsFooter({super.key});
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xff8ad5f4),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/ssite_logo_cropped.png',
                  width: 54,
                  height: 54,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'STUDENT SOCIETY IN INFORMATION TECHNOLOGY EDUCATION',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'The student organization for Information Technology at Mabalacat City College.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                for (final item in ['ics', 'mcc', 'ssite'])
                  Image.asset(
                    'assets/images/$item-badge.png',
                    height: 52,
                    width: 52,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Contact Us', style: Theme.of(context).textTheme.titleMedium),
            for (final item in [
              (
                Icons.location_on_outlined,
                'Dolores, Mabalacat City College',
                'https://www.google.com/maps/search/?api=1&query=Mabalacat%20City%20College%20Dolores',
              ),
              (
                Icons.facebook,
                'SSITE on Facebook',
                'https://www.facebook.com/ICSSSITE',
              ),
              (Icons.mail_outline, 'ssite@gmail.com', 'mailto:ssite@gmail.com'),
            ])
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      if (await launchUrl(
                        Uri.parse(item.$3),
                        mode: LaunchMode.externalApplication,
                      ))
                        return;
                    } catch (_) {}
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not open ${item.$2}.')),
                      );
                  },
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor: ink,
                    backgroundColor: const Color(0xffdff3fc),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(item.$1, size: 20),
                  label: Text(item.$2),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
