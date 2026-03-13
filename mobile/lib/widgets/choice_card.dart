import 'package:flutter/material.dart';
import '../models/chapter.dart';

class ChoiceCard extends StatelessWidget {
  final Choice choice;
  final VoidCallback onTap;

  const ChoiceCard({super.key, required this.choice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Row(
          children: [
            Text(
              '${choice.id}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFC9A96E)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                choice.text,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w300),
              ),
            ),
            Icon(Icons.arrow_forward, size: 14, color: Colors.grey[700]),
          ],
        ),
      ),
    );
  }
}
