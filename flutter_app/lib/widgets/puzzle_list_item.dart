import 'package:flutter/material.dart';

import 'package:flutter_app/models/puzzle_data.dart';

class PuzzleListItem extends StatelessWidget {
  const PuzzleListItem({
    super.key,
    required this.index,
    required this.puzzle,
    required this.onTap,
    this.result,
  });

  final int index;
  final PuzzleData puzzle;
  final VoidCallback onTap;
  final bool? result;

  @override
  Widget build(BuildContext context) {
    final statusText = result == true
        ? 'Solved'
        : result == false
            ? 'Attempted'
            : 'New';
    final statusColor = result == true
        ? const Color(0xFF81B64C)
        : result == false
            ? const Color(0xFFF1C453)
            : Colors.white70;
    final advantage = puzzle.mateIn != null ? 'Mate in ${puzzle.mateIn}' : '${(puzzle.evaluationCp / 100).toStringAsFixed(1)} pawns';

    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          'Puzzle $index',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(puzzle.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(
                '${puzzle.opening} • $advantage',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700)),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
