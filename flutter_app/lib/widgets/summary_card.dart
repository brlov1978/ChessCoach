import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.gamesCount,
    required this.puzzleCount,
    required this.attemptCount,
    required this.correctCount,
    required this.stats,
  });

  final int gamesCount;
  final int puzzleCount;
  final int attemptCount;
  final int correctCount;
  final Map<String, dynamic>? stats;

  @override
  Widget build(BuildContext context) {
    final engine = stats?['engine_source']?.toString() ?? 'Not run yet';
    final positions = stats?['positions_checked']?.toString() ?? '0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Training snapshot',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatBadge(label: 'Score', value: '$correctCount / $attemptCount'),
                _StatBadge(label: 'Loaded', value: '$puzzleCount puzzles'),
                _StatBadge(label: 'Games', value: '$gamesCount scanned'),
                _StatBadge(label: 'Checked', value: '$positions positions'),
              ],
            ),
            const SizedBox(height: 12),
            Text('Engine: $engine'),
            const SizedBox(height: 6),
            const Text('Pick a puzzle from the list and solve it on its own screen.'),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF262421),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4A4743)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFBFD97B),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
