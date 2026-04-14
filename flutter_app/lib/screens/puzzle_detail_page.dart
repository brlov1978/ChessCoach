import 'package:flutter/material.dart';

import 'package:flutter_app/models/puzzle_data.dart';
import 'package:flutter_app/utils/chess_board_utils.dart';
import 'package:flutter_app/widgets/chess_board_view.dart';
import 'package:flutter_app/widgets/info_chip.dart';

class PuzzleDetailPage extends StatefulWidget {
  const PuzzleDetailPage({
    super.key,
    required this.index,
    required this.puzzle,
    required this.onAttempt,
    this.initialResult,
    this.onNextPuzzle,
    this.onOpenSettings,
    this.gamesCount = 0,
    this.puzzleCount = 0,
    this.attemptCount = 0,
    this.correctCount = 0,
    this.stats,
    this.isPreparingNext = false,
  });

  final int index;
  final PuzzleData puzzle;
  final ValueChanged<bool> onAttempt;
  final bool? initialResult;
  final VoidCallback? onNextPuzzle;
  final VoidCallback? onOpenSettings;
  final int gamesCount;
  final int puzzleCount;
  final int attemptCount;
  final int correctCount;
  final Map<String, dynamic>? stats;
  final bool isPreparingNext;

  @override
  State<PuzzleDetailPage> createState() => _PuzzleDetailPageState();
}

class _PuzzleDetailPageState extends State<PuzzleDetailPage> {
  bool _reveal = false;
  late String _currentFen;
  String? _selectedSquare;
  String? _highlightSquare;
  bool? _lastResult;
  int _celebrationCount = 0;

  @override
  void initState() {
    super.initState();
    _resetPuzzle();
    _lastResult = widget.initialResult;
    if (_lastResult == true) {
      _celebrationCount = 1;
    }
  }

  void _resetPuzzle() {
    _currentFen = widget.puzzle.fen;
    _selectedSquare = null;
    _highlightSquare = null;
    _lastResult = widget.initialResult == true ? true : null;
    _celebrationCount = widget.initialResult == true ? 1 : 0;
  }

  void _handleMoveAttempt(String fromSquare, String toSquare) {
    if (_lastResult != null) {
      return;
    }
    final expectedMove = widget.puzzle.bestMoveUci.toLowerCase();
    final attemptedMove = '$fromSquare$toSquare'.toLowerCase();
    final isCorrect = attemptedMove == expectedMove.substring(0, 4);

    widget.onAttempt(isCorrect);

    setState(() {
      _highlightSquare = toSquare;
      _selectedSquare = null;
      _lastResult = isCorrect;

      if (isCorrect) {
        _currentFen = applyMoveToFen(_currentFen, expectedMove);
        _celebrationCount += 1;
      } else {
        _currentFen = applyMoveToFen(_currentFen, attemptedMove);
      }
    });
  }

  void _handleSquareTap(String square) {
    if (_lastResult != null) {
      return;
    }

    final piece = pieceAtSquare(_currentFen, square);

    if (_selectedSquare == null) {
      if (piece.isNotEmpty && isSideToMovePiece(_currentFen, piece)) {
        setState(() {
          _selectedSquare = square;
          _highlightSquare = square;
        });
      } else {
        setState(() {});
      }
      return;
    }

    if (_selectedSquare == square) {
      setState(() {
        _selectedSquare = null;
        _highlightSquare = null;
      });
      return;
    }

    if (piece.isNotEmpty && isSideToMovePiece(_currentFen, piece)) {
      setState(() {
        _selectedSquare = square;
        _highlightSquare = square;
      });
      return;
    }

    _handleMoveAttempt(_selectedSquare!, square);
  }

  Widget _buildHeaderSnapshot(BuildContext context) {
    final positions = widget.stats?['positions_checked']?.toString() ?? '0';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
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
              'Training snapshot',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SnapshotPill(label: 'Score', value: '${widget.correctCount}/${widget.attemptCount}'),
                  const SizedBox(width: 8),
                  _SnapshotPill(label: 'Next', value: widget.isPreparingNext ? 'Loading' : 'Ready'),
                  const SizedBox(width: 8),
                  _SnapshotPill(label: 'Checked', value: positions),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCelebrationCard() {
    return TweenAnimationBuilder<double>(
      key: ValueKey(_celebrationCount),
      tween: Tween(begin: 0.7, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: Transform.scale(scale: value, child: child),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1F3A27),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF59A96A)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x331E8E3E),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.celebration, color: Color(0xFFFFD54F)),
                SizedBox(width: 8),
                Text(
                  'Nice solve!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.auto_awesome, color: Color(0xFFFFD54F)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'You found the best move. Ready for the next puzzle?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: widget.onNextPuzzle,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next puzzle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTryAgainCard() {
    return TweenAnimationBuilder<double>(
      key: ValueKey('retry-$_lastResult-$_currentFen'),
      tween: Tween(begin: 0.82, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(scale: value, child: child),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF4A1F1F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFB95C5C)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33B95C5C),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.close_rounded, color: Color(0xFFFFC9C9)),
                SizedBox(width: 8),
                Text(
                  'Not quite',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.refresh_rounded, color: Color(0xFFFFC9C9)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'That move was not the best one. Reset the board and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => setState(_resetPuzzle),
              icon: const Icon(Icons.replay),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = widget.puzzle;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Your move'),
          toolbarHeight: 60,
          actions: [
            if (widget.onOpenSettings != null)
              IconButton(
                onPressed: widget.onOpenSettings,
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(78),
            child: _buildHeaderSnapshot(context),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final boardSize = constraints.maxWidth < 640 ? (constraints.maxWidth - 84).clamp(260.0, 560.0).toDouble() : 520.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        puzzle.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Drag a piece to solve the puzzle. Tapping also works.',
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: SizedBox(
                          width: boardSize + 72,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _EvalBar(
                                evaluationCp: puzzle.evaluationCp,
                                mateIn: puzzle.mateIn,
                                height: boardSize,
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: boardSize,
                                height: boardSize,
                                child: ChessBoardView(
                                  fen: _currentFen,
                                  selectedSquare: _selectedSquare,
                                  highlightSquare: _highlightSquare,
                                  onSquareTap: _handleSquareTap,
                                  onMoveAttempt: _handleMoveAttempt,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_lastResult == true) ...[
                        const SizedBox(height: 16),
                        _buildCelebrationCard(),
                      ] else if (_lastResult == false) ...[
                        const SizedBox(height: 16),
                        _buildTryAgainCard(),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          InfoChip(label: 'Opening', value: puzzle.opening),
                          InfoChip(label: 'Opponent', value: puzzle.opponent),
                          InfoChip(label: 'Side', value: puzzle.playerColor),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(puzzle.reason),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => setState(() => _reveal = !_reveal),
                            child: Text(
                              _reveal ? 'Hide solution' : 'Reveal solution',
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(_resetPuzzle),
                            child: const Text('Reset board'),
                          ),
                        ],
                      ),
                      if (_reveal || _lastResult == true) ...[
                        const SizedBox(height: 8),
                        Text('Best move: ${puzzle.bestMoveSan}'),
                        if (puzzle.actualMoveSan != null)
                          Text(
                            'Move played in the game: ${puzzle.actualMoveSan}',
                          ),
                        if (puzzle.sourceUrl.isNotEmpty) SelectableText('Source game: ${puzzle.sourceUrl}'),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SnapshotPill extends StatelessWidget {
  const _SnapshotPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1D1B),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF4A4743)),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.labelMedium,
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(color: Colors.white70),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Color(0xFFBFD97B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvalBar extends StatelessWidget {
  const _EvalBar({
    required this.evaluationCp,
    required this.mateIn,
    required this.height,
  });

  final int evaluationCp;
  final int? mateIn;
  final double height;

  @override
  Widget build(BuildContext context) {
    final whiteShare = mateIn != null ? (evaluationCp >= 0 ? 0.96 : 0.04) : (((evaluationCp.clamp(-900, 900)) + 900) / 1800).toDouble();
    final whiteFlex = (whiteShare * 100).round().clamp(4, 96);
    final blackFlex = 100 - whiteFlex;
    final label = mateIn != null ? 'M$mateIn' : '${evaluationCp >= 0 ? '+' : ''}${(evaluationCp / 100).toStringAsFixed(1)}';

    return SizedBox(
      width: 56,
      height: height,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xCC2C2A28),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF4A4743)),
            ),
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF4A4743), width: 1.2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Column(
                  children: [
                    Expanded(
                      flex: blackFlex,
                      child: Container(color: const Color(0xFF1F1F1F)),
                    ),
                    Expanded(
                      flex: whiteFlex,
                      child: Container(color: const Color(0xFFF4F1EA)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
