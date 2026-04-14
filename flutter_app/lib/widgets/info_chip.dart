import 'package:flutter/material.dart';

class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF262421),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF4A4743)),
      ),
      child: Text(
        '$label • $value',
        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
      ),
    );
  }
}
