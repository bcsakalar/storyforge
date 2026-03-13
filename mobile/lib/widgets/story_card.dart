import 'package:flutter/material.dart';
import '../models/story.dart';

class StoryCardWidget extends StatelessWidget {
  final Story story;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const StoryCardWidget({
    super.key,
    required this.story,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[800]!))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title.length > 60 ? '${story.title.substring(0, 60)}...' : story.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(story.genre.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 1.5, color: Color(0xFFC9A96E), fontWeight: FontWeight.w500)),
                      const SizedBox(width: 12),
                      Text('${story.chapterCount} bölüm', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[700]),
          ],
        ),
      ),
    );
  }
}
