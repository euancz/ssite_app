import 'package:flutter/material.dart';
import '../../widgets/search_bar.dart';

class ArticlesScreen extends StatelessWidget {
  const ArticlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(
          left: 32,
          right: 32,
          top: 19,
          bottom: 30,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SEARCH BAR
            const AppSearchBar(),

            const SizedBox(height: 34),

            // TITLE
            const Text(
              'Articles',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF164B5C),
              ),
            ),

            const SizedBox(height: 15),

            // FIRST POST
            _buildArticle(caption: 'Caption Bluh Bluh Bluh', date: 'Date'),

            const SizedBox(height: 15),

            // SECOND POST
            _buildArticle(caption: 'Caption Bluh Bluh Bluh', date: 'Date'),
          ],
        ),
      ),
    );
  }

  Widget _buildArticle({required String caption, required String date}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 171,
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
                  onPressed: () {},
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
}
