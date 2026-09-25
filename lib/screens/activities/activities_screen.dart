import 'package:flutter/material.dart';
import '../../widgets/search_bar.dart';

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(
          left: 36,
          right: 36,
          top: 19,
          bottom: 30,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // SEARCH BAR
            const AppSearchBar(),

            const SizedBox(height: 34),

            // TITLE
            const Text(
              'Activities',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF164B5C),
              ),
            ),

            const SizedBox(height: 15),

            // FIRST POST
            _buildActivity(
              context,
              caption: 'Caption Bluh Bluh Bluh',
              date: 'Date',
            ),

            const SizedBox(height: 15),

            // SECOND POST
            _buildActivity(
              context,
              caption: 'Caption Bluh Bluh Bluh',
              date: 'Date',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivity(
    BuildContext context, {
    required String caption,
    required String date,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 190,
          decoration: BoxDecoration(
            color: const Color(0xFFD0D0D0),
            borderRadius: BorderRadius.circular(9),
          ),

          child: Stack(
            children: [
              Positioned(
                top: 4,
                right: 8,
                child: IconButton(
                  onPressed: () {
                    _showPostOptions(context);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.more_horiz,
                    color: Color(0xFF164B5C),
                    size: 23,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Text(
          caption,
          style: const TextStyle(fontSize: 13, color: Colors.black),
        ),

        const SizedBox(height: 4),

        Text(date, style: const TextStyle(fontSize: 13, color: Colors.black)),
      ],
    );
  }

  void _showPostOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF87D5F4),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) {
        return SizedBox(
          height: 300,
          width: double.infinity,
          child: Column(
            children: [
              const SizedBox(height: 12),

              Container(
                width: 42,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF164B5C),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  color: const Color(0xFF81D4F3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 18, top: 10, right: 18),
                        child: Text(
                          'About this post',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF164B5C),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(
                          left: 18,
                          right: 18,
                          top: 10,
                          bottom: 10,
                        ),
                        child: Text(
                          'Description of the post bluh bluh bluh '
                          'bluh bluh bluhbluh bluhbluh bluh bluh '
                          'bluh bluhbluhbluh bluh bluhbluh bluh',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: Color(0xFF164B5C),
                          ),
                        ),
                      ),
                      _buildOption(
                        context,
                        icon: Icons.edit,
                        text: 'Edit Post',
                        onTap: () => Navigator.pop(context),
                      ),
                      _buildOption(
                        context,
                        icon: Icons.link,
                        text: 'Copy Link',
                        onTap: () => Navigator.pop(context),
                      ),
                      _buildOption(
                        context,
                        icon: Icons.delete_outline,
                        text: 'Move to Trash',
                        onTap: () => Navigator.pop(context),
                      ),
                      _buildOption(
                        context,
                        icon: Icons.archive_outlined,
                        text: 'Move to Archive',
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFD8F3FC), width: 1)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 18),
            Icon(icon, size: 24, color: const Color(0xFF164B5C)),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF164B5C),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
