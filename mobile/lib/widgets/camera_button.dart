import 'package:flutter/material.dart';

class CameraButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool hasPhoto;

  const CameraButton({super.key, required this.onPressed, required this.hasPhoto});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        hasPhoto ? Icons.camera_alt : Icons.camera_alt_outlined,
        size: 18,
        color: hasPhoto ? const Color(0xFFC9A96E) : Colors.grey[600],
      ),
      tooltip: hasPhoto ? 'Fotoğraf eklendi' : 'Fotoğraf ekle',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}
